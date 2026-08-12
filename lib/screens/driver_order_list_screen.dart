import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';
import 'driver_order_detail_screen.dart';
import '../utils/qatar_time.dart';

class DriverOrderListScreen extends StatefulWidget {
  final String statusFilter;
  final String title;
  const DriverOrderListScreen({super.key, required this.statusFilter, required this.title});

  @override
  State<DriverOrderListScreen> createState() => _DriverOrderListScreenState();
}

class _DriverOrderListScreenState extends State<DriverOrderListScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  String _todayStr() => QatarTime.todayStr();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final driverId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('orders')
        .select()
        .eq('assigned_driver_id', driverId)
        .eq('delivery_date', _todayStr())
        .eq('status', widget.statusFilter)
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(data);
    list.sort((a, b) {
      final beforeA = a['delivery_window_end'] as String?;
      final beforeB = b['delivery_window_end'] as String?;
      if (beforeA == null && beforeB == null) return 0;
      if (beforeA == null) return 1;
      if (beforeB == null) return -1;
      return beforeA.compareTo(beforeB);
    });

    setState(() {
      _orders = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: AppColors.navy, foregroundColor: Colors.white),
      body: Container(
        color: AppColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? const Center(child: Text('No orders here', style: TextStyle(color: AppColors.textSecondary)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        final slot = order['delivery_window_start'] != null
                                ? '${QatarTime.trimSeconds(order['delivery_window_start'])} - ${QatarTime.trimSeconds(order['delivery_window_end'])}'
                                : null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(order['consignee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [order['full_address'], ?slot].where((e) => e != null).join('\n'),
                            ),
                            isThreeLine: slot != null,
                            trailing: StatusPill(status: order['status'] ?? 'pending'),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => DriverOrderDetailScreen(order: order)));
                              _load();
                            },
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}