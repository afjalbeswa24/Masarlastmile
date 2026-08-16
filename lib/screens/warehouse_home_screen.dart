import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_mode_settings_tile.dart';
import 'warehouse_home_tab.dart';
import 'warehouse_sort_tab.dart';
import 'warehouse_package_info_tab.dart';

class WarehouseHomeScreen extends StatefulWidget {
  const WarehouseHomeScreen({super.key});

  @override
  State<WarehouseHomeScreen> createState() => _WarehouseHomeScreenState();
}

class _WarehouseHomeScreenState extends State<WarehouseHomeScreen> {
  int _tabIndex = 0;
  // Package Info and Sorting both need the camera. Previously each tab
  // created its own MobileScannerController, and switching between them
  // raced to grab the camera hardware before the other tab had released
  // it — sharing one controller here removes that conflict entirely.
  final MobileScannerController _scannerController = MobileScannerController(autoStart: false);

  final _titles = ['Home', 'Package Info', 'Sorting', 'More'];

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _setTab(int i) async {
    final needsCamera = i == 1 || i == 2;
    final hadCamera = _tabIndex == 1 || _tabIndex == 2;
    setState(() => _tabIndex = i);
    if (needsCamera && !hadCamera) {
      try {
        await _scannerController.start();
      } catch (_) {
        // Already running — ignore
      }
    } else if (!needsCamera && hadCamera) {
      try {
        await _scannerController.stop();
      } catch (_) {
        // Already stopped — ignore
      }
    }
  }

  Widget _buildTab() {
    switch (_tabIndex) {
      case 0:
        return const WarehouseHomeTab();
      case 1:
        return WarehousePackageInfoTab(controller: _scannerController);
      case 2:
        return WarehouseSortTab(controller: _scannerController);
      default:
        return _MoreTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex].toUpperCase(), style: const TextStyle(letterSpacing: 1)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _buildTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _setTab,
        indicatorColor: AppColors.purpleLight,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.purple), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info, color: AppColors.purple), label: 'Info'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner, color: AppColors.purple), label: 'Sorting'),
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
            subtitle: const Text('Warehouse Staff'),
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