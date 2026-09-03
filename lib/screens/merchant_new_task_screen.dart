import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_time_picker.dart';

class MerchantNewTaskScreen extends StatefulWidget {
  const MerchantNewTaskScreen({super.key});

  @override
  State<MerchantNewTaskScreen> createState() => _MerchantNewTaskScreenState();
}

class _MerchantNewTaskScreenState extends State<MerchantNewTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _consigneeController = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _codController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  String _deliveryType = 'standard';
  bool _remoteArea = false;
  DateTime? _deliveryDate;
  TimeOfDay? _windowStart;
  TimeOfDay? _windowEnd;
  bool _submitting = false;
  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final merchantId = supabase.auth.currentUser!.id;
    final data = await supabase.from('customers').select().eq('merchant_id', merchantId);
    setState(() => _customers = List<Map<String, dynamic>>.from(data));
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final merchantId = supabase.auth.currentUser!.id;
      await supabase.from('orders').insert({
        'merchant_id': merchantId,
        'consignee_name': _consigneeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'full_address': _addressController.text.trim(),
        'district': _districtController.text.trim(),
        'city': _cityController.text.trim(),
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'cod_amount': double.tryParse(_codController.text) ?? 0,
        'notes': _notesController.text.trim(),
        'delivery_date': _deliveryDate != null ? _fmtDate(_deliveryDate!) : null,
        'delivery_window_start': _windowStart != null ? _fmtTime(_windowStart!) : null,
        'delivery_window_end': _windowEnd != null ? _fmtTime(_windowEnd!) : null,
        'delivery_type': _deliveryType,
        'remote_area': _remoteArea,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable.empty();
                  return _customers.where((c) =>
                      (c['name'] as String).toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (c) => c['name'] as String,
                onSelected: (c) {
                  _consigneeController.text = c['name'] ?? '';
                  _phoneController.text = c['phone'] ?? '';
                  _addressController.text = c['full_address'] ?? '';
                  _cityController.text = c['city'] ?? '';
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  // Keep our own controller in sync so form submission still works
                  controller.addListener(() => _consigneeController.text = controller.text);
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Consignee Name', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Full Address', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: 'District (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _codController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'COD Amount', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: AppColors.border)),
                title: Text(_deliveryDate == null ? 'Delivery Date' : _fmtDate(_deliveryDate!)),
                trailing: const Icon(Icons.calendar_today, size: 18),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: AppColors.border)),
                      title: Text(_windowStart == null ? 'After' : _windowStart!.format(context)),
                      trailing: const Icon(Icons.access_time, size: 18),
                      onTap: () async {
                        final picked = await showCompactTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) setState(() => _windowStart = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: AppColors.border)),
                      title: Text(_windowEnd == null ? 'Before' : _windowEnd!.format(context)),
                      trailing: const Icon(Icons.access_time, size: 18),
                      onTap: () async {
                        final picked = await showCompactTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) setState(() => _windowEnd = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _deliveryType,
                      decoration: const InputDecoration(labelText: 'Delivery Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'standard', child: Text('Standard')),
                        DropdownMenuItem(value: 'express', child: Text('Express')),
                        DropdownMenuItem(value: 'same_day', child: Text('Same Day')),
                        DropdownMenuItem(value: 'on_demand', child: Text('On Demand')),
                      ],
                      onChanged: (v) => setState(() => _deliveryType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remote Area', style: TextStyle(fontSize: 13)),
                      value: _remoteArea,
                      onChanged: (v) => setState(() => _remoteArea = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}