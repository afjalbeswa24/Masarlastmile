import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import '../main.dart';
import '../utils/qatar_time.dart';

class ExportDialog extends StatefulWidget {
  final Map<String, bool> columnVisibility;
  const ExportDialog({super.key, required this.columnVisibility});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _exporting = false;

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _setQuickRange(int daysBack) {
    setState(() {
      _startDate = DateTime.now().subtract(Duration(days: daysBack));
      _endDate = DateTime.now();
    });
  }

  // Same column set/order as the on-screen grid (excluding POD/Audit, which
  // are UI-only actions with no exportable data value).
  static const _columnMap = <String, String>{
    'id': 'ID',
    'merchant': 'Merchant',
    'status': 'Status',
    'date': 'Delivery Date',
    'after': 'After',
    'before': 'Before',
    'awb': 'AWB',
    'company': 'Company',
    'driver': 'Driver',
    'quantity': 'Quantity',
    'cod': 'COD Amount',
    'consignee': 'Consignee Name',
    'address': 'Full Address',
    'city': 'City',
    'phone': 'Phone',
    'delivery_start': 'Delivery Start',
    'delivery_end': 'Delivery End',
    'collected': 'Collected Amount',
    'failure_reason': 'Failure Reason',
    'punctuality': 'Punctuality',
    'notes': 'Notes',
  };

  String _fmtDateTime(String? iso) {
    if (iso == null) return '';
    final d = QatarTime.fromIso(iso);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _punctualityOf(Map<String, dynamic> o) {
    if (o['status'] != 'delivered' || o['delivered_at'] == null) return '';
    final start = o['delivery_window_start'] as String?;
    final end = o['delivery_window_end'] as String?;
    if (start == null || end == null) return '';
    final delivered = QatarTime.fromIso(o['delivered_at']);
    final hm = QatarTime.hm(delivered);
    if (hm.compareTo(start) < 0) return 'Early';
    if (hm.compareTo(end) > 0) return 'Late';
    return 'On Time';
  }

  Future<void> _export() async {
    setState(() => _exporting = true);

    try {
      final orders = await supabase
          .from('orders')
          .select('''
            order_number, order_code, status, delivery_date,
            delivery_window_start, delivery_window_end, quantity, cod_amount,
            collected_amount, failure_reason, out_for_delivery_at, delivered_at,
            consignee_name, full_address, city, phone, notes,
            merchant:profiles!orders_merchant_id_fkey(full_name),
            driver:profiles!orders_assigned_driver_id_fkey(full_name),
            company:companies(name)
          ''')
          .gte('delivery_date', _fmtDate(_startDate))
          .lte('delivery_date', _fmtDate(_endDate))
          .order('delivery_date');

      final activeKeys = _columnMap.keys.where((k) => widget.columnVisibility[k] ?? false).toList();

      if (activeKeys.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No columns are currently visible. Enable some via Manage Columns first.')),
          );
          setState(() => _exporting = false);
        }
        return;
      }

      final workbook = xl.Excel.createExcel();
      final sheet = workbook['Orders'];
      workbook.delete('Sheet1');

      sheet.appendRow(activeKeys.map((k) => xl.TextCellValue(_columnMap[k]!)).toList());

      for (final order in orders) {
        final row = <xl.CellValue>[];
        for (final key in activeKeys) {
          switch (key) {
            case 'id':
              row.add(xl.TextCellValue('${order['order_number'] ?? ''}'));
              break;
            case 'merchant':
              row.add(xl.TextCellValue(order['merchant']?['full_name'] ?? ''));
              break;
            case 'status':
              row.add(xl.TextCellValue(order['status'] ?? ''));
              break;
            case 'date':
              row.add(xl.TextCellValue(order['delivery_date'] ?? ''));
              break;
            case 'after':
              row.add(xl.TextCellValue(order['delivery_window_start'] ?? ''));
              break;
            case 'before':
              row.add(xl.TextCellValue(order['delivery_window_end'] ?? ''));
              break;
            case 'awb':
              row.add(xl.TextCellValue(order['order_code'] ?? ''));
              break;
            case 'company':
              row.add(xl.TextCellValue(order['company']?['name'] ?? ''));
              break;
            case 'driver':
              row.add(xl.TextCellValue(order['driver']?['full_name'] ?? 'Unassigned'));
              break;
            case 'quantity':
              row.add(xl.TextCellValue('${order['quantity'] ?? ''}'));
              break;
            case 'cod':
              row.add(xl.TextCellValue('${order['cod_amount'] ?? ''}'));
              break;
            case 'consignee':
              row.add(xl.TextCellValue(order['consignee_name'] ?? ''));
              break;
            case 'address':
              row.add(xl.TextCellValue(order['full_address'] ?? ''));
              break;
            case 'city':
              row.add(xl.TextCellValue(order['city'] ?? ''));
              break;
            case 'phone':
              row.add(xl.TextCellValue(order['phone'] ?? ''));
              break;
            case 'delivery_start':
              row.add(xl.TextCellValue(_fmtDateTime(order['out_for_delivery_at'])));
              break;
            case 'delivery_end':
              row.add(xl.TextCellValue(_fmtDateTime(order['delivered_at'])));
              break;
            case 'collected':
              row.add(xl.TextCellValue(order['collected_amount'] != null ? '${order['collected_amount']}' : ''));
              break;
            case 'failure_reason':
              row.add(xl.TextCellValue(order['failure_reason'] ?? ''));
              break;
            case 'punctuality':
              row.add(xl.TextCellValue(_punctualityOf(order)));
              break;
            case 'notes':
              row.add(xl.TextCellValue(order['notes'] ?? ''));
              break;
          }
        }
        sheet.appendRow(row);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw Exception('Could not generate file');

      await FileSaver.instance.saveFile(
        name: 'orders_${_fmtDate(_startDate)}_to_${_fmtDate(_endDate)}',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Orders'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Exports whichever columns are currently visible (Manage Columns).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () => _setQuickRange(0), child: const Text('Today')),
                OutlinedButton(onPressed: () => _setQuickRange(1), child: const Text('Yesterday')),
                OutlinedButton(onPressed: () => _setQuickRange(7), child: const Text('This Week')),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('From: ${_fmtDate(_startDate)}'),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: () => _pickDate(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('To: ${_fmtDate(_endDate)}'),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: () => _pickDate(false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _exporting ? null : _export,
          child: _exporting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Download Excel'),
        ),
      ],
    );
  }
}