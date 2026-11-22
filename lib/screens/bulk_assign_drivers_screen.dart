import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:csv/csv.dart';
import '../utils/xlsx_repair.dart';
import '../main.dart';
import '../theme/app_theme.dart';

/// Lets a dispatcher upload the same AWB + Driver sheet used for the daily
/// assignment round and assign every order in one shot, instead of
/// filtering by driver, selecting all matching rows, and running Bulk Edit
/// once per driver.
///
/// The file only needs two columns — "AWB" and "Driver" (or "Driv") — extra
/// columns (Merchant, Consignee Name, etc.) are ignored, so the exact sheet
/// used for manual assignment can be uploaded as-is.
class BulkAssignDriversScreen extends StatefulWidget {
  const BulkAssignDriversScreen({super.key});

  @override
  State<BulkAssignDriversScreen> createState() => _BulkAssignDriversScreenState();
}

class _BulkAssignDriversScreenState extends State<BulkAssignDriversScreen> {
  String? _fileName;
  bool _parsing = false;
  bool _checking = false;
  bool _applying = false;
  List<Map<String, String>> _pairs = [];
  String? _parseError;

  // Result of the last dry-run / apply call from bulk_assign_drivers().
  List<String> _assigned = [];
  List<Map<String, dynamic>> _skippedStatus = [];
  List<String> _unmatchedOrders = [];
  List<Map<String, dynamic>> _unmatchedDrivers = [];
  bool _previewed = false;
  bool _applied = false;

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
      _parseError = null;
      _pairs = [];
      _previewed = false;
      _applied = false;
    });

    try {
      List<List<dynamic>> rows;
      if (file.name.toLowerCase().endsWith('.csv')) {
        final content = String.fromCharCodes(file.bytes!);
        rows = const CsvToListConverter().convert(content, eol: '\n');
      } else {
        final excelFile = xl.Excel.decodeBytes(repairXlsxNumFmts(file.bytes!));
        final sheet = excelFile.tables[excelFile.tables.keys.first]!;
        rows = sheet.rows.map((row) => row.map((cell) => cell?.value ?? '').toList()).toList();
      }
      _processRows(rows);
    } catch (e) {
      setState(() => _parseError = 'Could not read file: $e');
    } finally {
      setState(() => _parsing = false);
    }
  }

  void _processRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      setState(() => _parseError = 'File appears to be empty');
      return;
    }

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final awbIdx = headers.indexWhere((h) => h.toLowerCase() == 'awb');
    final driverIdx = headers.indexWhere((h) => h.toLowerCase() == 'driver' || h.toLowerCase() == 'driv');

    if (awbIdx == -1 || driverIdx == -1) {
      setState(() => _parseError = 'Could not find "AWB" and "Driver" columns. Found headers: ${headers.join(', ')}');
      return;
    }

    final pairs = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.toString().trim().isEmpty)) continue;

      final awb = awbIdx < row.length ? row[awbIdx].toString().trim() : '';
      final driver = driverIdx < row.length ? row[driverIdx].toString().trim() : '';
      if (awb.isEmpty || driver.isEmpty) continue;

      pairs.add({'awb': awb, 'driver_name': driver});
    }

    setState(() => _pairs = pairs);
  }

  Future<void> _preview() async {
    if (_pairs.isEmpty) return;
    setState(() => _checking = true);
    try {
      final result = await supabase.rpc('bulk_assign_drivers', params: {
        'p_assignments': _pairs,
        'p_dry_run': true,
      });
      _applyResult(result);
      setState(() => _previewed = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not check file: $e')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _confirmApply() async {
    setState(() => _applying = true);
    try {
      final result = await supabase.rpc('bulk_assign_drivers', params: {
        'p_assignments': _pairs,
        'p_dry_run': false,
      });
      _applyResult(result);
      setState(() => _applied = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_assigned.length} order(s) assigned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assignment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _applyResult(dynamic result) {
    final map = Map<String, dynamic>.from(result as Map);
    setState(() {
      _assigned = List<String>.from(map['assigned'] ?? []);
      _skippedStatus = List<Map<String, dynamic>>.from(
          (map['skipped_status'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      _unmatchedOrders = List<String>.from(map['unmatched_orders'] ?? []);
      _unmatchedDrivers = List<Map<String, dynamic>>.from(
          (map['unmatched_drivers'] ?? []).map((e) => Map<String, dynamic>.from(e)));
    });
  }

  Widget _issueSection(String title, Color color, List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
          const SizedBox(height: 4),
          ...items,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasIssues = _unmatchedOrders.isNotEmpty || _unmatchedDrivers.isNotEmpty || _skippedStatus.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Assign Drivers'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Upload the same AWB + Driver sheet used for the daily assignment round. '
                  'Only "AWB" and "Driver" columns are read — any other columns are ignored.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(_fileName ?? 'Choose .xlsx or .csv file'),
              onPressed: _parsing ? null : _pickFile,
            ),
            if (_parseError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_parseError!, style: const TextStyle(color: AppColors.statusFailed, fontSize: 12)),
              ),
            const SizedBox(height: 16),
            if (_parsing) const Center(child: CircularProgressIndicator()),
            if (!_parsing && _pairs.isNotEmpty && !_previewed)
              Row(
                children: [
                  Text('${_pairs.length} row(s) read from file', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  FilledButton(
                    onPressed: _checking ? null : _preview,
                    child: _checking
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Check File'),
                  ),
                ],
              ),
            if (_previewed)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_assigned.length} order(s) ready to ${_applied ? 'were' : 'be'} assigned',
                        style: const TextStyle(color: AppColors.statusDelivered, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      _issueSection(
                        '${_unmatchedOrders.length} AWB(s) not found',
                        AppColors.statusFailed,
                        [Text(_unmatchedOrders.join(', '), style: const TextStyle(fontSize: 12))],
                      ),
                      _issueSection(
                        '${_unmatchedDrivers.length} unrecognized driver name(s)',
                        Colors.orange.shade800,
                        _unmatchedDrivers
                            .map((u) => Text('${u['awb']} → "${u['driver_name']}"', style: const TextStyle(fontSize: 12)))
                            .toList(),
                      ),
                      _issueSection(
                        '${_skippedStatus.length} order(s) skipped (already delivered / cancelled / returned)',
                        AppColors.textSecondary,
                        _skippedStatus
                            .map((s) => Text('${s['awb']} (${statusRawDisplay(s['status'])})', style: const TextStyle(fontSize: 12)))
                            .toList(),
                      ),
                      if (hasIssues && !_applied)
                        const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: Text(
                            'Fix the rows above in your file and re-upload, or continue — unmatched rows are simply skipped.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_previewed && !_applied)
              FilledButton(
                onPressed: (_assigned.isEmpty || _applying) ? null : _confirmApply,
                child: _applying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Confirm & Assign ${_assigned.length} Order(s)'),
              ),
            if (_applied)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }
}