import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class DispatcherBulkUploadScreen extends StatefulWidget {
  const DispatcherBulkUploadScreen({super.key});

  @override
  State<DispatcherBulkUploadScreen> createState() => _DispatcherBulkUploadScreenState();
}

class _DispatcherBulkUploadScreenState extends State<DispatcherBulkUploadScreen> {
  List<Map<String, dynamic>> _merchants = [];
  String? _selectedMerchantId;
  DateTime? _defaultDeliveryDate;

  List<Map<String, dynamic>> _validRows = [];
  List<String> _errors = [];
  bool _parsing = false;
  bool _uploading = false;
  String? _fileName;

  final _requiredColumns = ['Consignee Name', 'Phone', 'Full Address'];

  @override
  void initState() {
    super.initState();
    _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    final data = await supabase.from('profiles').select('id, full_name').eq('role', 'merchant');
    setState(() => _merchants = List<Map<String, dynamic>>.from(data));
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _readyToUpload => _selectedMerchantId != null && _defaultDeliveryDate != null;

  Future<void> _downloadTemplate() async {
    final workbook = xl.Excel.createExcel();
    final sheet = workbook['Template'];
    workbook.delete('Sheet1');

    final headers = [
      'Consignee Name', 'Phone', 'Full Address', 'City', 'Quantity',
      'COD Amount', 'Delivery Date', 'After', 'Before', 'Notes'
    ];
    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());

    sheet.appendRow([
      xl.TextCellValue('Ahmed Al-Sayed'),
      xl.TextCellValue('97455529019'),
      xl.TextCellValue('Zone 67, Street 850, Building 115'),
      xl.TextCellValue('Doha'),
      xl.TextCellValue('2'),
      xl.TextCellValue('150'),
      xl.TextCellValue('2026-07-20'),
      xl.TextCellValue('08:00'),
      xl.TextCellValue('12:00'),
      xl.TextCellValue('Leave at reception'),
    ]);

    final bytes = workbook.encode();
    if (bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'bulk_upload_template',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    setState(() {
      _fileName = file.name;
      _parsing = true;
      _validRows = [];
      _errors = [];
    });

    try {
      List<List<dynamic>> rows;
      if (file.name.toLowerCase().endsWith('.csv')) {
        final content = String.fromCharCodes(file.bytes!);
        rows = const CsvToListConverter().convert(content, eol: '\n');
      } else {
        final excelFile = xl.Excel.decodeBytes(file.bytes!);
        final sheet = excelFile.tables[excelFile.tables.keys.first]!;
        rows = sheet.rows
            .map((row) => row.map((cell) => cell?.value ?? '').toList())
            .toList();
      }

      _processRows(rows);
    } catch (e) {
      setState(() => _errors = ['Could not read file: $e']);
    } finally {
      setState(() => _parsing = false);
    }
  }

  void _processRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      setState(() => _errors = ['File appears to be empty']);
      return;
    }

    final headers = rows.first.map((h) => h.toString().trim()).toList();

    for (final col in _requiredColumns) {
      if (!headers.contains(col)) {
        setState(() => _errors = ['Missing required column: "$col". Check your file headers match the template.']);
        return;
      }
    }

    final valid = <Map<String, dynamic>>[];
    final errors = <String>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.toString().trim().isEmpty)) continue;

      final rowMap = <String, String>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        rowMap[headers[j]] = row[j].toString().trim();
      }

      final consignee = rowMap['Consignee Name'] ?? '';
      final phone = rowMap['Phone'] ?? '';
      final address = rowMap['Full Address'] ?? '';

      if (consignee.isEmpty || phone.isEmpty || address.isEmpty) {
        errors.add('Row ${i + 1}: missing required field(s) (Consignee Name / Phone / Full Address)');
        continue;
      }

      valid.add({
        'consignee_name': consignee,
        'phone': phone,
        'full_address': address,
        'city': rowMap['City'] ?? '',
        'quantity': int.tryParse(rowMap['Quantity'] ?? '') ?? 1,
        'cod_amount': double.tryParse(rowMap['COD Amount'] ?? '') ?? 0,
        // Row's own date/slot wins if present, otherwise fall back to the selected default
        'delivery_date': (rowMap['Delivery Date']?.isNotEmpty ?? false)
            ? rowMap['Delivery Date']
            : _fmtDate(_defaultDeliveryDate!),
        'delivery_window_start': (rowMap['After']?.isNotEmpty ?? false) ? '${rowMap['After']}:00' : null,
        'delivery_window_end': (rowMap['Before']?.isNotEmpty ?? false) ? '${rowMap['Before']}:00' : null,
        'notes': rowMap['Notes'] ?? '',
      });
    }

    setState(() {
      _validRows = valid;
      _errors = errors;
    });
  }

  Future<void> _uploadAll() async {
    if (_validRows.isEmpty) return;
    setState(() => _uploading = true);

    try {
      final rowsWithMerchant = _validRows.map((r) => {...r, 'merchant_id': _selectedMerchantId}).toList();
      await supabase.from('orders').insert(rowsWithMerchant);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_validRows.length} orders uploaded successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Upload Orders'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Step 1: Choose merchant and delivery date', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMerchantId,
                      decoration: const InputDecoration(labelText: 'Merchant', border: OutlineInputBorder()),
                      items: _merchants.map((m) => DropdownMenuItem(value: m['id'] as String, child: Text(m['full_name'] ?? 'Unnamed'))).toList(),
                      onChanged: (v) => setState(() => _selectedMerchantId = v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: AppColors.border)),
                      title: Text(_defaultDeliveryDate == null ? 'Delivery Date (default for all rows)' : _fmtDate(_defaultDeliveryDate!)),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _defaultDeliveryDate = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.purpleLight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: AppColors.purple),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Not sure of the format? Download a sample file with all columns filled in.', style: TextStyle(fontSize: 13)),
                    ),
                    TextButton(onPressed: _downloadTemplate, child: const Text('Download Sample')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(_fileName ?? 'Choose .xlsx or .csv file'),
              onPressed: (!_readyToUpload || _parsing) ? null : _pickFile,
            ),
            if (!_readyToUpload)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Select a merchant and delivery date above to enable file upload.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 16),
            if (_parsing) const Center(child: CircularProgressIndicator()),
            if (!_parsing && (_validRows.isNotEmpty || _errors.isNotEmpty))
              Expanded(
                child: ListView(
                  children: [
                    if (_validRows.isNotEmpty)
                      Text('${_validRows.length} order(s) ready to upload',
                          style: const TextStyle(color: AppColors.statusDelivered, fontWeight: FontWeight.bold)),
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${_errors.length} row(s) with issues:',
                          style: const TextStyle(color: AppColors.statusFailed, fontWeight: FontWeight.bold)),
                      ..._errors.map((e) => Text('• $e', style: const TextStyle(color: AppColors.statusFailed, fontSize: 12))),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (_validRows.isNotEmpty)
              FilledButton(
                onPressed: _uploading ? null : _uploadAll,
                child: _uploading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Upload ${_validRows.length} Orders'),
              ),
          ],
        ),
      ),
    );
  }
}