import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/date_range_button.dart';

class AuditLogCleanupScreen extends StatefulWidget {
  const AuditLogCleanupScreen({super.key});

  @override
  State<AuditLogCleanupScreen> createState() => _AuditLogCleanupScreenState();
}

class _AuditLogCleanupScreenState extends State<AuditLogCleanupScreen> {
  DateTimeRange? _range;
  bool _loadingPreview = false;
  bool _purging = false;
  int? _total;

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _preview() async {
    if (_range == null) return;
    setState(() {
      _loadingPreview = true;
      _total = null;
    });
    try {
      final result = await supabase.rpc('preview_audit_purge', params: {
        'p_start': _fmtDate(_range!.start),
        'p_end': _fmtDate(_range!.end),
      });
      if (result['success'] == true) {
        setState(() => _total = result['total']);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Could not check this range.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _confirmAndPurge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete these logs?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently remove $_total log entries belonging to orders that have already been deleted, from ${_fmtDate(_range!.start)} to ${_fmtDate(_range!.end)}.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Once purged, those orders can no longer be restored with Undo. Nothing belonging to a still-active order is ever touched.',
              style: TextStyle(color: AppColors.statusFailed, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('This cannot be undone.', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusFailed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _purging = true);
    try {
      final result = await supabase.rpc('purge_audit_log', params: {
        'p_start': _fmtDate(_range!.start),
        'p_end': _fmtDate(_range!.end),
      });
      final success = result['success'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Deleted ${result['deleted_count']} entries.' : (result['message'] ?? 'Something went wrong.')),
            backgroundColor: success ? AppColors.statusDelivered : AppColors.statusFailed,
          ),
        );
      }
      if (success) {
        setState(() => _total = null);
      }
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log Cleanup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scope is stated plainly here, not just explained elsewhere —
            // this tool only ever touches logs belonging to orders that no
            // longer exist. History for a still-active order is never
            // eligible, no matter what date range is picked.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.purpleLight, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.purple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only clears log entries for orders that have already been deleted. History for any order that still exists is never touched, regardless of the date range picked.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.purple),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DateRangeButton(range: _range, onChanged: (r) => setState(() {
                  _range = r;
                  _total = null;
                })),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: (_range == null || _loadingPreview) ? null : _preview,
                  child: _loadingPreview
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_total != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _total == 0
                            ? 'No deleted-order log entries in this range.'
                            : '$_total log entr${_total == 1 ? 'y' : 'ies'} found, belonging to deleted orders in this range.',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if ((_total ?? 0) > 0) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Purging removes the ability to restore these orders with Undo. Active orders are unaffected either way.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.statusFailed),
                icon: _purging
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delete_forever),
                label: Text(_purging ? 'Deleting…' : 'Permanently Delete These Entries'),
                onPressed: (_total == 0 || _purging) ? null : _confirmAndPurge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}