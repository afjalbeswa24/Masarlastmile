import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanModeService {
  // false = camera, true = handheld laser scanner
  static final ValueNotifier<bool> laserMode = ValueNotifier<bool>(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    laserMode.value = prefs.getBool('laser_scan_mode') ?? false;
  }

  static Future<void> setLaserMode(bool value) async {
    laserMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('laser_scan_mode', value);
  }
}