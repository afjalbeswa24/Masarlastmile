import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import '../main.dart';

class MerchantExportDialog extends StatefulWidget {
  const MerchantExportDialog({super.key});

  @override
  State<MerchantExportDialog> createState() => _MerchantExportDialogState();
}

class _MerchantExportDialogState extends State<MerchantExportDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _exporting = false;

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final merchantId = supabase.auth.currentUser!.id;

      final orders = await supabase
          .from('orders')
          .select()
          .eq('merchant_id', merchantId)
          .gte('created_at', _startDate.toIso8601String())
          .lte('created_at', _endDate.add(const Duration(days: 1)).toIso8601String())
          .order('created_at');

      final workbook = xl.Excel.createExcel();
      final sheet = workbook['Orders'];
      workbook.delete('Sheet1');

      // Driver and Punctuality intentionally excluded — merchants only see their own order details.
      sheet.appendRow([
        'AWB', 'Status', 'Consignee Name', 'Phone', 'Full Address', 'City',
        'Quantity', 'COD Amount', 'Delivery Date', 'Notes'
      ].map((h) => xl.TextCellValue(h)).toList());

      for (final o in orders) {
        sheet.appendRow([
          xl.TextCellValue(o['order_code'] ?? ''),
          xl.TextCellValue(o['status'] ?? ''),
          xl.TextCellValue(o['consignee_name'] ?? ''),
          xl.TextCellValue(o['phone'] ?? ''),
          xl.TextCellValue(o['full_address'] ?? ''),
          xl.TextCellValue(o['city'] ?? ''),
          xl.TextCellValue('${o['quantity'] ?? ''}'),
          xl.TextCellValue('${o['cod_amount'] ?? ''}'),
          xl.TextCellValue(o['delivery_date'] ?? ''),
          xl.TextCellValue(o['notes'] ?? ''),
        ]);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw Exception('Could not generate file');

      await FileSaver.instance.saveFile(
        name: 'my_orders_${_fmtDate(_startDate)}_to_${_fmtDate(_endDate)}',
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
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Download Report'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('From: ${_fmtDate(_startDate)}'),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () => _pickDate(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('To: ${_fmtDate(_endDate)}'),
              trailing: const Icon(Icons.calendar_today, size: 18),
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