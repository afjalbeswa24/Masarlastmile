import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/qatar_time.dart';

class _LeaderboardStat {
  int total = 0;
  int hit = 0;
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();
  int _chartYear = DateTime.now().year;
  bool _loading = true;

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _yearOrders = [];

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final rangeData = await supabase
        .from('orders')
        .select('''
          id, status, assigned_driver_id, cod_amount, collected_amount, delivered_at,
          delivery_date, delivery_window_start, delivery_window_end,
          driver:profiles!orders_assigned_driver_id_fkey(full_name),
          merchant:profiles!orders_merchant_id_fkey(full_name)
        ''')
        .gte('delivery_date', _fmtDate(_rangeStart))
        .lte('delivery_date', _fmtDate(_rangeEnd));

    final yearData = await supabase
        .from('orders')
        .select('id, created_at')
        .gte('created_at', DateTime(_chartYear, 1, 1).toIso8601String())
        .lt('created_at', DateTime(_chartYear + 1, 1, 1).toIso8601String());

    setState(() {
      _orders = List<Map<String, dynamic>>.from(rangeData);
      _yearOrders = List<Map<String, dynamic>>.from(yearData);
      _loading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );
    if (picked != null) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _orders.length;
    final completed = _orders.where((o) => o['status'] == 'delivered').length;
    final failed = _orders.where((o) => o['status'] == 'failed').length;
    final pending = total - completed - failed;

    final assigned = _orders.where((o) => o['assigned_driver_id'] != null).length;
    final unassigned = total - assigned;

    int onTime = 0, early = 0, late = 0;
    for (final o in _orders) {
      if (o['status'] != 'delivered' || o['delivered_at'] == null) continue;
      final deliveredTime = QatarTime.fromIso(o['delivered_at']);
      final start = o['delivery_window_start'] as String?;
      final end = o['delivery_window_end'] as String?;
      if (start == null || end == null) continue;
      final deliveredHm = QatarTime.hm(deliveredTime);
      if (deliveredHm.compareTo(start) < 0) {
        early++;
      } else if (deliveredHm.compareTo(end) > 0) {
        late++;
      } else {
        onTime++;
      }
    }
    final punctualityTotal = onTime + early + late;

    // Top drivers by on-time rate — only counts deliveries that had a
    // delivery window set (same eligibility rule as the Punctuality card
    // above), and requires at least 3 such deliveries so one lucky/unlucky
    // order doesn't put a driver at the top or bottom.
    final driverStats = <String, _LeaderboardStat>{};
    for (final o in _orders) {
      if (o['status'] != 'delivered' || o['delivered_at'] == null) continue;
      final start = o['delivery_window_start'] as String?;
      final end = o['delivery_window_end'] as String?;
      if (start == null || end == null) continue;
      final name = o['driver']?['full_name'] as String?;
      if (name == null) continue;
      final stat = driverStats.putIfAbsent(name, () => _LeaderboardStat());
      stat.total++;
      final hm = QatarTime.hm(QatarTime.fromIso(o['delivered_at']));
      if (hm.compareTo(start) >= 0 && hm.compareTo(end) <= 0) stat.hit++;
    }
    final topDrivers = driverStats.entries.where((e) => e.value.total >= 3).toList()
      ..sort((a, b) => (b.value.hit / b.value.total).compareTo(a.value.hit / a.value.total));

    // Top merchants by order volume in the selected date range.
    final merchantStats = <String, _LeaderboardStat>{};
    for (final o in _orders) {
      final name = o['merchant']?['full_name'] as String?;
      if (name == null) continue;
      final stat = merchantStats.putIfAbsent(name, () => _LeaderboardStat());
      stat.total++;
      if (o['status'] == 'delivered') stat.hit++;
    }
    final topMerchants = merchantStats.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    double toBeCollected = 0, collected = 0;
    for (final o in _orders) {
      final cod = (o['cod_amount'] ?? 0).toDouble();
      if (cod <= 0) continue;
      if (o['status'] == 'delivered') {
        collected += (o['collected_amount'] ?? cod).toDouble();
      } else if (o['status'] != 'failed' && o['status'] != 'cancelled') {
        toBeCollected += cod;
      }
    }

    final monthlyCounts = List<int>.filled(12, 0);
    for (final o in _yearOrders) {
      final created = DateTime.parse(o['created_at']).toLocal();
      monthlyCounts[created.month - 1]++;
    }
    final yearTotal = monthlyCounts.fold<int>(0, (a, b) => a + b);

    return Container(
      color: AppColors.background,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('${_fmtDate(_rangeStart)} ~ ${_fmtDate(_rangeEnd)}', style: const TextStyle(fontSize: 13)),
                    onPressed: _pickDateRange,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _tasksCard(total, pending, completed, failed)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _gaugeCard(
                          title: 'Assigned vs. Unassigned',
                          centerLines: ['$assigned Assigned', '$unassigned Unassigned'],
                          segments: [assigned.toDouble(), unassigned.toDouble()],
                          colors: [AppColors.purple, AppColors.navy],
                          footer: [
                            _footerStat('Assigned', total == 0 ? '0%' : '${(assigned / total * 100).toStringAsFixed(1)}%', AppColors.purple),
                            _footerStat('Unassigned', total == 0 ? '0%' : '${(unassigned / total * 100).toStringAsFixed(1)}%', AppColors.navy),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _gaugeCard(
                            title: 'Punctuality',
                            centerLines: ['$onTime On Time', '$early Early', '$late Late'],
                            segments: [onTime.toDouble(), early.toDouble(), late.toDouble()],
                            colors: [AppColors.purple, AppColors.statusPending, AppColors.statusFailed],
                            footer: [
                              _footerStat('On Time', punctualityTotal == 0 ? '0%' : '${(onTime / punctualityTotal * 100).toStringAsFixed(1)}%', AppColors.purple),
                              _footerStat('Early', punctualityTotal == 0 ? '0%' : '${(early / punctualityTotal * 100).toStringAsFixed(1)}%', AppColors.statusPending),
                              _footerStat('Late', punctualityTotal == 0 ? '0%' : '${(late / punctualityTotal * 100).toStringAsFixed(1)}%', AppColors.statusFailed),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _leaderboardCard(
                        title: 'Top drivers',
                        subtitle: 'By on-time delivery rate, minimum 3 timed deliveries',
                        entries: topDrivers.take(3).toList(),
                        emptyText: 'Not enough timed deliveries yet to rank drivers.',
                        rowSubtitle: (e) => '${e.value.hit} of ${e.value.total} on time',
                        rowValue: (e) => '${(e.value.hit / e.value.total * 100).round()}%',
                        rowValueColor: (e) => (e.value.hit / e.value.total) >= 0.5 ? AppColors.statusDelivered : AppColors.statusPending,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _leaderboardCard(
                        title: 'Top merchants',
                        subtitle: 'By order volume in this date range',
                        entries: topMerchants.take(3).toList(),
                        emptyText: 'No orders in this date range yet.',
                        rowSubtitle: (e) => '${e.value.hit} of ${e.value.total} delivered',
                        rowValue: (e) => '${e.value.total}',
                        rowValueColor: (e) => AppColors.purple,
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _monthlyChartCard(monthlyCounts, yearTotal)),
                      const SizedBox(width: 16),
                      Expanded(child: _cashCard(toBeCollected, collected)),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  static const _rankColors = [
    (bg: Color(0xFFFAC775), fg: Color(0xFF633806)), // gold
    (bg: Color(0xFFD3D1C7), fg: Color(0xFF444441)), // silver
    (bg: Color(0xFFF0997B), fg: Color(0xFF4A1B0C)), // bronze
  ];

  static const _avatarColors = [AppColors.purple, Color(0xFF0F6E56), Color(0xFF993C1D)];

  Widget _leaderboardCard({
    required String title,
    required String subtitle,
    required List<MapEntry<String, _LeaderboardStat>> entries,
    required String emptyText,
    required String Function(MapEntry<String, _LeaderboardStat>) rowSubtitle,
    required String Function(MapEntry<String, _LeaderboardStat>) rowValue,
    required Color Function(MapEntry<String, _LeaderboardStat>) rowValueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyText, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            )
          else
            ...entries.asMap().entries.map((indexed) {
              final i = indexed.key;
              final e = indexed.value;
              final initials = e.key.trim().isEmpty
                  ? '?'
                  : e.key.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
              return Padding(
                padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 10),
                child: Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: _rankColors[i].bg, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _rankColors[i].fg)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: _avatarColors[i % _avatarColors.length], shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(rowSubtitle(e), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(rowValue(e), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: rowValueColor(e))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _cardShell({required String title, required Widget child, double width = 260}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
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

  Widget _statRow(IconData icon, Color color, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tasksCard(int total, int pending, int completed, int failed) {
    return _cardShell(
      title: 'Tasks',
      child: Column(
        children: [
          _statRow(Icons.layers_outlined, AppColors.purple, 'Total Tasks', total),
          const Divider(),
          _statRow(Icons.hourglass_bottom, Colors.orange, 'Pending Tasks', pending),
          const Divider(),
          _statRow(Icons.check_circle_outline, AppColors.statusDelivered, 'Completed Tasks', completed),
          const Divider(),
          _statRow(Icons.cancel_outlined, AppColors.statusFailed, 'Failed Tasks', failed),
        ],
      ),
    );
  }

  Widget _footerStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ],
    );
  }

  Widget _gaugeCard({
    required String title,
    required List<String> centerLines,
    required List<double> segments,
    required List<Color> colors,
    required List<Widget> footer,
  }) {
    final total = segments.fold<double>(0, (a, b) => a + b);
    final sections = total == 0
        ? [PieChartSectionData(value: 1, color: Colors.grey.shade300, showTitle: false, radius: 20)]
        : List.generate(segments.length, (i) {
            return PieChartSectionData(
              value: segments[i] == 0 ? 0.001 : segments[i],
              color: colors[i],
              showTitle: false,
              radius: 20,
            );
          });

    return _cardShell(
      title: title,
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(sections: sections, centerSpaceRadius: 42, sectionsSpace: 2, startDegreeOffset: -90),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: centerLines
                      .map((line) => Text(line, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: footer),
        ],
      ),
    );
  }

  Widget _monthlyChartCard(List<int> monthlyCounts, int yearTotal) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final maxVal = monthlyCounts.isEmpty ? 1 : monthlyCounts.reduce((a, b) => a > b ? a : b);

    return _cardShell(
      title: '',
      width: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Monthly Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  setState(() => _chartYear--);
                  _load();
                },
              ),
              Text('$_chartYear'),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  setState(() => _chartYear++);
                  _load();
                },
              ),
            ],
          ),
          Text('Total Tasks: ($yearTotal)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: (maxVal * 1.2).clamp(1, double.infinity),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(months[i], style: const TextStyle(fontSize: 9)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(12, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(toY: monthlyCounts[i].toDouble(), color: AppColors.navy, width: 14, borderRadius: BorderRadius.circular(2)),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cashCard(double toBeCollected, double collected) {
    return _cardShell(
      title: 'Delivery Cash',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.statusAssigned),
                const SizedBox(width: 10),
                const Expanded(child: Text('To be Collected', style: TextStyle(fontSize: 13))),
                Text(toBeCollected.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.attach_money, color: AppColors.statusDelivered),
                const SizedBox(width: 10),
                const Expanded(child: Text('Collected Cash', style: TextStyle(fontSize: 13))),
                Text(collected.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusDelivered)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}