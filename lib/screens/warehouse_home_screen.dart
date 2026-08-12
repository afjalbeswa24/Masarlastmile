import 'package:flutter/material.dart';
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

  final _titles = ['Home', 'Package Info', 'Sorting', 'More'];

  Widget _buildTab() {
    switch (_tabIndex) {
      case 0:
        return const WarehouseHomeTab();
      case 1:
        return const WarehousePackageInfoTab();
      case 2:
        return const WarehouseSortTab();
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
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
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