import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart';

class CollectionHomeScreen extends StatefulWidget {
  const CollectionHomeScreen({super.key});

  @override
  State<CollectionHomeScreen> createState() => _CollectionHomeScreenState();
}

class _CollectionHomeScreenState extends State<CollectionHomeScreen> {
  bool _processing = false;
  String? _lastMessage;
  bool _lastSuccess = false;

  Future<void> _handleScan(String code) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _lastMessage = null;
    });

    try {
      final order = await supabase
          .from('orders')
          .select('id, status, consignee_name')
          .eq('order_code', code)
          .maybeSingle();

      if (order == null) {
        setState(() {
          _lastSuccess = false;
          _lastMessage = 'No order found for code: $code';
        });
        return;
      }

      if (order['status'] != 'pending') {
        setState(() {
          _lastSuccess = false;
          _lastMessage = '${order['consignee_name']} ($code) is already "${order['status']}" — not picking up again.';
        });
        return;
      }

      await supabase.from('orders').update({
        'status': 'picked_up',
        'picked_up_at': DateTime.now().toIso8601String(),
        'assigned_collection_id': supabase.auth.currentUser!.id,
      }).eq('id', order['id']);

      setState(() {
        _lastSuccess = true;
        _lastMessage = 'Picked up: ${order['consignee_name']} ($code)';
      });
    } catch (e) {
      setState(() {
        _lastSuccess = false;
        _lastMessage = 'Error: $e';
      });
    } finally {
      // Small delay so the same barcode isn't scanned twice instantly
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection — Scan to Pick Up'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => supabase.auth.signOut()),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  _handleScan(barcodes.first.rawValue!);
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: _lastMessage == null
                  ? Colors.grey.shade100
                  : (_lastSuccess ? Colors.green.shade50 : Colors.red.shade50),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _processing
                    ? const CircularProgressIndicator()
                    : Text(
                        _lastMessage ?? 'Point the camera at an order barcode',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _lastMessage == null
                              ? Colors.black54
                              : (_lastSuccess ? Colors.green.shade800 : Colors.red.shade800),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}