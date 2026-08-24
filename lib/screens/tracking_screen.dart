import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.purple,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.purple,
            tabs: const [
              Tab(text: 'Mobile GPS'),
              Tab(text: 'Mobitrack'),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _MobileGpsTab(),
              _MobitrackTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The original phone-GPS-based tracking view (driver_locations table),
/// unchanged — just extracted into its own widget so it can sit in a tab
/// alongside the new Mobitrack hardware-tracker view.
class _MobileGpsTab extends StatefulWidget {
  const _MobileGpsTab();

  @override
  State<_MobileGpsTab> createState() => _MobileGpsTabState();
}

class _MobileGpsTabState extends State<_MobileGpsTab> {
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  Timer? _refreshTimer;
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await supabase
        .from('driver_locations')
        .select('driver_id, lat, lng, updated_at, driver:profiles!driver_locations_driver_id_fkey(full_name)');

    setState(() {
      _locations = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  String _minutesAgo(String iso) {
    final updated = DateTime.parse(iso);
    final diff = DateTime.now().toUtc().difference(updated.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  bool _isStale(String iso) {
    final updated = DateTime.parse(iso);
    return DateTime.now().toUtc().difference(updated.toUtc()).inMinutes > 5;
  }

  List<Map<String, dynamic>> get _filteredLocations {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _locations;
    return _locations.where((loc) {
      final name = (loc['driver']?['full_name'] ?? '').toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  void _focusOnDriver(Map<String, dynamic> loc) {
    _mapController.move(LatLng(loc['lat'], loc['lng']), 15);
    _showDriverInfo(loc);
  }

  @override
  Widget build(BuildContext context) {
    const defaultCenter = LatLng(25.2854, 51.5310); // Doha, Qatar
    final filtered = _filteredLocations;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _locations.isNotEmpty
                      ? LatLng(_locations.first['lat'], _locations.first['lng'])
                      : defaultCenter,
                  initialZoom: 11,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.masar.delivery',
                  ),
                  MarkerLayer(
                    markers: filtered.map((loc) {
                      final stale = _isStale(loc['updated_at']);
                      return Marker(
                        point: LatLng(loc['lat'], loc['lng']),
                        width: 140,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _showDriverInfo(loc),
                          child: Column(
                            children: [
                              Icon(Icons.local_shipping, color: stale ? Colors.grey : AppColors.purple, size: 30),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)]),
                                child: Text(
                                  loc['driver']?['full_name'] ?? 'Driver',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              if (filtered.isEmpty)
                Container(
                  color: Colors.white70,
                  child: Center(
                    child: Text(
                      _locations.isEmpty ? 'No drivers online right now' : 'No driver matches your search',
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              Positioned(
                top: 12, left: 12, right: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search driver...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            isDense: true,
                          ),
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _load,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.refresh, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]),
                      child: Text('${filtered.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              if (_searchController.text.trim().isNotEmpty && filtered.isNotEmpty)
                Positioned(
                  top: 66, left: 12, right: 12,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]),
                    child: ListView(
                      shrinkWrap: true,
                      children: filtered.map((loc) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.local_shipping, size: 18, color: AppColors.purple),
                          title: Text(loc['driver']?['full_name'] ?? 'Driver'),
                          subtitle: Text(_minutesAgo(loc['updated_at']), style: const TextStyle(fontSize: 11)),
                          onTap: () => _focusOnDriver(loc),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          );
  }

  void _showDriverInfo(Map<String, dynamic> loc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc['driver']?['full_name'] ?? 'Driver'),
        content: Text('Last updated: ${_minutesAgo(loc['updated_at'])}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

/// Fleet GPS hardware tracker view, reading from vehicle_positions —
/// populated by a sync job once Mobitrack API access is set up. Until
/// then this shows a clear "not connected yet" state rather than an
/// empty, confusing map.
class _MobitrackTab extends StatefulWidget {
  const _MobitrackTab();

  @override
  State<_MobitrackTab> createState() => _MobitrackTabState();
}

class _MobitrackTabState extends State<_MobitrackTab> {
  List<Map<String, dynamic>> _positions = [];
  bool _loading = true;
  Timer? _refreshTimer;
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await supabase
        .from('vehicle_positions')
        .select('id, vehicle_id, vehicle_name, lat, lng, speed_kmh, updated_at, driver:profiles!vehicle_positions_driver_id_fkey(full_name)');

    setState(() {
      _positions = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  String _minutesAgo(String iso) {
    final updated = DateTime.parse(iso);
    final diff = DateTime.now().toUtc().difference(updated.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  bool _isStale(String iso) {
    final updated = DateTime.parse(iso);
    return DateTime.now().toUtc().difference(updated.toUtc()).inMinutes > 5;
  }

  String _label(Map<String, dynamic> pos) => pos['vehicle_name'] ?? pos['driver']?['full_name'] ?? pos['vehicle_id'] ?? 'Vehicle';

  List<Map<String, dynamic>> get _filteredPositions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _positions;
    return _positions.where((pos) => _label(pos).toString().toLowerCase().contains(query)).toList();
  }

  // ignore: unused_element
  void _focusOnVehicle(Map<String, dynamic> pos) {
    _mapController.move(LatLng(pos['lat'], pos['lng']), 15);
    _showVehicleInfo(pos);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    const defaultCenter = LatLng(25.2854, 51.5310); // Doha, Qatar
    final filtered = _filteredPositions;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_positions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.satellite_alt_outlined, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text('Mobitrack not connected yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              const Text(
                'Once the Mobitrack fleet GPS integration is set up, live vehicle positions will appear here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_positions.first['lat'], _positions.first['lng']),
            initialZoom: 11,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.masar.delivery',
            ),
            MarkerLayer(
              markers: filtered.map((pos) {
                final stale = _isStale(pos['updated_at']);
                return Marker(
                  point: LatLng(pos['lat'], pos['lng']),
                  width: 140,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _showVehicleInfo(pos),
                    child: Column(
                      children: [
                        Icon(Icons.satellite_alt, color: stale ? Colors.grey : AppColors.purple, size: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)]),
                          child: Text(_label(pos), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          top: 12, left: 12, right: 12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search vehicle...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _load,
                  child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.refresh, size: 20)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]),
                child: Text('${filtered.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showVehicleInfo(Map<String, dynamic> pos) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_label(pos)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last updated: ${_minutesAgo(pos['updated_at'])}'),
            if (pos['speed_kmh'] != null) Text('Speed: ${pos['speed_kmh']} km/h'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}