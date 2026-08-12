import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ManageColumnsDialog extends StatefulWidget {
  final Map<String, bool> visibility;
  const ManageColumnsDialog({super.key, required this.visibility});

  @override
  State<ManageColumnsDialog> createState() => _ManageColumnsDialogState();
}

class _ManageColumnsDialogState extends State<ManageColumnsDialog> {
  late Map<String, bool> _temp;

  final _labels = {
    'id': 'ID',
    'pod': 'POD',
    'audit': 'Audit',
    'merchant': 'Merchant',
    'status': 'Status',
    'date': 'Delivery Date',
    'after': 'After',
    'before': 'Before',
    'awb': 'AWB',
    'company': 'Company',
    'driver': 'Driver',
    'quantity': 'Quantity',
    'cod': 'COD Amount',
    'delivery_start': 'Delivery Start',
    'delivery_end': 'Delivery End',
    'collected': 'Collected Amount',
    'failure_reason': 'Failure Reason',
    'punctuality': 'Punctuality',
    'delivery_type': 'Delivery Type',
    'remote_area': 'Remote Area',
    'notes': 'Notes',
  };

  @override
  void initState() {
    super.initState();
    _temp = Map.from(widget.visibility);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Columns')),
          TextButton(
            onPressed: () => setState(() => _temp.updateAll((k, v) => true)),
            child: const Text('Reset'),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _labels.entries.map((e) {
              return SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.purple,
                title: Text(e.value),
                value: _temp[e.key] ?? true,
                onChanged: (v) => setState(() => _temp[e.key] = v),
              );
            }).toList(),
          ),
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