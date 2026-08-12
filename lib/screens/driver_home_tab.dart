import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';
import 'driver_scan_screen.dart';
import 'driver_order_list_screen.dart';
import 'driver_order_detail_screen.dart';
import '../utils/qatar_time.dart';

class DriverHomeTab extends StatefulWidget {
  const DriverHomeTab({super.key});

  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab> {
  Map<String, int> _counts = {'sorted': 0, 'out_for_delivery': 0, 'delivered': 0, 'failed': 0};
  List<Map<String, dynamic>> _allOrders = [];
  bool _loading = true;
  bool _sequenceMode = false;

  String _todayStr() => QatarTime.todayStr();

  int _statusRank(Map<String, dynamic> o) {
    final s = o['status'];
    return (s == 'delivered' || s == 'failed' || s == 'cancelled') ? 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final driverId = supabase.auth.currentUser!.id;
    final today = _todayStr();

    final data = await supabase
        .from('orders')
        .select()
        .eq('assigned_driver_id', driverId)
        .or('delivery_date.eq.$today,delivery_date.is.null')
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(data);

    final anySequenceSet = orders.any((o) => o['delivery_sequence'] != null);

    if (anySequenceSet) {
      orders.sort((a, b) {
        final rankCompare = _statusRank(a).compareTo(_statusRank(b));
        if (rankCompare != 0) return rankCompare;

        final seqA = a['delivery_sequence'];
        final seqB = b['delivery_sequence'];
        if (seqA == null && seqB == null) return 0;
        if (seqA == null) return 1;
        if (seqB == null) return -1;
        return (seqA as int).compareTo(seqB as int);
      });
    } else {
      orders.sort((a, b) {
        final rankCompare = _statusRank(a).compareTo(_statusRank(b));
        if (rankCompare != 0) return rankCompare;

        final beforeA = a['delivery_window_end'] as String?;
        final beforeB = b['delivery_window_end'] as String?;
        if (beforeA == null && beforeB == null) return 0;
        if (beforeA == null) return 1;
        if (beforeB == null) return -1;
        return beforeA.compareTo(beforeB);
      });
    }

    final counts = {'sorted': 0, 'out_for_delivery': 0, 'delivered': 0, 'failed': 0};
    for (final o in orders) {
      final s = o['status'];
      if (counts.containsKey(s)) counts[s] = counts[s]! + 1;
    }

    setState(() {
      _allOrders = orders;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _persistSequence() async {
    for (var i = 0; i < _allOrders.length; i++) {
      await supabase.from('orders').update({'delivery_sequence': i}).eq('id', _allOrders[i]['id']);
    }
  }

  Widget _statCard(String label, int value, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color),
          ),
          child: Column(
            children: [
              Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order, {int? serial}) {
    final slot = order['delivery_window_start'] != null
        ? '${order['delivery_window_start']} - ${order['delivery_window_end']}'
        : null;

    return Card(
      key: ValueKey(order['id']),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _sequenceMode
            ? CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.purpleLight,
                child: Text('${(serial ?? 0) + 1}', style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            : null,
        title: Text(order['consignee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [order['full_address'], ?slot].where((e) => e != null).join('\n'),
        ),
        isThreeLine: slot != null,
        trailing: _sequenceMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(status: order['status'] ?? 'pending'),
                  const SizedBox(width: 8),
                  const Icon(Icons.drag_handle, color: AppColors.textSecondary),
                ],
              )
            : StatusPill(status: order['status'] ?? 'pending'),
        onTap: _sequenceMode
            ? null
            : () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => DriverOrderDetailScreen(order: order)));
                _load();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _allOrders.length;

    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Today — ${_todayStr()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  Row(
                    children: [
                      _statCard('Sorted', _counts['sorted'] ?? 0, AppColors.statusAssigned, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverScanScreen()))
                            .then((_) => _load());
                      }),
                      _statCard('OFD', _counts['out_for_delivery'] ?? 0, AppColors.statusOutForDelivery, () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const DriverOrderListScreen(statusFilter: 'out_for_delivery', title: 'Out for Delivery')));
                      }),
                    ],
                  ),
                  Row(
                    children: [
                      _statCard('Delivered', _counts['delivered'] ?? 0, AppColors.statusDelivered, () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const DriverOrderListScreen(statusFilter: 'delivered', title: 'Delivered')));
                      }),
                      _statCard('Failed', _counts['failed'] ?? 0, AppColors.statusFailed, () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const DriverOrderListScreen(statusFilter: 'failed', title: 'Failed')));
                      }),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('All Orders ($total)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      Row(
                        children: [
                          Text(_sequenceMode ? 'Set Sequence: ON' : 'Set Sequence', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Switch(
                            value: _sequenceMode,
                            activeThumbColor: AppColors.purple,
                            onChanged: (v) async {
                              if (!v && _sequenceMode) {
                                await _persistSequence();
                              }
                              setState(() => _sequenceMode = v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_allOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No orders scheduled for today', style: TextStyle(color: AppColors.textSecondary))),
                    )
                  else if (_sequenceMode)
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _allOrders.removeAt(oldIndex);
                          _allOrders.insert(newIndex, item);
                        });
                      },
                      children: [
                        for (int i = 0; i < _allOrders.length; i++) _orderCard(_allOrders[i], serial: i),
                      ],
                    )
                  else
                    ..._allOrders.map((order) => _orderCard(order)),
                ],
              ),
      ),
    );
  }
}