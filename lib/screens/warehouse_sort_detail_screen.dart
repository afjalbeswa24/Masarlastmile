import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/box_scan_service.dart';

class WarehouseSortDetailScreen extends StatefulWidget {
  final Map<String, dynamic> box;
  final Map<String, dynamic> order;
  const WarehouseSortDetailScreen({super.key, required this.box, required this.order});

  @override
  State<WarehouseSortDetailScreen> createState() => _WarehouseSortDetailScreenState();
}

class _WarehouseSortDetailScreenState extends State<WarehouseSortDetailScreen> {
  bool _submitting = false;

  Widget _row(String label, String? value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Flexible(
            child: Text(
              value?.isNotEmpty == true ? value! : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSort() async {
    setState(() => _submitting = true);
    try {
      await BoxScanService.markStage(widget.box['id'], widget.box['order_id'], 'sorted');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final box = widget.box;
    final driverName = order['driver']?['full_name'] as String?;
    final hasDriver = driverName != null && driverName.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('#${box['box_code'] ?? ''}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          statusLabel(order['status'] ?? 'pending').toUpperCase(),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: statusColor(order['status'] ?? 'pending'),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E9DD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Box ${box['box_number']}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border.all(color: hasDriver ? AppColors.purple : AppColors.statusFailed),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          hasDriver ? 'Driver: $driverName' : 'No driver assigned!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: hasDriver ? AppColors.purple : AppColors.statusFailed,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (!hasDriver)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'This order cannot be sorted until a dispatcher assigns a driver.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _row('Delivery Date', order['delivery_date']),
                    _row('Box Code', box['box_code']),
                    _row('Consignee', order['consignee_name']),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: hasDriver ? null : Colors.grey.shade400,
                  ),
                  onPressed: (!hasDriver || _submitting) ? null : _confirmSort,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(hasDriver ? 'CONTINUE' : 'ASSIGN A DRIVER FIRST', style: const TextStyle(letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}