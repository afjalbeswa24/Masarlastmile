import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/sound_utils.dart';
import '../utils/qatar_time.dart';


class DriverManualOfdScreen extends StatefulWidget {
  const DriverManualOfdScreen({super.key});

  @override
  State<DriverManualOfdScreen> createState() => _DriverManualOfdScreenState();
}

class _DriverManualOfdScreenState extends State<DriverManualOfdScreen> {
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
        .inFilter('status', ['pending', 'picked_up', 'sorted', 'assigned', 'rescheduled'])
        .order('created_at');

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

  Future<void> _confirmOfd(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Out for Delivery?'),
        content: Text('${order['consignee_name']} — ${order['order_code']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase.from('orders').update({
      'status': 'out_for_delivery',
      'out_for_delivery_at': QatarTime.nowUtcIso(),
    }).eq('id', order['id']);

    SoundUtils.playSuccess();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Order Manually'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? const Center(child: Text('No pending orders for today', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
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
                          trailing: FilledButton(
                            onPressed: () => _confirmOfd(order),
                            child: const Text('OFD'),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}