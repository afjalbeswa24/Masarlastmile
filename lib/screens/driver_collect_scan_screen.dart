import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/sound_utils.dart';
import '../utils/box_scan_service.dart';
import '../widgets/scan_input.dart';
import '../utils/qatar_time.dart';

class DriverCollectScanScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  const DriverCollectScanScreen({super.key, required this.merchantId, required this.merchantName});

  @override
  State<DriverCollectScanScreen> createState() => _DriverCollectScanScreenState();
}

class _DriverCollectScanScreenState extends State<DriverCollectScanScreen> {
  bool _processing = false;
  String? _lastMessage;
  bool _lastSuccess = false;

  int _totalAtStart = 0;
  int _collectedCount = 0;
  List<Map<String, dynamic>> _remainingPending = [];
  bool _loadingList = true;

  String _todayStr() => QatarTime.todayStr();

  @override
  void initState() {
    super.initState();
    _initCounts();
  }

  Future<void> _initCounts() async {
    final pending = await supabase
        .from('orders')
        .select('id, order_code, consignee_name, full_address')
        .eq('merchant_id', widget.merchantId)
        .eq('status', 'pending')
        .or('delivery_date.eq.${_todayStr()},delivery_date.is.null')
        .order('created_at');

    setState(() {
      _remainingPending = List<Map<String, dynamic>>.from(pending);
      _totalAtStart = _remainingPending.length;
      _loadingList = false;
    });
  }

  Future<void> _refreshRemaining() async {
    final pending = await supabase
        .from('orders')
        .select('id, order_code, consignee_name, full_address')
        .eq('merchant_id', widget.merchantId)
        .eq('status', 'pending')
        .or('delivery_date.eq.${_todayStr()},delivery_date.is.null')
        .order('created_at');
    setState(() => _remainingPending = List<Map<String, dynamic>>.from(pending));
  }

  Future<void> _handleScan(String code) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _lastMessage = null;
    });

    try {
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

      if (order['merchant_id'] != widget.merchantId) {
        SoundUtils.playFail();
        setState(() {
          _lastSuccess = false;
          _lastMessage = 'This package belongs to a different merchant.';
        });
        return;
      }
      if (order['status'] != 'pending') {
        SoundUtils.playDuplicate();
        setState(() {
          _lastSuccess = false;
          _lastMessage = '${order['consignee_name']} is already "${order['status']}".';
        });
        return;
      }
      if (BoxScanService.alreadyScanned(box, 'picked_up')) {
        SoundUtils.playDuplicate();
        setState(() {
          _lastSuccess = false;
          _lastMessage = 'Box ${box['box_number']} already collected.';
        });
        return;
      }

      final result = await BoxScanService.markStage(box['id'], box['order_id'], 'picked_up');

      SoundUtils.playSuccess();
      setState(() {
        _lastSuccess = true;
        _lastMessage = result.orderCompleted
            ? 'Collected: ${order['consignee_name']} ($code) — all boxes done'
            : 'Box ${box['box_number']} collected. ${result.remaining} box(es) remaining for ${order['consignee_name']}.';
      });
      if (result.orderCompleted) {
        _collectedCount++;
      }
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
    _refreshRemaining();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchantName),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.navy,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '($_collectedCount/$_totalAtStart)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ScanInput(height: 260, onScan: _handleScan),
            Container(
              width: double.infinity,
              color: _lastMessage == null
                  ? Colors.white
                  : (_lastSuccess ? Colors.green.shade50 : Colors.red.shade50),
              padding: const EdgeInsets.all(14),
              child: Center(
                child: _processing
                    ? const CircularProgressIndicator()
                    : Text(
                        _lastMessage ?? 'Scan a package from ${widget.merchantName}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _lastMessage == null
                              ? AppColors.textSecondary
                              : (_lastSuccess ? Colors.green.shade800 : Colors.red.shade800),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text('Remaining Pending (${_remainingPending.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: _loadingList
                  ? const Center(child: CircularProgressIndicator())
                  : _remainingPending.isEmpty
                      ? const Center(child: Text('All packages collected', style: TextStyle(color: AppColors.statusDelivered, fontWeight: FontWeight.w600)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _remainingPending.length,
                          itemBuilder: (context, index) {
                            final o = _remainingPending[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary, size: 20),
                                title: Text(o['order_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text(
                                  '${o['consignee_name'] ?? ''} — ${o['full_address'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}