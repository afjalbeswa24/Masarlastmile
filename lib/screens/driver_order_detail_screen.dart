import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';
import 'driver_proof_screen.dart';
import '../utils/qatar_time.dart';

class DriverOrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const DriverOrderDetailScreen({super.key, required this.order});

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : '—', style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // Phone numbers are normally stored with the country code already, digits
  // only (e.g. "97433091153") — but nothing elsewhere in the app enforces
  // that format on entry, so this cleans up before building tel:/wa.me links:
  // strips anything non-numeric, then if what's left is exactly 8 digits
  // (a bare Qatar local number with no country code), prepends 974.
  String _normalizedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) return '974$digits';
    return digits;
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:+${_normalizedPhone(phone)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone app')),
        );
      }
    }
  }

  Future<void> _whatsapp(BuildContext context, String phone) async {
    final uri = Uri.parse('https://wa.me/${_normalizedPhone(phone)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _podPhoto(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        height: 180,
        width: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stack) => Container(
          height: 180,
          color: AppColors.background,
          alignment: Alignment.center,
          child: const Text('Photo unavailable', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'pending';
    final canAct = status == 'out_for_delivery';
    final phone = (order['phone'] as String?)?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;

    final photo1 = order['proof_photo_url'] as String?;
    final photo2 = order['proof_photo_url_2'] as String?;
    final hasPod = status == 'delivered' && ((photo1?.isNotEmpty ?? false) || (photo2?.isNotEmpty ?? false));

    return Scaffold(
      appBar: AppBar(
        title: Text('Task #${order['order_number'] ?? ''}'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(order['consignee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                                StatusPill(status: status),
                              ],
                            ),
                            if (hasPhone) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _contactButton(
                                    icon: Icons.call,
                                    label: 'Call',
                                    color: AppColors.statusDelivered,
                                    onTap: () => _call(context, phone),
                                  ),
                                  const SizedBox(width: 10),
                                  _contactButton(
                                    icon: Icons.chat,
                                    label: 'WhatsApp',
                                    color: const Color(0xFF25D366),
                                    onTap: () => _whatsapp(context, phone),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 24),
                            _row('Phone', order['phone']),
                            _row('Address', order['full_address']),
                            _row('City', order['city']),
                            _row('AWB', order['order_code']),
                            _row('Quantity', '${order['quantity'] ?? ''}'),
                            _row('COD Amount', '${order['cod_amount'] ?? ''}'),
                            _row('Delivery Window', order['delivery_window_start'] != null ? '${QatarTime.trimSeconds(order['delivery_window_start'])} - ${QatarTime.trimSeconds(order['delivery_window_end'])}' : null),
                            _row('Notes', order['notes']),
                          ],
                        ),
                      ),
                    ),
                    if (hasPod) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Proof of Delivery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text(
                                'Check this against the address above if you think this order may have gone to the wrong place.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              if (photo1?.isNotEmpty ?? false) _podPhoto(photo1!),
                              if ((photo1?.isNotEmpty ?? false) && (photo2?.isNotEmpty ?? false)) const SizedBox(height: 10),
                              if (photo2?.isNotEmpty ?? false) _podPhoto(photo2!),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (canAct)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusDelivered, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DriverProofScreen(order: order, isComplete: true))),
                        child: const Text('COMPLETE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusFailed, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DriverProofScreen(order: order, isComplete: false))),
                        child: const Text('FAIL'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}