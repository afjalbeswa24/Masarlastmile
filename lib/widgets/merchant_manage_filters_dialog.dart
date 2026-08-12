import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MerchantManageFiltersDialog extends StatefulWidget {
  final Map<String, bool> enabledFilters;
  const MerchantManageFiltersDialog({super.key, required this.enabledFilters});

  @override
  State<MerchantManageFiltersDialog> createState() => _MerchantManageFiltersDialogState();
}

class _MerchantManageFiltersDialogState extends State<MerchantManageFiltersDialog> {
  late Map<String, bool> _temp;

  final _labels = {
    'status': 'Status',
    'consignee': 'Consignee Name',
    'city': 'City',
    'phone': 'Phone',
    'quantity': 'Quantity',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$selectedCount item(s) selected', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            ..._labels.entries.map((e) {
              final checked = _temp[e.key] ?? false;
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.purple,
                title: Text(e.value),
                value: checked,
                onChanged: (v) => setState(() => _temp[e.key] = v ?? false),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _temp), child: const Text('Apply')),
      ],
    );
  }
}