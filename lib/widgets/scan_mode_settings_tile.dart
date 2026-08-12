import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/scan_mode_service.dart';

class ScanModeSettingsTile extends StatelessWidget {
  const ScanModeSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ScanModeService.laserMode,
      builder: (context, isLaser, _) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.settings_input_antenna, color: AppColors.textSecondary),
              title: const Text('Scan Input Method'),
              subtitle: Text(isLaser ? 'Handheld Scanner' : 'Camera'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Camera'), icon: Icon(Icons.camera_alt_outlined)),
                  ButtonSegment(value: true, label: Text('Handheld'), icon: Icon(Icons.qr_code_scanner)),
                ],
                selected: {isLaser},
                onSelectionChanged: (selected) => ScanModeService.setLaserMode(selected.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected) ? AppColors.purpleLight : null),
                ),
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }
}