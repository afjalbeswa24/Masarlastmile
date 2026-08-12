import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/sound_utils.dart';
import '../utils/box_scan_service.dart';
import '../widgets/scan_input.dart';
import 'driver_manual_ofd_screen.dart';
import '../utils/qatar_time.dart';

class DriverScanScreen extends StatefulWidget {
  const DriverScanScreen({super.key});

  @override
  State<DriverScanScreen> createState() => _DriverScanScreenState();
}

class _DriverScanScreenState extends State<DriverScanScreen> {
  bool _processing = false;
  String? _lastMessage;
  bool _lastSuccess = false;
  List<Map<String, dynamic>> _remainingSorted = [];
  bool _loadingList = true;

  String _todayStr() => QatarTime.todayStr();

  int _compareByBefore(Map<String, dynamic> a, Map<String, dynamic> b) {
    final beforeA = a['delivery_window_end'] as String?;
    final beforeB = b['delivery_window_end'] as String?;
    if (beforeA == null && beforeB == null) return 0;
    if (beforeA == null) return 1;
    if (beforeB == null) return -1;
    return beforeA.compareTo(beforeB);
  }

  @override
  void initState() {
    super.initState();
    _loadRemaining();
  }

  Future<void> _loadRemaining() async {
    final driverId = supabase.auth.currentUser!.id;
    final today = _todayStr();

    final data = await supabase
        .from('orders')
        .select('id, order_code, consignee_name, full_address, delivery_window_start, delivery_window_end')
        .eq('assigned_driver_id', driverId)
        .inFilter('status', ['sorted', 'rescheduled'])
        .or('delivery_date.eq.$today,delivery_date.is.null');

    final list = List<Map<String, dynamic>>.from(data);
    list.sort(_compareByBefore);

    setState(() {
      _remainingSorted = list;
      _loadingList = false;
    });
  }

  Future<void> _handleScan(String code) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _lastMessage = null;
    });

    try {
      final driverId = supabase.auth.currentUser!.id;
      final lookup = await BoxScanService.lookup(code);

      if (!lookup.found) {
        SoundUtils.playFail();
        setState(() {
          _lastSuccess = false;
          _lastMessage = 'No package found for code: $code';
        });
        return;
      }

      final box = lookup.box!;
      final order = lookup.order!;

      if (order['assigned_driver_id'] != driverId) {
        SoundUtils.playWrongDriver();
        setState(() {
          _lastSuccess = false;
          _lastMessage = 'This order is not assigned to you.';
        });
        return;
      }
      if (order['delivery_date'] != null && order['delivery_date'] != _todayStr()) {
        SoundUtils.playFail();
        setState(() {
          _lastSuccess = false;
          _lastMessage = '${order['consignee_name']} is not scheduled for today.';
        });
        return;
      }
      if (order['status'] == 'out_for_delivery' || order['status'] == 'delivered' || order['status'] == 'failed') {
        SoundUtils.playDuplicate();
        setState(() {
          _lastSuccess = false;
          _lastMessage = '${order['consignee_name']} ($code) is already "${order['status']}".';
        });
        return;
      }
      if (BoxScanService.alreadyScanned(box, 'out_for_delivery')) {
        SoundUtils.playDuplicate();
        setState(() {
          _lastSuccess = false;
          _lastMessage = 'Box ${box['box_number']} already scanned.';
        });
        return;
      }

      final result = await BoxScanService.markStage(box['id'], box['order_id'], 'out_for_delivery');

      SoundUtils.playSuccess();
      setState(() {
        _lastSuccess = true;
        _lastMessage = result.orderCompleted
            ? 'Out for delivery: ${order['consignee_name']} ($code) — all boxes done'
            : 'Box ${box['box_number']} scanned. ${result.remaining} box(es) remaining for ${order['consignee_name']}.';
      });
      _loadRemaining();
    } catch (e) {
      SoundUtils.playFail();
      setState(() {
        _lastSuccess = false;
        _lastMessage = 'Error: $e';
      });
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to Start Delivery'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          ScanInput(height: 240, onScan: _handleScan),
          Container(
            width: double.infinity,
            color: _lastMessage == null
                ? Colors.grey.shade100
                : (_lastSuccess ? Colors.green.shade50 : Colors.red.shade50),
            padding: const EdgeInsets.all(14),
            child: Center(
              child: _processing
                  ? const CircularProgressIndicator()
                  : Text(
                      _lastMessage ?? 'Scan a barcode from today\'s assigned orders',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _lastMessage == null
                            ? Colors.black54
                            : (_lastSuccess ? Colors.green.shade800 : Colors.red.shade800),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text('Remaining Sorted (${_remainingSorted.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: _loadingList
                ? const Center(child: CircularProgressIndicator())
                : _remainingSorted.isEmpty
                    ? const Center(child: Text('All sorted orders started', style: TextStyle(color: AppColors.statusDelivered, fontWeight: FontWeight.w600)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _remainingSorted.length,
                        itemBuilder: (context, index) {
                          final o = _remainingSorted[index];
                          final slot = o['delivery_window_start'] != null
                              ? '${QatarTime.trimSeconds(o['delivery_window_start'])} - ${QatarTime.trimSeconds(o['delivery_window_end'])}'
                              : null;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary, size: 20),
                              title: Text(o['consignee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(
                                [o['full_address'], ?slot].where((e) => e != null).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.touch_app),
              label: const Text('Can\'t scan? Select order manually'),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverManualOfdScreen()));
                _loadRemaining();
              },
            ),
          ),
        ],
      ),
    );
  }
}