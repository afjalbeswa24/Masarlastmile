import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/qatar_time.dart';
import '../widgets/date_range_button.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _dateRange;
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    final today = QatarTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    _dateRange = DateTimeRange(start: todayOnly, end: todayOnly);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Future<void> _exportSheet(String name, List<String> headers, List<List<String>> rows) async {
    final workbook = xl.Excel.createExcel();
    final sheet = workbook[name];
    workbook.delete('Sheet1');

    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((v) => xl.TextCellValue(v)).toList());
    }

    final bytes = workbook.encode();
    if (bytes == null) return;

    await FileSaver.instance.saveFile(
      name: '${name}_${_fmtDate(_dateRange!.start)}_to_${_fmtDate(_dateRange!.end)}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
  Future<void> _exportCurrentTab() async {
    switch (_tabController.index) {
      case 0:
        await _exportDailySummary();
        break;
      case 1:
        await _exportDriverPerformance();
        break;
      case 2:
        await _exportCodReconciliation();
        break;
      case 3:
        await _exportMerchantVolume();
        break;
    }
  }

  Future<void> _exportDailySummary() async {
    final total = _orders.length;
    final delivered = _orders.where((o) => o['status'] == 'delivered').length;
    final failed = _orders.where((o) => o['status'] == 'failed').length;
    final pending = _orders.where((o) => !['delivered', 'failed', 'cancelled'].contains(o['status'])).length;
    final cancelled = _orders.where((o) => o['status'] == 'cancelled').length;

    int onTime = 0, early = 0, late = 0;
    for (final o in _orders) {
      final p = _punctuality(o);
      if (p == 'On Time') onTime++;
      if (p == 'Early') early++;
      if (p == 'Late') late++;
    }

    double codCollected = 0;
    for (final o in _orders) {
      if (o['status'] == 'delivered') codCollected += (o['collected_amount'] ?? o['cod_amount'] ?? 0).toDouble();
    }

    await _exportSheet('Daily_Summary', ['Metric', 'Value'], [
      ['Total Orders', '$total'],
      ['Delivered', '$delivered'],
      ['Failed', '$failed'],
      ['Pending', '$pending'],
      ['Cancelled', '$cancelled'],
      ['On Time', '$onTime'],
      ['Early', '$early'],
      ['Late', '$late'],
      ['COD Collected', codCollected.toStringAsFixed(2)],
    ]);
  }

  Future<void> _exportDriverPerformance() async {
    final Map<String, Map<String, dynamic>> byDriver = {};
    for (final o in _orders) {
      final driverId = o['assigned_driver_id'] as String?;
      if (driverId == null) continue;
      final name = o['driver']?['full_name'] ?? 'Unnamed';
      byDriver.putIfAbsent(driverId, () => {'name': name, 'delivered': 0, 'failed': 0, 'onTime': 0, 'early': 0, 'late': 0});
      final entry = byDriver[driverId]!;
      if (o['status'] == 'delivered') entry['delivered']++;
      if (o['status'] == 'failed') entry['failed']++;
      final p = _punctuality(o);
      if (p == 'On Time') entry['onTime']++;
      if (p == 'Early') entry['early']++;
      if (p == 'Late') entry['late']++;
    }

    final rows = byDriver.values.map((r) {
      final total = (r['onTime'] as int) + (r['early'] as int) + (r['late'] as int);
      final pct = total == 0 ? '—' : '${((r['onTime'] as int) / total * 100).toStringAsFixed(0)}%';
      return [r['name'].toString(), '${r['delivered']}', '${r['failed']}', '${r['onTime']}', '${r['early']}', '${r['late']}', pct];
    }).toList();

    await _exportSheet('Driver_Performance', ['Driver', 'Delivered', 'Failed', 'On Time', 'Early', 'Late', 'Punctuality %'], rows);
  }

  Future<void> _exportCodReconciliation() async {
    final Map<String, Map<String, dynamic>> byDriver = {};
    for (final o in _orders) {
      final cod = (o['cod_amount'] ?? 0).toDouble();
      if (cod <= 0) continue;
      final driverId = o['assigned_driver_id'] as String? ?? '__unassigned__';
      final name = driverId == '__unassigned__' ? 'Unassigned' : (o['driver']?['full_name'] ?? 'Unnamed');
      byDriver.putIfAbsent(driverId, () => {'name': name, 'expected': 0.0, 'collected': 0.0, 'outstanding': 0.0});
      final entry = byDriver[driverId]!;
      if (o['status'] == 'delivered') {
        final collected = (o['collected_amount'] ?? cod).toDouble();
        entry['expected'] += cod;
        entry['collected'] += collected;
      } else if (!['failed', 'cancelled'].contains(o['status'])) {
        entry['outstanding'] += cod;
      }
    }

    final rows = byDriver.values.map((r) {
      final diff = (r['collected'] as double) - (r['expected'] as double);
      return [
        r['name'].toString(),
        (r['expected'] as double).toStringAsFixed(2),
        (r['collected'] as double).toStringAsFixed(2),
        diff.toStringAsFixed(2),
        (r['outstanding'] as double).toStringAsFixed(2),
      ];
    }).toList();

    await _exportSheet('COD_Reconciliation', ['Driver', 'Expected', 'Collected', 'Difference', 'Outstanding'], rows);
  }

  Future<void> _exportMerchantVolume() async {
    final Map<String, Map<String, dynamic>> byMerchant = {};
    for (final o in _orders) {
      final merchantId = o['merchant_id'] as String?;
      if (merchantId == null) continue;
      final name = o['merchant']?['full_name'] ?? 'Unnamed';
      byMerchant.putIfAbsent(merchantId, () => {'name': name, 'total': 0, 'delivered': 0, 'failed': 0, 'cancelled': 0, 'cod': 0.0});
      final entry = byMerchant[merchantId]!;
      entry['total']++;
      if (o['status'] == 'delivered') entry['delivered']++;
      if (o['status'] == 'failed') entry['failed']++;
      if (o['status'] == 'cancelled') entry['cancelled']++;
      entry['cod'] += (o['cod_amount'] ?? 0).toDouble();
    }

    final rows = byMerchant.values.map((r) {
      return [r['name'].toString(), '${r['total']}', '${r['delivered']}', '${r['failed']}', '${r['cancelled']}', (r['cod'] as double).toStringAsFixed(2)];
    }).toList();

    await _exportSheet('Merchant_Volume', ['Merchant', 'Total Orders', 'Delivered', 'Failed', 'Cancelled', 'Total COD Value'], rows);
  }
  Future<void> _load() async {
    setState(() => _loading = true);

    var query = supabase.from('orders').select('''
      id, status, cod_amount, collected_amount, delivered_at, delivery_window_start, delivery_window_end,
      failure_reason, assigned_driver_id, merchant_id,
      driver:profiles!orders_assigned_driver_id_fkey(full_name),
      merchant:profiles!orders_merchant_id_fkey(full_name)
    ''');

    if (_dateRange != null) {
      query = query
          .gte('delivery_date', _fmtDate(_dateRange!.start))
          .lte('delivery_date', _fmtDate(_dateRange!.end));
    }

    final data = await query;

    setState(() {
      _orders = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  String _punctuality(Map<String, dynamic> o) {
    if (o['status'] != 'delivered' || o['delivered_at'] == null) return '';
    final start = o['delivery_window_start'] as String?;
    final end = o['delivery_window_end'] as String?;
    if (start == null || end == null) return '';
    final delivered = QatarTime.fromIso(o['delivered_at']);
    final hm = QatarTime.hm(delivered);
    if (hm.compareTo(start) < 0) return 'Early';
    if (hm.compareTo(end) > 0) return 'Late';
    return 'On Time';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.purple,
              labelColor: AppColors.purple,
              unselectedLabelColor: AppColors.textSecondary,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Daily Summary'),
                Tab(text: 'Driver Performance'),
                Tab(text: 'COD Reconciliation'),
                Tab(text: 'Merchant Volume'),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DateRangeButton(
                  range: _dateRange,
                  onChanged: (r) {
                    setState(() => _dateRange = r);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download This Report'),
                  onPressed: _exportCurrentTab,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _dailySummaryTab(),
                      _driverPerformanceTab(),
                      _codReconciliationTab(),
                      _merchantVolumeTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cardShell(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: Daily Operations Summary
  // ============================================================
  Widget _dailySummaryTab() {
    final total = _orders.length;
    final delivered = _orders.where((o) => o['status'] == 'delivered').length;
    final failed = _orders.where((o) => o['status'] == 'failed').length;
    final pending = _orders.where((o) => !['delivered', 'failed', 'cancelled'].contains(o['status'])).length;
    final cancelled = _orders.where((o) => o['status'] == 'cancelled').length;

    int onTime = 0, early = 0, late = 0;
    for (final o in _orders) {
      final p = _punctuality(o);
      if (p == 'On Time') onTime++;
      if (p == 'Early') early++;
      if (p == 'Late') late++;
    }
    final punctualTotal = onTime + early + late;

    double codCollected = 0;
    for (final o in _orders) {
      if (o['status'] == 'delivered') codCollected += (o['collected_amount'] ?? o['cod_amount'] ?? 0).toDouble();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardShell('Order Summary', Row(
            children: [
              Expanded(child: _statTile('Total', '$total')),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Delivered', '$delivered', color: AppColors.statusDelivered)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Failed', '$failed', color: AppColors.statusFailed)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Pending', '$pending', color: AppColors.statusAssigned)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Cancelled', '$cancelled', color: AppColors.textSecondary)),
            ],
          )),
          _cardShell('Punctuality', Row(
            children: [
              Expanded(child: _statTile('On Time', punctualTotal == 0 ? '0%' : '${(onTime / punctualTotal * 100).toStringAsFixed(0)}%', color: AppColors.statusDelivered)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Early', punctualTotal == 0 ? '0%' : '${(early / punctualTotal * 100).toStringAsFixed(0)}%', color: AppColors.statusPending)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Late', punctualTotal == 0 ? '0%' : '${(late / punctualTotal * 100).toStringAsFixed(0)}%', color: AppColors.statusFailed)),
            ],
          )),
          _cardShell('Cash', Row(
            children: [
              Expanded(child: _statTile('COD Collected', codCollected.toStringAsFixed(0), color: AppColors.statusDelivered)),
            ],
          )),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2: Driver Performance
  // ============================================================
  Widget _driverPerformanceTab() {
    final Map<String, Map<String, dynamic>> byDriver = {};

    for (final o in _orders) {
      final driverId = o['assigned_driver_id'] as String?;
      if (driverId == null) continue;
      final name = o['driver']?['full_name'] ?? 'Unnamed';

      byDriver.putIfAbsent(driverId, () => {
        'name': name, 'delivered': 0, 'failed': 0, 'onTime': 0, 'early': 0, 'late': 0,
      });

      final entry = byDriver[driverId]!;
      if (o['status'] == 'delivered') entry['delivered']++;
      if (o['status'] == 'failed') entry['failed']++;
      final p = _punctuality(o);
      if (p == 'On Time') entry['onTime']++;
      if (p == 'Early') entry['early']++;
      if (p == 'Late') entry['late']++;
    }

    final rows = byDriver.values.toList()
      ..sort((a, b) => (b['delivered'] as int).compareTo(a['delivered'] as int));

    if (rows.isEmpty) {
      return const Center(child: Text('No driver activity in this range', style: TextStyle(color: AppColors.textSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          columns: const [
            DataColumn(label: Text('Driver')),
            DataColumn(label: Text('Delivered')),
            DataColumn(label: Text('Failed')),
            DataColumn(label: Text('On Time')),
            DataColumn(label: Text('Early')),
            DataColumn(label: Text('Late')),
            DataColumn(label: Text('Punctuality %')),
          ],
          rows: rows.map((r) {
            final total = (r['onTime'] as int) + (r['early'] as int) + (r['late'] as int);
            final pct = total == 0 ? '—' : '${((r['onTime'] as int) / total * 100).toStringAsFixed(0)}%';
            return DataRow(cells: [
              DataCell(Text(r['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${r['delivered']}', style: const TextStyle(color: AppColors.statusDelivered))),
              DataCell(Text('${r['failed']}', style: const TextStyle(color: AppColors.statusFailed))),
              DataCell(Text('${r['onTime']}')),
              DataCell(Text('${r['early']}')),
              DataCell(Text('${r['late']}')),
              DataCell(Text(pct, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 3: COD Reconciliation
  // ============================================================
  Widget _codReconciliationTab() {
    final Map<String, Map<String, dynamic>> byDriver = {};

    for (final o in _orders) {
      final cod = (o['cod_amount'] ?? 0).toDouble();
      if (cod <= 0) continue;
      final driverId = o['assigned_driver_id'] as String? ?? '__unassigned__';
      final name = driverId == '__unassigned__' ? 'Unassigned' : (o['driver']?['full_name'] ?? 'Unnamed');

      byDriver.putIfAbsent(driverId, () => {
        'name': name, 'expected': 0.0, 'collected': 0.0, 'outstanding': 0.0,
      });

      final entry = byDriver[driverId]!;
      if (o['status'] == 'delivered') {
        final collected = (o['collected_amount'] ?? cod).toDouble();
        entry['expected'] += cod;
        entry['collected'] += collected;
      } else if (!['failed', 'cancelled'].contains(o['status'])) {
        entry['outstanding'] += cod;
      }
    }

    final rows = byDriver.values.toList()
      ..sort((a, b) => (b['collected'] as double).compareTo(a['collected'] as double));

    final totalCollected = rows.fold<double>(0, (sum, r) => sum + (r['collected'] as double));
    final totalOutstanding = rows.fold<double>(0, (sum, r) => sum + (r['outstanding'] as double));

    if (rows.isEmpty) {
      return const Center(child: Text('No COD orders in this range', style: TextStyle(color: AppColors.textSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _statTile('Total Collected', totalCollected.toStringAsFixed(0), color: AppColors.statusDelivered)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Still Outstanding', totalOutstanding.toStringAsFixed(0), color: AppColors.statusAssigned)),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text('Driver')),
                DataColumn(label: Text('Expected')),
                DataColumn(label: Text('Collected')),
                DataColumn(label: Text('Difference')),
                DataColumn(label: Text('Outstanding')),
              ],
              rows: rows.map((r) {
                final diff = (r['collected'] as double) - (r['expected'] as double);
                return DataRow(cells: [
                  DataCell(Text(r['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text((r['expected'] as double).toStringAsFixed(0))),
                  DataCell(Text((r['collected'] as double).toStringAsFixed(0))),
                  DataCell(Text(diff.toStringAsFixed(0), style: TextStyle(color: diff == 0 ? AppColors.textSecondary : (diff < 0 ? AppColors.statusFailed : AppColors.statusDelivered)))),
                  DataCell(Text((r['outstanding'] as double).toStringAsFixed(0), style: const TextStyle(color: AppColors.statusAssigned))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 4: Merchant Volume
  // ============================================================
  Widget _merchantVolumeTab() {
    final Map<String, Map<String, dynamic>> byMerchant = {};

    for (final o in _orders) {
      final merchantId = o['merchant_id'] as String?;
      if (merchantId == null) continue;
      final name = o['merchant']?['full_name'] ?? 'Unnamed';

      byMerchant.putIfAbsent(merchantId, () => {
        'name': name, 'total': 0, 'delivered': 0, 'failed': 0, 'cancelled': 0, 'cod': 0.0,
      });

      final entry = byMerchant[merchantId]!;
      entry['total']++;
      if (o['status'] == 'delivered') entry['delivered']++;
      if (o['status'] == 'failed') entry['failed']++;
      if (o['status'] == 'cancelled') entry['cancelled']++;
      entry['cod'] += (o['cod_amount'] ?? 0).toDouble();
    }

    final rows = byMerchant.values.toList()
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    if (rows.isEmpty) {
      return const Center(child: Text('No merchant orders in this range', style: TextStyle(color: AppColors.textSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          columns: const [
            DataColumn(label: Text('Merchant')),
            DataColumn(label: Text('Total Orders')),
            DataColumn(label: Text('Delivered')),
            DataColumn(label: Text('Failed')),
            DataColumn(label: Text('Cancelled')),
            DataColumn(label: Text('Total COD Value')),
          ],
          rows: rows.map((r) {
            return DataRow(cells: [
              DataCell(Text(r['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${r['total']}')),
              DataCell(Text('${r['delivered']}', style: const TextStyle(color: AppColors.statusDelivered))),
              DataCell(Text('${r['failed']}', style: const TextStyle(color: AppColors.statusFailed))),
              DataCell(Text('${r['cancelled']}', style: const TextStyle(color: AppColors.textSecondary))),
              DataCell(Text((r['cod'] as double).toStringAsFixed(0))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}