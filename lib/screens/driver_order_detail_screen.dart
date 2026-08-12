import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';
import 'driver_proof_screen.dart';
import '../utils/qatar_time.dart';

class DriverOrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const DriverOrderDetailScreen({super.key, required this.order});

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : '—', style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'pending';
    final canAct = status == 'out_for_delivery';

    return Scaffold(
      appBar: AppBar(
        title: Text('Task #${order['order_number'] ?? ''}'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(order['consignee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            ),
                            StatusPill(status: status),
                          ],
                        ),
                        const Divider(height: 24),
                        _row('Phone', order['phone']),
                        _row('Address', order['full_address']),
                        _row('City', order['city']),
                        _row('AWB', order['order_code']),
                        _row('Quantity', '${order['quantity'] ?? ''}'),
                        _row('COD Amount', '${order['cod_amount'] ?? ''}'),
                        _row('Delivery Window', order['delivery_window_start'] != null ? '${QatarTime.trimSeconds(order['delivery_window_start'])} - ${QatarTime.trimSeconds(order['delivery_window_end'])}' : null),
                        _row('Notes', order['notes']),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (canAct)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusDelivered, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DriverProofScreen(order: order, isComplete: true))),
                        child: const Text('COMPLETE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusFailed, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DriverProofScreen(order: order, isComplete: false))),
                        child: const Text('FAIL'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}