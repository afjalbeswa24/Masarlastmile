import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DateRangeButton extends StatefulWidget {
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;

  const DateRangeButton({super.key, required this.range, required this.onChanged});

  @override
  State<DateRangeButton> createState() => _DateRangeButtonState();
}

class _DateRangeButtonState extends State<DateRangeButton> {
  final _buttonKey = GlobalKey();

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _open(BuildContext context) async {
    final box = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final screenSize = MediaQuery.of(context).size;

    const popoverWidth = 520.0;
    const popoverHeight = 300.0;

    double left = offset.dx;
    if (left + popoverWidth > screenSize.width - 12) {
      left = screenSize.width - popoverWidth - 12;
    }
    if (left < 12) left = 12;

    double top = offset.dy + buttonSize.height + 6;
    if (top + popoverHeight > screenSize.height - 12) {
      // Not enough room below — open above the button instead.
      top = offset.dy - popoverHeight - 6;
    }

    final result = await showDialog<DateTimeRange?>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Tapping anywhere outside the popover closes it without changing anything.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _DateRangePopover(initial: widget.range),
          ),
        ],
      ),
    );
    if (result != null || widget.range != null) {
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    final label = range == null ? 'Date Range' : '${_fmt(range.start)} ~ ${_fmt(range.end)}';

    return OutlinedButton.icon(
      key: _buttonKey,
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

class _DateRangePopover extends StatefulWidget {
  final DateTimeRange? initial;
  const _DateRangePopover({this.initial});

  @override
  State<_DateRangePopover> createState() => _DateRangePopoverState();
}

class _DateRangePopoverState extends State<_DateRangePopover> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _leftMonth;

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start;
    _end = widget.initial?.end;
    final anchor = _start ?? DateTime.now();
    _leftMonth = DateTime(anchor.year, anchor.month, 1);
  }

  void _quickSelect(DateTime start, DateTime end) {
    setState(() {
      _start = DateTime(start.year, start.month, start.day);
      _end = DateTime(end.year, end.month, end.day);
      _leftMonth = DateTime(_start!.year, _start!.month, 1);
    });
  }

  void _tapDay(DateTime day) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _end = _start;
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  bool _isInRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return day.isAfter(_start!) && day.isBefore(_end!);
  }

  bool _isEndpoint(DateTime day) {
    return (_start != null && _isSameDay(day, _start!)) || (_end != null && _isSameDay(day, _end!));
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _monthGrid(DateTime month, {required bool showPrev, required bool showNext}) {
    const weekLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday-start grid

    final cells = <Widget>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final isEndpoint = _isEndpoint(day);
      final inRange = _isInRange(day);
      cells.add(
        InkWell(
          onTap: () => _tapDay(day),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isEndpoint ? AppColors.purple : (inRange ? AppColors.purpleLight : null),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$d',
              style: TextStyle(
                fontSize: 11,
                color: isEndpoint ? Colors.white : AppColors.textPrimary,
                fontWeight: isEndpoint ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return SizedBox(
      width: 180,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                child: showPrev
                    ? InkWell(onTap: () => setState(() => _leftMonth = DateTime(_leftMonth.year, _leftMonth.month - 1, 1)), child: const Icon(Icons.chevron_left, size: 16, color: AppColors.textSecondary))
                    : null,
              ),
              Expanded(
                child: Text('${monthNames[month.month - 1]} ${month.year}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 20,
                child: showNext
                    ? InkWell(onTap: () => setState(() => _leftMonth = DateTime(_leftMonth.year, _leftMonth.month + 1, 1)), child: const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            children: [
              Row(
                children: [for (final w in weekLabels) Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))))],
              ),
              const SizedBox(height: 2),
              for (int row = 0; row < (cells.length / 7).ceil(); row++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      for (int col = 0; col < 7; col++)
                        Expanded(
                          child: SizedBox(
                            height: 22,
                            child: (row * 7 + col) < cells.length ? cells[row * 7 + col] : const SizedBox(),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetTile(String label, DateTime start, DateTime end) {
    return InkWell(
      onTap: () => _quickSelect(start, end),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1, 1);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 110,
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border, width: 0.5))),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _presetTile('Today', today, today),
                        _presetTile('Yesterday', today.subtract(const Duration(days: 1)), today.subtract(const Duration(days: 1))),
                        _presetTile('Last 7 days', today.subtract(const Duration(days: 6)), today),
                        _presetTile('This month', DateTime(today.year, today.month, 1), today),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _monthGrid(_leftMonth, showPrev: true, showNext: false),
                        const SizedBox(width: 18),
                        _monthGrid(rightMonth, showPrev: false, showNext: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: (_start != null && _end != null)
                        ? () => Navigator.pop(context, DateTimeRange(start: _start!, end: _end!))
                        : null,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}