import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../utils/box_scan_service.dart';
import '../widgets/scan_input.dart';
import 'warehouse_sort_detail_screen.dart';

class WarehouseSortTab extends StatefulWidget {
  final MobileScannerController controller;
  const WarehouseSortTab({super.key, required this.controller});

  @override
  State<WarehouseSortTab> createState() => _WarehouseSortTabState();
}

class _WarehouseSortTabState extends State<WarehouseSortTab> {
  bool _processing = false;
  bool _scanning = true;
  String? _lastMessage;
  final List<Map<String, String>> _recentlySorted = [];

  Future<void> _safeStart() async {
    try {
      await widget.controller.start();
    } catch (_) {
      // Already running or camera still releasing from another tab — ignore
    }
  }

  Future<void> _safeStop() async {
    try {
      await widget.controller.stop();
    } catch (_) {
      // Already stopped — ignore
    }
  }

  Future<void> _handleScan(String code) async {
    if (_processing || !_scanning) return;
    setState(() {
      _processing = true;
      _lastMessage = null;
    });

    try {
      final lookup = await BoxScanService.lookup(code);
      if (!lookup.found) {
        await _pauseWithMessage('No package found for code: $code');
        return;
      }

      final box = lookup.box!;
      final order = lookup.order!;

      final blockedStatuses = ['sorted', 'assigned', 'out_for_delivery', 'delivered', 'failed', 'cancelled'];
      if (blockedStatuses.contains(order['status'])) {
        await _pauseWithMessage('${order['consignee_name']} ($code) is already "${order['status']}" — not sorting again.');
        return;
      }
      if (BoxScanService.alreadyScanned(box, 'sorted')) {
        await _pauseWithMessage('Box ${box['box_number']} already sorted.');
        return;
      }

      await _safeStop();
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WarehouseSortDetailScreen(box: box, order: order)),
      );

      if (!mounted) return;
      if (result == true) {
        setState(() {
          _recentlySorted.insert(0, {'code': box['box_code'], 'name': order['consignee_name'] ?? ''});
        });
      }
      await _safeStart();
    } catch (e) {
      await _pauseWithMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _pauseWithMessage(String message) async {
    await _safeStop();
    setState(() {
      _scanning = false;
      _lastMessage = message;
    });
  }

  Future<void> _resumeScanning() async {
    setState(() {
      _scanning = true;
      _lastMessage = null;
    });
    await _safeStart();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          ScanInput(height: 280, controller: widget.controller, onScan: _handleScan),
          if (_lastMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _lastMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade800),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _resumeScanning,
                      child: const Text('OK — Continue Scanning'),
                    ),
                  ),
                ],
              ),
            )
          else if (_processing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          Expanded(
            child: _recentlySorted.isEmpty
                ? const Center(child: Text('No items sorted yet this session', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _recentlySorted.length,
                    itemBuilder: (context, index) {
                      final item = _recentlySorted[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.check_circle, color: AppColors.statusDelivered),
                          title: Text(item['code'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(item['name'] ?? ''),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}