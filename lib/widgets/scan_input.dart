import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../utils/scan_mode_service.dart';

class ScanInput extends StatefulWidget {
  final double height;
  final ValueChanged<String> onScan;
  final MobileScannerController? controller;

  const ScanInput({
    super.key,
    required this.onScan,
    this.height = 280,
    this.controller,
  });

  @override
  State<ScanInput> createState() => _ScanInputState();
}

class _ScanInputState extends State<ScanInput> {
  final _laserController = TextEditingController();
  final _laserFocusNode = FocusNode();

  void _submitLaser(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      widget.onScan(trimmed);
    }
    _laserController.clear();
    _laserFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _laserController.dispose();
    _laserFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ScanModeService.laserMode,
      builder: (context, isLaser, _) {
        if (isLaser) {
          // Keep focus so the handheld scanner's keystrokes always land here
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _laserFocusNode.requestFocus();
          });

          return Container(
            height: widget.height,
            color: AppColors.navy,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, size: 48, color: Colors.white70),
                const SizedBox(height: 12),
                const Text('Handheld scanner mode', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Point the scanner and pull the trigger', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 16),
                TextField(
                  controller: _laserController,
                  focusNode: _laserFocusNode,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white24,
                    hintText: 'Waiting for scan...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onSubmitted: _submitLaser,
                  textInputAction: TextInputAction.done,
                  // Handle scanners configured to send Tab instead of Enter
                  keyboardType: TextInputType.text,
                ),
              ],
            ),
          );
        }

        return ClipRRect(
          child: SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: widget.controller,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      widget.onScan(barcodes.first.rawValue!);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: widget.height * 0.7,
                    height: widget.height * 0.7,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}