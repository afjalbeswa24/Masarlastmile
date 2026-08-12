import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ManageFiltersDialog extends StatefulWidget {
  final Map<String, bool> enabledFilters;
  const ManageFiltersDialog({super.key, required this.enabledFilters});

  @override
  State<ManageFiltersDialog> createState() => _ManageFiltersDialogState();
}

class _ManageFiltersDialogState extends State<ManageFiltersDialog> {
  late Map<String, bool> _temp;

  final _labels = {
    'status': 'Status',
    'driver': 'Driver',
    'merchant': 'Merchant',
    'company': 'Company',
    'consignee': 'Consignee Name',
    'city': 'City',
    'phone': 'Phone',
    'quantity': 'Quantity',
    'punctuality': 'Punctuality',
    'before_hour': 'Before Time Hour',
    'collectable_cash': 'Collectable Cash',
  };

  @override
  void initState() {
    super.initState();
    _temp = Map.from(widget.enabledFilters);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _temp.values.where((v) => v).length;

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Filters')),
          TextButton(
            onPressed: () => setState(() => _temp.updateAll((k, v) => false)),
            child: const Text('Reset'),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$selectedCount item(s) selected', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _labels.entries.map((e) {
                    final checked = _temp[e.key] ?? false;
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.purple,
                      title: Text(e.value),
                      value: checked,
                      onChanged: (v) => setState(() => _temp[e.key] = v ?? false),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _temp),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}