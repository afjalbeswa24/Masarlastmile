import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Drop-in replacement for Flutter's built-in showTimePicker — same
/// call signature, but a compact scrollable Hours/Minutes picker instead
/// of the large analog clock dial.
Future<TimeOfDay?> showCompactTimePicker({required BuildContext context, TimeOfDay? initialTime}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (context) => _CompactTimePickerDialog(initial: initialTime ?? TimeOfDay.now()),
  );
}

class _CompactTimePickerDialog extends StatefulWidget {
  final TimeOfDay initial;
  const _CompactTimePickerDialog({required this.initial});

  @override
  State<_CompactTimePickerDialog> createState() => _CompactTimePickerDialogState();
}

class _CompactTimePickerDialogState extends State<_CompactTimePickerDialog> {
  static const _itemHeight = 36.0;

  late int _hour;
  late int _minute;
  late ScrollController _hourController;
  late ScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourController = ScrollController(initialScrollOffset: _hour * _itemHeight);
    _minuteController = ScrollController(initialScrollOffset: _minute * _itemHeight);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Widget _column({
    required int count,
    required int selected,
    required ScrollController controller,
    required ValueChanged<int> onSelect,
  }) {
    return SizedBox(
      width: 64,
      height: 200,
      child: ListView.builder(
        controller: controller,
        itemExtent: _itemHeight,
        itemCount: count,
        itemBuilder: (context, i) {
          final isSelected = i == selected;
          return InkWell(
            onTap: () => onSelect(i),
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.purple : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                i.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.purple),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Text('Hours', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    _column(count: 24, selected: _hour, controller: _hourController, onSelect: (v) => setState(() => _hour = v)),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Text('Minutes', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    _column(count: 60, selected: _minute, controller: _minuteController, onSelect: (v) => setState(() => _minute = v)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
                  onPressed: () => Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute)),
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}