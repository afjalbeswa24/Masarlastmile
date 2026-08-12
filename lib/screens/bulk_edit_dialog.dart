import 'package:flutter/material.dart';
import '../main.dart';

class BulkEditDialog extends StatefulWidget {
  final List<String> orderIds;
  final String? initialStatus;
  const BulkEditDialog({super.key, required this.orderIds, this.initialStatus});

  @override
  State<BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<BulkEditDialog> {
  List<Map<String, dynamic>> _drivers = [];
  String? _selectedDriverId;
  String? _selectedStatus;
  String? _selectedDeliveryType;
  bool? _selectedRemoteArea;
  DateTime? _deliveryDate;
  TimeOfDay? _windowStart;
  TimeOfDay? _windowEnd;
  bool _saving = false;

  final _statuses = ['pending', 'picked_up', 'sorted', 'assigned', 'out_for_delivery', 'delivered', 'failed', 'cancelled', 'rescheduled', 'returned_to_shipper'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    final data = await supabase.from('profiles').select('id, full_name').eq('role', 'driver');
    setState(() => _drivers = List<Map<String, dynamic>>.from(data));
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _apply() async {
    setState(() => _saving = true);

    final updates = <String, dynamic>{};
    if (_selectedDriverId == '__unassign__') {
      updates['assigned_driver_id'] = null;
    } else if (_selectedDriverId != null) {
      updates['assigned_driver_id'] = _selectedDriverId;
    }
    if (_selectedStatus != null) updates['status'] = _selectedStatus;
    if (_selectedDeliveryType != null) updates['delivery_type'] = _selectedDeliveryType;
    if (_selectedRemoteArea != null) updates['remote_area'] = _selectedRemoteArea;
    if (_deliveryDate != null) {
      updates['delivery_date'] =
          '${_deliveryDate!.year}-${_deliveryDate!.month.toString().padLeft(2, '0')}-${_deliveryDate!.day.toString().padLeft(2, '0')}';
    }
    if (_windowStart != null) updates['delivery_window_start'] = _fmtTime(_windowStart!);
    if (_windowEnd != null) updates['delivery_window_end'] = _fmtTime(_windowEnd!);

    if (updates.isEmpty) {
      setState(() => _saving = false);
      if (mounted) Navigator.pop(context, false);
      return;
    }

    try {
      await supabase.from('orders').update(updates).inFilter('id', widget.orderIds);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bulk Edit (${widget.orderIds.length} orders)'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Leave a field empty to keep it unchanged for the selected orders.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedDriverId,
                decoration: const InputDecoration(labelText: 'Assign Driver', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '__unassign__', child: Text('Unassign (remove driver)')),
                  ..._drivers.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['full_name'] ?? 'Unnamed'))),
                ],
                onChanged: (v) => setState(() => _selectedDriverId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _selectedStatus = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedDeliveryType,
                decoration: const InputDecoration(labelText: 'Delivery Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'express', child: Text('Express')),
                  DropdownMenuItem(value: 'same_day', child: Text('Same Day')),
                  DropdownMenuItem(value: 'on_demand', child: Text('On Demand')),
                ],
                onChanged: (v) => setState(() => _selectedDeliveryType = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<bool>(
                initialValue: _selectedRemoteArea,
                decoration: const InputDecoration(labelText: 'Remote Area', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Yes')),
                  DropdownMenuItem(value: false, child: Text('No')),
                ],
                onChanged: (v) => setState(() => _selectedRemoteArea = v),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_deliveryDate == null ? 'Delivery Date: not set' : 'Delivery Date: ${_deliveryDate!.toLocal()}'.split(' ')[0]),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _deliveryDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_windowStart == null ? 'After: not set' : 'After: ${_windowStart!.format(context)}'),
                trailing: const Icon(Icons.access_time, size: 20),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (picked != null) setState(() => _windowStart = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_windowEnd == null ? 'Before: not set' : 'Before: ${_windowEnd!.format(context)}'),
                trailing: const Icon(Icons.access_time, size: 20),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (picked != null) setState(() => _windowEnd = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _apply,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Apply'),
        ),
      ],
    );
  }
}