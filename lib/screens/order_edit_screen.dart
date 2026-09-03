import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_time_picker.dart';

class OrderEditScreen extends StatefulWidget {
  final String orderId;
  const OrderEditScreen({super.key, required this.orderId});

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _myRole;

  late TextEditingController _consigneeController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _districtController;
  late TextEditingController _cityController;
  late TextEditingController _quantityController;
  late TextEditingController _codController;
  late TextEditingController _notesController;
  String _status = 'pending';
  String _deliveryType = 'standard';
  bool _remoteArea = false;
  DateTime? _deliveryDate;
  TimeOfDay? _windowStart;
  TimeOfDay? _windowEnd;
  String? _photoUrl1;
  String? _photoUrl2;
  double? _deliveredLat;
  double? _deliveredLng;

  final _statuses = [
    'pending', 'picked_up', 'sorted', 'assigned',
    'out_for_delivery', 'delivered', 'failed', 'cancelled', 'rescheduled', 'returned_to_shipper'
  ];

  bool get _isMerchant => _myRole == 'merchant';

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  @override
  void initState() {
    super.initState();
    _loadMyRole();
    _loadOrder();
  }

  Future<void> _loadMyRole() async {
    final data = await supabase
        .from('profiles')
        .select('role')
        .eq('id', supabase.auth.currentUser!.id)
        .single();
    setState(() => _myRole = data['role'] as String);
  }

  Future<void> _loadOrder() async {
    final data = await supabase
        .from('orders')
        .select()
        .eq('id', widget.orderId)
        .single();

    _order = data;
    _consigneeController = TextEditingController(text: data['consignee_name'] ?? '');
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _addressController = TextEditingController(text: data['full_address'] ?? '');
    _districtController = TextEditingController(text: data['district'] ?? '');
    _cityController = TextEditingController(text: data['city'] ?? '');
    _quantityController = TextEditingController(text: '${data['quantity'] ?? 1}');
    _codController = TextEditingController(text: '${data['cod_amount'] ?? 0}');
    _notesController = TextEditingController(text: data['notes'] ?? '');
    _status = data['status'] ?? 'pending';
    _deliveryType = data['delivery_type'] ?? 'standard';
    _remoteArea = data['remote_area'] == true;
    _windowStart = _parseTime(data['delivery_window_start']);
    _windowEnd = _parseTime(data['delivery_window_end']);
    _photoUrl1 = data['proof_photo_url'];
    _photoUrl2 = data['proof_photo_url_2'];
    _deliveredLat = data['delivered_lat'];
    _deliveredLng = data['delivered_lng'];
    if (data['delivery_date'] != null) {
      _deliveryDate = DateTime.tryParse(data['delivery_date']);
    }

    setState(() => _loading = false);
  }

  Future<void> _uploadPhoto({required bool isSecond}) async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = result.files.single.bytes!;
      final fileName = '${_order?['order_code']}_${isSecond ? '2' : '1'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('proof-of-delivery').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('proof-of-delivery').getPublicUrl(fileName);

      await supabase.from('orders').update({
        isSecond ? 'proof_photo_url_2' : 'proof_photo_url': url,
      }).eq('id', widget.orderId);

      setState(() {
        if (isSecond) {
          _photoUrl2 = url;
        } else {
          _photoUrl1 = url;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
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
      };

      if (!_isMerchant) {
        updates['status'] = _status;
      }

      await supabase.from('orders').update(updates).eq('id', widget.orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoSlot(String label, String? url, {required bool isSecond}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _uploadingPhoto ? null : () => _uploadPhoto(isSecond: isSecond),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: url != null && url.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
                    )
                  : const Center(child: Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasDeliveredLocation = _deliveredLat != null && _deliveredLng != null;

    return Scaffold(
      appBar: AppBar(title: Text(_order?['order_code'] ?? 'Edit Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isMerchant)
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: _statuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
            if (!_isMerchant) const SizedBox(height: 16),
            if (!_isMerchant) ...[
              const Text('Proof of Delivery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _photoSlot('Photo 1', _photoUrl1, isSecond: false),
                  const SizedBox(width: 12),
                  _photoSlot('Photo 2', _photoUrl2, isSecond: true),
                ],
              ),
              if (_uploadingPhoto)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              const SizedBox(height: 10),
              if (hasDeliveredLocation)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    label: const Text('View Delivery Location'),
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.google.com/maps/search/?api=1&query=$_deliveredLat,$_deliveredLng'),
                      webOnlyWindowName: '_blank',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _consigneeController,
              decoration: const InputDecoration(
                  labelText: 'Consignee Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                  labelText: 'Phone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Full Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _districtController,
              decoration: const InputDecoration(
                  labelText: 'District (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                  labelText: 'City', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Quantity', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _codController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'COD Amount', border: OutlineInputBorder()),
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
                  initialDate: _deliveryDate ?? DateTime.now(),
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
                      final picked = await showCompactTimePicker(context: context, initialTime: _windowStart ?? TimeOfDay.now());
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
                      final picked = await showCompactTimePicker(context: context, initialTime: _windowEnd ?? TimeOfDay.now());
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
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Notes', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}