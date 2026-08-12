import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/location_tracking_service.dart';
import 'driver_home_tab.dart';
import 'driver_collect_tab.dart';
import '../widgets/scan_mode_settings_tile.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;
  final _titles = ['Home', 'Collect', 'More'];

  bool _checking = true;
  bool _serviceEnabled = false;
  bool _permissionGranted = false;

  bool get _locationReady => _serviceEnabled && _permissionGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationTrackingService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check whenever the driver comes back to the app — catches the case
    // where they disabled GPS or revoked permission while away from it.
    if (state == AppLifecycleState.resumed) {
      _checkLocation();
    }
  }

  Future<void> _checkLocation() async {
    setState(() => _checking = true);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _serviceEnabled = false;
        _permissionGranted = false;
        _checking = false;
      });
      LocationTrackingService.stop();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;

    setState(() {
      _serviceEnabled = true;
      _permissionGranted = granted;
      _checking = false;
    });

    if (granted) {
      await LocationTrackingService.start();
    } else {
      LocationTrackingService.stop();
    }
  }

  Widget _buildBlockedScreen() {
    final needsService = !_serviceEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Required'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => supabase.auth.signOut()),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: AppColors.statusFailed),
              const SizedBox(height: 20),
              Text(
                needsService ? 'Location Services are turned off' : 'Location permission is required',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                needsService
                    ? 'MASAR needs your phone\'s GPS turned on so dispatch can track deliveries. Please enable Location in your phone settings, then come back and tap Retry.'
                    : 'MASAR needs location permission to track deliveries. Please allow it, then tap Retry.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(needsService ? Icons.settings : Icons.lock_open),
                  label: Text(needsService ? 'Open Location Settings' : 'Grant Permission / Open App Settings'),
                  onPressed: () async {
                    if (needsService) {
                      await Geolocator.openLocationSettings();
                    } else {
                      await openAppSettings();
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: _checkLocation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_locationReady) {
      return _buildBlockedScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex].toUpperCase(), style: const TextStyle(letterSpacing: 1)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          const DriverHomeTab(),
          const DriverCollectTab(),
          _MoreTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        indicatorColor: AppColors.purpleLight,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.purple), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner, color: AppColors.purple), label: 'Collect'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz, color: AppColors.purple), label: 'More'),
        ],
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.purple, child: Icon(Icons.person, color: Colors.white)),
            title: Text(supabase.auth.currentUser?.email ?? ''),
            subtitle: const Text('Driver'),
          ),
          const Divider(),
          const ScanModeSettingsTile(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => supabase.auth.signOut(),
          ),
        ],
      ),
    );
  }
}