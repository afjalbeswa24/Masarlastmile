import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'driver_collect_scan_screen.dart';
import '../utils/qatar_time.dart';

class DriverCollectTab extends StatefulWidget {
  const DriverCollectTab({super.key});

  @override
  State<DriverCollectTab> createState() => _DriverCollectTabState();
}

class _DriverCollectTabState extends State<DriverCollectTab> {
  List<Map<String, dynamic>> _merchants = [];
  Map<String, int> _pendingCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _todayStr() => QatarTime.todayStr();

  Future<void> _load() async {
    setState(() => _loading = true);
    final merchants = await supabase.from('profiles').select('id, full_name').eq('role', 'merchant');
    final pending = await supabase
        .from('orders')
        .select('merchant_id')
        .eq('status', 'pending')
        .or('delivery_date.eq.${_todayStr()},delivery_date.is.null');

    final counts = <String, int>{};
    for (final row in pending) {
      final mid = row['merchant_id'] as String?;
      if (mid == null) continue;
      counts[mid] = (counts[mid] ?? 0) + 1;
    }

    setState(() {
      _merchants = List<Map<String, dynamic>>.from(merchants);
      _pendingCounts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _merchants.isEmpty
                  ? const Center(child: Text('No merchants found', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Select a merchant to collect from', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        ..._merchants.map((m) {
                          final pendingCount = _pendingCounts[m['id']] ?? 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: pendingCount > 0 ? AppColors.purpleLight : Colors.grey.shade200,
                                child: Text(
                                  '$pendingCount',
                                  style: TextStyle(
                                    color: pendingCount > 0 ? AppColors.purple : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(m['full_name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('$pendingCount pending pickup'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => DriverCollectScanScreen(
                                    merchantId: m['id'],
                                    merchantName: m['full_name'] ?? 'Unnamed',
                                  ),
                                ));
                                _load();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }
}