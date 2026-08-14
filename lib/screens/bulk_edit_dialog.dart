import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_time_picker.dart';

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

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.6)),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      );

  Widget _pickerBox({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(value, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.purpleLight, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.edit_note, color: AppColors.purple, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bulk Edit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text('${widget.orderIds.length} orders selected', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 20),
                  child: Text('Leave a field empty to keep it unchanged for the selected orders.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),

                _sectionLabel('Assignment'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDriverId,
                        decoration: _decoration('Assign Driver'),
                        items: [
                          const DropdownMenuItem(value: '__unassign__', child: Text('Unassign (remove driver)')),
                          ..._drivers.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['full_name'] ?? 'Unnamed'))),
                        ],
                        onChanged: (v) => setState(() => _selectedDriverId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: _decoration('Status'),
                        items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _sectionLabel('Delivery Details'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDeliveryType,
                        decoration: _decoration('Delivery Type'),
                        items: const [
                          DropdownMenuItem(value: 'standard', child: Text('Standard')),
                          DropdownMenuItem(value: 'express', child: Text('Express')),
                          DropdownMenuItem(value: 'same_day', child: Text('Same Day')),
                          DropdownMenuItem(value: 'on_demand', child: Text('On Demand')),
                        ],
                        onChanged: (v) => setState(() => _selectedDeliveryType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        initialValue: _selectedRemoteArea,
                        decoration: _decoration('Remote Area'),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Yes')),
                          DropdownMenuItem(value: false, child: Text('No')),
                        ],
                        onChanged: (v) => setState(() => _selectedRemoteArea = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _sectionLabel('Schedule'),
                _pickerBox(
                  label: 'Delivery Date',
                  value: _deliveryDate == null ? 'Not set' : '${_deliveryDate!.toLocal()}'.split(' ')[0],
                  icon: Icons.calendar_today,
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
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _pickerBox(
                        label: 'After',
                        value: _windowStart == null ? 'Not set' : _windowStart!.format(context),
                        icon: Icons.access_time,
                        onTap: () async {
                          final picked = await showCompactTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked != null) setState(() => _windowStart = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerBox(
                        label: 'Before',
                        value: _windowEnd == null ? 'Not set' : _windowEnd!.format(context),
                        icon: Icons.access_time,
                        onTap: () async {
                          final picked = await showCompactTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked != null) setState(() => _windowEnd = picked);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.purple, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                      onPressed: _saving ? null : _apply,
                      child: _saving
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}