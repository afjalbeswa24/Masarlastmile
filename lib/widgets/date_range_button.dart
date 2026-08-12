import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DateRangeButton extends StatelessWidget {
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;

  const DateRangeButton({super.key, required this.range, required this.onChanged});

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<DateTimeRange?>(
      context: context,
      builder: (context) => _DateRangeDialog(initial: range),
    );
    if (result != null || range != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = range == null
        ? 'Date Range'
        : '${_fmt(range!.start)} ~ ${_fmt(range!.end)}';

    return OutlinedButton.icon(
      onPressed: () => _open(context),
      icon: Icon(Icons.calendar_today, size: 15, color: range != null ? AppColors.purple : AppColors.textSecondary),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        backgroundColor: range != null ? AppColors.purpleLight : AppColors.background,
        foregroundColor: range != null ? AppColors.purple : AppColors.textPrimary,
        side: BorderSide(color: range != null ? AppColors.purple : AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _DateRangeDialog extends StatefulWidget {
  final DateTimeRange? initial;
  const _DateRangeDialog({this.initial});

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  DateTimeRange? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  void _quickSelect(int startOffset, int endOffset) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).add(Duration(days: startOffset));
    final end = DateTime(now.year, now.month, now.day).add(Duration(days: endOffset));
    setState(() => _selected = DateTimeRange(start: start, end: end));
  }

  Future<void> _openCalendar() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selected,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.purple),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => _quickSelect(-1, -1), child: const Text('Yesterday')),
                OutlinedButton(onPressed: () => _quickSelect(0, 0), child: const Text('Today')),
                OutlinedButton(onPressed: () => _quickSelect(1, 1), child: const Text('Tomorrow')),
                OutlinedButton(onPressed: () => _quickSelect(0, 7), child: const Text('Next 7 Days')),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('Choose custom range'),
              onPressed: _openCalendar,
            ),
            const SizedBox(height: 12),
            if (_selected != null)
              Text(
                'Selected: ${_selected!.start.toString().split(' ')[0]} ~ ${_selected!.end.toString().split(' ')[0]}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Clear'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}