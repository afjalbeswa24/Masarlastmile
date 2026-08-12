import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/qatar_time.dart';

class AuditTrailDialog extends StatefulWidget {
  final String orderId;
  final String orderCode;
  const AuditTrailDialog({super.key, required this.orderId, required this.orderCode});

  @override
  State<AuditTrailDialog> createState() => _AuditTrailDialogState();
}

class _AuditTrailDialogState extends State<AuditTrailDialog> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  final ScrollController _hController = ScrollController();
  final ScrollController _vController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hController.dispose();
    _vController.dispose();
    super.dispose();
  }

  // These fields are just the technical "when did this happen" timestamps —
  // already implicitly shown by the log's own Date Time column and the
  // status-change row next to them, so we hide them here to reduce noise.
  static const _hiddenFields = {
    'picked_up_at', 'sorted_at', 'out_for_delivery_at', 'delivered_at',
    'collection_assigned_at', 'assigned_at', 'delivery_date',
    'delivery_window_start', 'delivery_window_end', 'created_at',
    'delivery_sequence', 'proof_photo_url', 'proof_photo_url_2',
    'dropoff_lat', 'dropoff_lng', 'delivered_lat', 'delivered_lng',
  };

  Future<void> _load() async {
    final data = await supabase
        .from('order_audit_log')
        .select('id, created_at, action_type, field, old_value, new_value, user:profiles!order_audit_log_changed_by_fkey(full_name)')
        .eq('order_id', widget.orderId)
        .order('created_at', ascending: false);

    final all = List<Map<String, dynamic>>.from(data);
    final filtered = all.where((log) => !_hiddenFields.contains(log['field'])).toList();

    setState(() {
      _logs = filtered;
      _loading = false;
    });
  }

  String _fmt(String iso) {
    final d = QatarTime.fromIso(iso);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // Timestamp-type fields (like sorted_at, out_for_delivery_at, delivered_at)
  // get stored/shown as raw UTC strings with microseconds — this cleans them
  // up into readable Qatar-time values for the timeline, same as everywhere else.
  bool _looksLikeTimestamp(String? value) {
    if (value == null) return false;
    return RegExp(r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}').hasMatch(value);
  }

  String _formatValue(String? value) {
    if (value == null || value.isEmpty) return '';
    if (_looksLikeTimestamp(value)) {
      try {
        final normalized = value.replaceFirst(' ', 'T');
        final d = QatarTime.fromIso(normalized);
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Task ${widget.orderCode} Timeline',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No history recorded yet for this order.', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              Flexible(
                child: Scrollbar(
                  controller: _hController,
                  thumbVisibility: true,
                  notificationPredicate: (n) => n.depth == 0,
                  child: SingleChildScrollView(
                    controller: _hController,
                    scrollDirection: Axis.horizontal,
                    child: Scrollbar(
                      controller: _vController,
                      thumbVisibility: true,
                      notificationPredicate: (n) => n.depth == 0,
                      child: SingleChildScrollView(
                        controller: _vController,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.background),
                          columns: const [
                            DataColumn(label: Text('Date Time')),
                            DataColumn(label: Text('User')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Field')),
                            DataColumn(label: Text('Old Value')),
                            DataColumn(label: Text('New Value')),
                          ],
                          rows: _logs.map((log) {
                            return DataRow(cells: [
                              DataCell(Text(_fmt(log['created_at']))),
                              DataCell(Text(log['user']?['full_name'] ?? 'System')),
                              DataCell(Text(log['action_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(log['field'] ?? '')),
                              DataCell(Text(_formatValue(log['old_value']))),
                                        DataCell(Text(_formatValue(log['new_value']))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}