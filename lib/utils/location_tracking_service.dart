import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import 'qatar_time.dart';

class LocationTrackingService {
  static Timer? _timer;

  static Future<void> start() async {
    stop(); // avoid duplicate timers if called twice

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
        return; // can't track without permission
      }
    }

    // Send an update immediately, then every 20 seconds while the app is open/foreground
    _sendUpdate();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _sendUpdate());
  }

  static Future<void> _sendUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final driverId = supabase.auth.currentUser?.id;
      if (driverId == null) return;

      await supabase.from('driver_locations').upsert({
        'driver_id': driverId,
        'lat': position.latitude,
        'lng': position.longitude,
        'updated_at': QatarTime.nowUtcIso(),
      });
    } catch (_) {
      // Silently ignore a single failed update (e.g. brief GPS/network blip) — next tick retries.
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}