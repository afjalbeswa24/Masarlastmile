import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/qatar_time.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/photo_stamp_service.dart';

class DriverProofScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isComplete;
  const DriverProofScreen({super.key, required this.order, required this.isComplete});

  @override
  State<DriverProofScreen> createState() => _DriverProofScreenState();
}

class _DriverProofScreenState extends State<DriverProofScreen> {
  String? _photoPath;
  String? _photoPath2;
  bool _submitting = false;

  String? _failureReason;
  final _commentController = TextEditingController();
  final _failureReasons = [
    'No Access to customer',
    'Incorrect Address',
    'Customer Wants Different Date/Time',
    'Customer Refused Delivery',
    'Customer Not Responding',
    'Customer Need Tomorrow',
  ];

  bool _showCodStep = false;
  final _collectedAmountController = TextEditingController();

  double get _codAmount => (widget.order['cod_amount'] ?? 0).toDouble();

  Future<void> _takePhoto({bool isSecond = false}) async {
    final picker = ImagePicker();
    // maxWidth/maxHeight matter more for upload speed than imageQuality
    // alone — modern phone cameras shoot 4000px+ wide by default, and even
    // at 70% JPEG quality that's still several MB. 1280px is plenty for a
    // proof photo that's only ever glanced at on a phone or dashboard.
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
    if (photo != null) {
      await PhotoStampService.stampPhotoInPlace(photo.path);
      setState(() {
        if (isSecond) {
          _photoPath2 = photo.path;
        } else {
          _photoPath = photo.path;
        }
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
    if (photo != null) setState(() => _photoPath = photo.path);
  }

  Future<void> _pickFailureReason() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Choose Delivery Note', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ..._failureReasons.map((reason) => Column(
                    children: [
                      ListTile(
                        title: Text(reason, textAlign: TextAlign.center),
                        onTap: () => Navigator.pop(context, reason),
                      ),
                      const Divider(height: 1),
                    ],
                  )),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) setState(() => _failureReason = selected);
  }

  Future<void> _proceedToConfirmOrCod() async {
    if (widget.isComplete && _codAmount > 0 && !_showCodStep) {
      if (_photoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please take at least one proof-of-delivery photo')),
        );
        return;
      }
      _collectedAmountController.text = _codAmount.toStringAsFixed(2);
      setState(() => _showCodStep = true);
      return;
    }
    await _submit();
  }

  Future<String> _uploadPhoto(String path, String suffix) async {
    final bytes = await File(path).readAsBytes();
    final fileName = '${widget.order['order_code']}_${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('proof-of-delivery').uploadBinary(fileName, bytes);
    return supabase.storage.from('proof-of-delivery').getPublicUrl(fileName);
  }

  Future<void> _submit() async {
    if (widget.isComplete && _photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take at least one proof-of-delivery photo')),
      );
      return;
    }
    if (!widget.isComplete && _failureReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a failure reason')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      String? photoUrl;
      String? photoUrl2;
      if (_photoPath != null) photoUrl = await _uploadPhoto(_photoPath!, '1');
      if (_photoPath2 != null) photoUrl2 = await _uploadPhoto(_photoPath2!, '2');

      final updates = <String, dynamic>{
        'status': widget.isComplete ? 'delivered' : 'failed',
      };
      if (photoUrl != null) updates['proof_photo_url'] = photoUrl;
      if (photoUrl2 != null) updates['proof_photo_url_2'] = photoUrl2;

      if (widget.isComplete) {
        updates['delivered_at'] = QatarTime.nowUtcIso();
        if (_codAmount > 0) {
          updates['collected_amount'] = double.tryParse(_collectedAmountController.text) ?? _codAmount;
        }
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          updates['delivered_lat'] = position.latitude;
          updates['delivered_lng'] = position.longitude;
        } catch (_) {
          // If GPS momentarily fails, still let the delivery complete —
          // location is a bonus record, not a hard requirement here.
        }
      } else {
        updates['failure_reason'] = _failureReason;
        updates['driver_comment'] = _commentController.text.trim();
      }

      await supabase.from('orders').update(updates).eq('id', widget.order['id']);

      if (mounted) {
        Navigator.pop(context);
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

  Widget _photoBox({required String? path, required VoidCallback onTap, required String label}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: path != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(path), fit: BoxFit.cover, width: double.infinity),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 32, color: AppColors.textSecondary),
                    const SizedBox(height: 6),
                    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCodStep() {
    return Column(
      children: [
        const Icon(Icons.payments, size: 48, color: AppColors.statusAssigned),
        const SizedBox(height: 12),
        const Text('Confirm Collected Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Expected COD: ${_codAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        TextField(
          controller: _collectedAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: 'Amount Collected',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Edit this if you collected a different amount than expected.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reasons', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickFailureReason,
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _failureReason ?? 'Choose Failure reason',
                    style: TextStyle(color: _failureReason == null ? Colors.grey.shade600 : Colors.black),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Driver Comment', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _commentController,
          decoration: InputDecoration(
            hintText: 'Add a comment...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: const Icon(Icons.chat_bubble_outline),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Proof Of Delivery | Collection', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        _photoPath != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_photoPath!), height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: IconButton(
                      icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white, size: 18)),
                      onPressed: () => setState(() => _photoPath = null),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      onPressed: () => _takePhoto(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('From Storage'),
                      onPressed: _pickFromGallery,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCod = widget.isComplete && _showCodStep;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isComplete ? (showCod ? 'Confirm Amount' : 'Task') : 'Task'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: showCod
                    ? _buildCodStep()
                    : widget.isComplete
                        ? Column(
                            children: [
                              const Text('Take up to 2 photos showing the package was delivered.',
                                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              _photoBox(path: _photoPath, onTap: () => _takePhoto(), label: 'Photo 1 (required)'),
                              const SizedBox(height: 12),
                              _photoBox(path: _photoPath2, onTap: () => _takePhoto(isSecond: true), label: 'Photo 2 (optional)'),
                            ],
                          )
                        : _buildFailForm(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.isComplete ? AppColors.statusDelivered : AppColors.statusFailed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _submitting ? null : (showCod ? _submit : _proceedToConfirmOrCod),
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(showCod ? 'CONFIRM' : (widget.isComplete ? 'Confirm Delivered' : 'CONFIRM')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}