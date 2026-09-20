import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/date_range_button.dart';

class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({super.key});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  bool _loading = true;
  DateTimeRange? _range;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _range = DateTimeRange(start: DateTime(today.year, today.month, today.day), end: DateTime(today.year, today.month, today.day));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final start = _range!.start;
    final end = _range!.end.add(const Duration(days: 1)); // inclusive of the whole end day

    final data = await supabase
        .from('order_audit_log')
        .select('''
          id, order_id, changed_by, action_type, field, old_value, new_value, created_at, ip_address, user_agent, order_code_snapshot, undone_at, undone_by,
          order:orders(order_code),
          user:profiles!order_audit_log_changed_by_fkey(full_name, role)
        ''')
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String())
        .order('created_at', ascending: false)
        .range(0, 19999);

    final rows = List<Map<String, dynamic>>.from(data);
    // Drivers and warehouse staff have their own separate scan-based
    // activity — this view is specifically for the people managing orders
    // day to day: dispatchers, master dispatchers, and merchants.
    rows.removeWhere((r) {
      final role = r['user']?['role'];
      return role == null || role == 'driver' || role == 'warehouse' || role == 'collection';
    });

    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Map<String, Map<String, dynamic>> get _byUser {
    final Map<String, Map<String, dynamic>> result = {};
    for (final r in _rows) {
      // changed_by should always be a real user for genuine activity, but
      // this guards against any row that somehow lacks one (a system
      // action, bad data, etc.) rather than crashing the whole screen.
      final userId = r['changed_by'] as String?;
      if (userId == null) continue;
      final entry = result.putIfAbsent(userId, () => {
            'name': r['user']?['full_name'] ?? 'Unknown',
            'role': r['user']?['role'] ?? '',
            'created': 0,
            'deleted': 0,
            'edited': 0,
            'statusChanged': 0,
            'driverAssigned': 0,
            'lastActive': r['created_at'],
          });
      if (r['action_type'] == 'CREATED') {
        entry['created']++;
      } else if (r['action_type'] == 'DELETED') {
        entry['deleted']++;
      } else if (r['field'] == 'status') {
        entry['statusChanged']++;
      } else if (r['field'] == 'assigned_driver_id') {
        entry['driverAssigned']++;
      } else {
        entry['edited']++;
      }
      // Rows are already sorted newest-first, so the first one seen per
      // user is naturally their most recent action.
    }
    return result;
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'master_dispatcher':
        return 'Master dispatcher';
      case 'dispatcher':
        return 'Dispatcher';
      case 'merchant':
        return 'Merchant';
      default:
        return role;
    }
  }

  String _timeAgo(String iso) {
    final t = DateTime.parse(iso);
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Creation is now logged as a single row per order (not one per field),
  // so counting CREATED rows directly, like every other category, is correct.
  void _openDetail(BuildContext context, String userName, String category, List<Map<String, dynamic>> filtered) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => _UserActivityDetailScreen(userName: '$userName — $category', entries: filtered)));
  }

  List<Map<String, dynamic>> _rowsFor(String userId, {String? actionType, String? field, List<String>? excludeFields}) {
    return _rows.where((r) {
      if (r['changed_by'] != userId) return false;
      if (actionType != null && r['action_type'] != actionType) return false;
      if (field != null && r['field'] != field) return false;
      if (excludeFields != null && excludeFields.contains(r['field'])) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final byUser = _byUser;
    final sortedUserIds = byUser.keys.toList()
      ..sort((a, b) => (byUser[b]!['created'] + byUser[b]!['deleted'] + byUser[b]!['edited'] + byUser[b]!['statusChanged'] + byUser[b]!['driverAssigned'])
          .compareTo(byUser[a]!['created'] + byUser[a]!['deleted'] + byUser[a]!['edited'] + byUser[a]!['statusChanged'] + byUser[a]!['driverAssigned']));

    return Scaffold(
      appBar: AppBar(title: const Text('User Activity')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DateRangeButton(range: _range, onChanged: (r) {
                  setState(() => _range = r ?? _range);
                  _load();
                }),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text('Today'),
                  onPressed: () {
                    final today = DateTime.now();
                    setState(() => _range = DateTimeRange(start: DateTime(today.year, today.month, today.day), end: DateTime(today.year, today.month, today.day)));
                    _load();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: const Text('Last 7 days'),
                  onPressed: () {
                    final today = DateTime.now();
                    setState(() => _range = DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today));
                    _load();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : sortedUserIds.isEmpty
                    ? const Center(child: Text('No activity in this range', style: TextStyle(color: AppColors.textSecondary)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.background),
                            columns: const [
                              DataColumn(label: Text('User')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Created')),
                              DataColumn(label: Text('Deleted')),
                              DataColumn(label: Text('Edited')),
                              DataColumn(label: Text('Status changed')),
                              DataColumn(label: Text('Driver assigned')),
                              DataColumn(label: Text('Last active')),
                            ],
                            rows: sortedUserIds.map((userId) {
                              final u = byUser[userId]!;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(u['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                    onTap: () => _openDetail(context, u['name'], 'All activity', _rowsFor(userId)),
                                  ),
                                  DataCell(Text(_roleLabel(u['role']), style: const TextStyle(color: AppColors.textSecondary))),
                                  DataCell(
                                    Text('${u['created']}'),
                                    onTap: () => _openDetail(context, u['name'], 'Created', _rowsFor(userId, actionType: 'CREATED')),
                                  ),
                                  DataCell(
                                    Text('${u['deleted']}', style: u['deleted'] > 0 ? const TextStyle(color: AppColors.statusFailed, fontWeight: FontWeight.w600) : null),
                                    onTap: () => _openDetail(context, u['name'], 'Deleted', _rowsFor(userId, actionType: 'DELETED')),
                                  ),
                                  DataCell(
                                    Text('${u['edited']}'),
                                    onTap: () => _openDetail(context, u['name'], 'Edited', _rowsFor(userId, actionType: 'UPDATED', excludeFields: ['status', 'assigned_driver_id'])),
                                  ),
                                  DataCell(
                                    Text('${u['statusChanged']}'),
                                    onTap: () => _openDetail(context, u['name'], 'Status changed', _rowsFor(userId, field: 'status')),
                                  ),
                                  DataCell(
                                    Text('${u['driverAssigned']}'),
                                    onTap: () => _openDetail(context, u['name'], 'Driver assigned', _rowsFor(userId, field: 'assigned_driver_id')),
                                  ),
                                  DataCell(Text(_timeAgo(u['lastActive']), style: const TextStyle(color: AppColors.textSecondary))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserActivityDetailScreen extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> entries;
  const _UserActivityDetailScreen({required this.userName, required this.entries});

  @override
  State<_UserActivityDetailScreen> createState() => _UserActivityDetailScreenState();
}

class _UserActivityDetailScreenState extends State<_UserActivityDetailScreen> {
  late List<Map<String, dynamic>> _entries;
  final Set<int> _undoing = {};

  @override
  void initState() {
    super.initState();
    _entries = widget.entries;
  }

  String _describeEntry(Map<String, dynamic> e) {
    // A deleted order has no order_id left to embed a live order through —
    // order_code_snapshot is what keeps this readable after the fact.
    final orderCode = e['order']?['order_code'] ?? e['order_code_snapshot'] ?? 'order';
    if (e['action_type'] == 'CREATED') return 'Created $orderCode';
    if (e['action_type'] == 'DELETED') return 'Deleted $orderCode';
    final field = e['field'] ?? '';
    final oldVal = e['old_value'] ?? '—';
    final newVal = e['new_value'] ?? '—';
    return '$orderCode — $field: $oldVal → $newVal';
  }

  String _fmtTimestamp(String iso) {
    final t = DateTime.parse(iso).toLocal();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _deviceSummary(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) return 'Unknown device';
    final ua = userAgent.toLowerCase();
    final isMobile = ua.contains('mobile') || ua.contains('android') || ua.contains('iphone');
    String browser = 'Unknown browser';
    if (ua.contains('edg/')) {
      browser = 'Edge';
    } else if (ua.contains('chrome')) {
      browser = 'Chrome';
    } else if (ua.contains('firefox')) {
      browser = 'Firefox';
    } else if (ua.contains('safari')) {
      browser = 'Safari';
    }
    return '${isMobile ? 'Mobile' : 'Desktop'} · $browser';
  }

  Future<void> _confirmAndUndo(Map<String, dynamic> entry, int index) async {
    final isDelete = entry['action_type'] == 'DELETED';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDelete ? 'Restore this order?' : 'Undo this change?'),
        content: Text(
          isDelete
              ? 'This will bring the order and its boxes back exactly as they were, including any notes.'
              : 'This will revert "${entry['field']}" back to its previous value: ${entry['old_value'] ?? '—'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isDelete ? 'Restore' : 'Undo')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _undoing.add(entry['id']));
    try {
      final result = await supabase.rpc('undo_audit_entry', params: {'p_audit_id': entry['id']});
      final success = result['success'] == true;
      final message = result['message'] ?? (success ? 'Done.' : 'Something went wrong.');

      if (success) {
        setState(() {
          _entries[index] = {..._entries[index], 'undone_at': DateTime.now().toIso8601String()};
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: success ? AppColors.statusDelivered : AppColors.statusFailed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach the server — try again.'), backgroundColor: AppColors.statusFailed),
        );
      }
    } finally {
      if (mounted) setState(() => _undoing.remove(entry['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.userName)),
      body: _entries.isEmpty
          ? const Center(child: Text('No actions in this range', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = _entries[index];
                final ip = e['ip_address'];
                final isDelete = e['action_type'] == 'DELETED';
                final isCreated = e['action_type'] == 'CREATED';
                final alreadyUndone = e['undone_at'] != null;
                final isBusy = _undoing.contains(e['id']);
                return ListTile(
                  dense: true,
                  title: Text(
                    _describeEntry(e),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDelete ? AppColors.statusFailed : null,
                      fontWeight: isDelete ? FontWeight.w600 : null,
                      decoration: alreadyUndone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    ip != null ? '${_deviceSummary(e['user_agent'])} · $ip' : 'Device info unavailable for this entry',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_fmtTimestamp(e['created_at']), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      if (!isCreated) ...[
                        const SizedBox(width: 8),
                        if (alreadyUndone)
                          const Text('Undone', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic))
                        else if (isBusy)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          TextButton(
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                            onPressed: () => _confirmAndUndo(e, index),
                            child: Text(isDelete ? 'Restore' : 'Undo', style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}