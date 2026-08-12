import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';
import '../widgets/scan_input.dart';
import '../utils/box_scan_service.dart';

class WarehousePackageInfoTab extends StatefulWidget {
  const WarehousePackageInfoTab({super.key});

  @override
  State<WarehousePackageInfoTab> createState() => _WarehousePackageInfoTabState();
}

class _WarehousePackageInfoTabState extends State<WarehousePackageInfoTab> {
  bool _loading = false;
  bool _scanning = true;
  Map<String, dynamic>? _box;
  Map<String, dynamic>? _order;
  String? _notFoundCode;
  final _searchController = TextEditingController();

  Future<void> _lookup(String code) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _box = null;
      _order = null;
      _notFoundCode = null;
    });

    try {
      final result = await BoxScanService.lookup(code);

      setState(() {
        _scanning = false;
        if (!result.found) {
          _notFoundCode = code;
        } else {
          _box = result.box;
          _order = result.order;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scanAnother() {
    setState(() {
      _box = null;
      _order = null;
      _notFoundCode = null;
      _scanning = true;
      _searchController.clear();
    });
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String? _fmtTime(String? iso) {
    if (iso == null) return null;
    return DateTime.parse(iso).toLocal().toString().split('.')[0];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              enabled: _scanning,
              decoration: InputDecoration(
                hintText: 'Enter or scan AWB / box code',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (_searchController.text.trim().isNotEmpty) _lookup(_searchController.text.trim());
                  },
                ),
              ),
              onSubmitted: (v) => _lookup(v.trim()),
            ),
          ),
          if (_scanning)
            ScanInput(
              height: 220,
              onScan: (code) {
                _searchController.text = code;
                _lookup(code);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Another'),
                  onPressed: _scanAnother,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : _notFoundCode != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No package found for "$_notFoundCode"',
                                style: const TextStyle(color: AppColors.textSecondary)),
                          ),
                        )
                      : (_box == null || _order == null)
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('Scan or search a box code to see package details',
                                    style: TextStyle(color: AppColors.textSecondary)),
                              ),
                            )
                          : Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(_box!['box_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        const Spacer(),
                                        StatusPill(status: _order!['status'] ?? 'pending'),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    _infoRow('Order AWB', _order!['order_code']),
                                    _infoRow('Box Number', '${_box!['box_number'] ?? ''}'),
                                    _infoRow('Consignee', _order!['consignee_name']),
                                    _infoRow('Address', _order!['full_address']),
                                    _infoRow('Delivery Date', _order!['delivery_date']),
                                    _infoRow('Driver', _order!['driver']?['full_name']),
                                    const Divider(height: 24),
                                    const Text('This Box\'s Timeline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    _infoRow('Picked Up', _fmtTime(_box!['picked_up_at'])),
                                    _infoRow('Sorted', _fmtTime(_box!['sorted_at'])),
                                    _infoRow('Out for Delivery', _fmtTime(_box!['out_for_delivery_at'])),
                                  ],
                                ),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}