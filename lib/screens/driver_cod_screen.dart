import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/qatar_time.dart';

class DriverCodScreen extends StatefulWidget {
  const DriverCodScreen({super.key});

  @override
  State<DriverCodScreen> createState() => _DriverCodScreenState();
}

class _DriverCodScreenState extends State<DriverCodScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final driverId = supabase.auth.currentUser!.id;
    final today = QatarTime.todayStr();

    final data = await supabase
        .from('orders')
        .select('''
          id, order_code, consignee_name, phone, full_address, status,
          cod_amount, collected_amount, delivered_at,
          merchant:profiles!orders_merchant_id_fkey(full_name)
        ''')
        .eq('assigned_driver_id', driverId)
        .eq('delivery_date', today)
        .gt('cod_amount', 0)
        .order('delivered_at', ascending: false);

    setState(() {
      _orders = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final delivered = _orders.where((o) => o['status'] == 'delivered').toList();
    final pending = _orders.where((o) => o['status'] != 'delivered').toList();

    double expectedTotal = 0, collectedTotal = 0;
    for (final o in delivered) {
      expectedTotal += (o['cod_amount'] ?? 0).toDouble();
      collectedTotal += (o['collected_amount'] ?? o['cod_amount'] ?? 0).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's COD Collection"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _orders.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('No COD orders for today', style: TextStyle(color: AppColors.textSecondary))),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Card(
                          color: AppColors.purpleLight,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('Collected', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(collectedTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.statusDelivered)),
                                  ],
                                ),
                                Container(width: 1, height: 36, color: AppColors.border),
                                Column(
                                  children: [
                                    const Text('Expected (delivered)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(expectedTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (pending.isNotEmpty) ...[
                                  Container(width: 1, height: 36, color: AppColors.border),
                                  Column(
                                    children: [
                                      const Text('Still pending', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      Text('${pending.length} orders', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.statusAssigned)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (delivered.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text('Delivered — collected', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                          ),
                          ...delivered.map((o) => _codCard(o, collected: true)),
                        ],
                        if (pending.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 8, bottom: 6),
                            child: Text('Not yet delivered', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                          ),
                          ...pending.map((o) => _codCard(o, collected: false)),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _codCard(Map<String, dynamic> o, {required bool collected}) {
    final cod = (o['cod_amount'] ?? 0).toDouble();
    final got = (o['collected_amount'] ?? o['cod_amount'] ?? 0).toDouble();
    final mismatch = collected && (got - cod).abs() > 0.001;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(o['consignee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text(
                  collected ? got.toStringAsFixed(2) : cod.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: !collected ? AppColors.statusAssigned : (mismatch ? AppColors.statusFailed : AppColors.statusDelivered),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Client: ${o['merchant']?['full_name'] ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(o['full_address'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(o['order_code'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (mismatch)
                  Text('expected ${cod.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.statusFailed)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}