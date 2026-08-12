import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class WarehouseHomeTab extends StatefulWidget {
  const WarehouseHomeTab({super.key});

  @override
  State<WarehouseHomeTab> createState() => _WarehouseHomeTabState();
}

class _WarehouseHomeTabState extends State<WarehouseHomeTab> {
  int _pickedUpCount = 0;
  int _sortedCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final pickedUp = await supabase.from('orders').select('id').eq('status', 'picked_up');
    final sorted = await supabase.from('orders').select('id').eq('status', 'sorted');
    setState(() {
      _pickedUpCount = (pickedUp as List).length;
      _sortedCount = (sorted as List).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warehouse, color: AppColors.purple),
                  const SizedBox(width: 12),
                  const Text('Warehouse Overview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Awaiting Sort',
                      value: '$_pickedUpCount',
                      color: AppColors.statusPickedUp,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Sorted',
                      value: '$_sortedCount',
                      color: AppColors.statusSorted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}