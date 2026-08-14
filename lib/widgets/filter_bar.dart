import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'compact_time_picker.dart';

class OrderFilters {
  Set<String> statuses = {};
  Set<String> driverIds = {};
  Set<String> merchantIds = {};
  Set<String> companyIds = {};
  String consigneeSearch = '';
  String citySearch = '';
  String phoneSearch = '';
  String quantitySearch = '';
  Set<String> punctuality = {}; // 'Early', 'On Time', 'Late'
  String? beforeTimeHour; // 'HH:00:00'
  String? collectableCash; // 'yes' or 'no'

  bool get isEmpty =>
      statuses.isEmpty && driverIds.isEmpty && merchantIds.isEmpty && companyIds.isEmpty &&
      consigneeSearch.isEmpty && citySearch.isEmpty && phoneSearch.isEmpty && quantitySearch.isEmpty &&
      punctuality.isEmpty && beforeTimeHour == null && collectableCash == null;

  void clear() {
    statuses = {};
    driverIds = {};
    merchantIds = {};
    companyIds = {};
    consigneeSearch = '';
    citySearch = '';
    phoneSearch = '';
    quantitySearch = '';
    punctuality = {};
    beforeTimeHour = null;
    collectableCash = null;
  }
}

class FilterBar extends StatefulWidget {
  final OrderFilters filters;
  final Map<String, bool> enabledFilters;
  final ValueChanged<OrderFilters> onChanged;

  const FilterBar({
    super.key,
    required this.filters,
    required this.enabledFilters,
    required this.onChanged,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _merchants = [];
  List<Map<String, dynamic>> _companies = [];

  final _statuses = ['pending', 'picked_up', 'sorted', 'assigned', 'out_for_delivery', 'delivered', 'failed', 'cancelled', 'rescheduled', 'returned_to_shipper'];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final drivers = await supabase.from('profiles').select('id, full_name').eq('role', 'driver');
    final merchants = await supabase.from('profiles').select('id, full_name').eq('role', 'merchant');
    final companies = await supabase.from('companies').select('id, name');
    setState(() {
      _drivers = List<Map<String, dynamic>>.from(drivers);
      _merchants = List<Map<String, dynamic>>.from(merchants);
      _companies = List<Map<String, dynamic>>.from(companies);
    });
  }

  Future<void> _openMultiSelect({
    required String title,
    required List<MapEntry<String, String>> options,
    required Set<String> selected,
  }) async {
    final tempSelection = Set<String>.from(selected);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options.map((opt) {
                      final checked = tempSelection.contains(opt.key);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(opt.value),
                        value: checked,
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              tempSelection.add(opt.key);
                            } else {
                              tempSelection.remove(opt.key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, <String>{}), child: const Text('Clear')),
                TextButton(onPressed: () => Navigator.pop(context, tempSelection), child: const Text('Apply')),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      selected
        ..clear()
        ..addAll(result);
      widget.onChanged(widget.filters);
    }
  }

  Future<void> _openTextFilter({
    required String title,
    required String initial,
    required ValueChanged<String> onApply,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Search $title', border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Clear')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Apply')),
        ],
      ),
    );
    if (result != null) {
      onApply(result);
      widget.onChanged(widget.filters);
    }
  }

  Widget _chip({required String label, required bool active, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.filter_list, size: 16, color: active ? AppColors.purple : AppColors.textSecondary),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColors.purpleLight : AppColors.background,
        foregroundColor: active ? AppColors.purple : AppColors.textPrimary,
        side: BorderSide(color: active ? AppColors.purple : AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (widget.enabledFilters['status'] ?? true) {
      chips.add(_chip(
        label: widget.filters.statuses.isEmpty ? 'Status' : 'Status (${widget.filters.statuses.length})',
        active: widget.filters.statuses.isNotEmpty,
        onTap: () => _openMultiSelect(title: 'Status', selected: widget.filters.statuses, options: _statuses.map((s) => MapEntry(s, s)).toList()),
      ));
    }
    if (widget.enabledFilters['driver'] ?? true) {
      chips.add(_chip(
        label: widget.filters.driverIds.isEmpty ? 'Driver' : 'Driver (${widget.filters.driverIds.length})',
        active: widget.filters.driverIds.isNotEmpty,
        onTap: () => _openMultiSelect(
          title: 'Driver',
          selected: widget.filters.driverIds,
          options: [
            const MapEntry('__unassigned__', 'Unassigned'),
            ..._drivers.map((d) => MapEntry(d['id'] as String, (d['full_name'] ?? 'Unnamed') as String)),
          ],
        ),
      ));
    }
    if (widget.enabledFilters['merchant'] ?? true) {
      chips.add(_chip(
        label: widget.filters.merchantIds.isEmpty ? 'Merchant' : 'Merchant (${widget.filters.merchantIds.length})',
        active: widget.filters.merchantIds.isNotEmpty,
        onTap: () => _openMultiSelect(title: 'Merchant', selected: widget.filters.merchantIds, options: _merchants.map((m) => MapEntry(m['id'] as String, (m['full_name'] ?? 'Unnamed') as String)).toList()),
      ));
    }
    if (widget.enabledFilters['company'] ?? false) {
      chips.add(_chip(
        label: widget.filters.companyIds.isEmpty ? 'Company' : 'Company (${widget.filters.companyIds.length})',
        active: widget.filters.companyIds.isNotEmpty,
        onTap: () => _openMultiSelect(title: 'Company', selected: widget.filters.companyIds, options: _companies.map((c) => MapEntry(c['id'] as String, (c['name'] ?? 'Unnamed') as String)).toList()),
      ));
    }
    if (widget.enabledFilters['consignee'] ?? false) {
      chips.add(_chip(
        label: widget.filters.consigneeSearch.isEmpty ? 'Consignee Name' : 'Consignee: ${widget.filters.consigneeSearch}',
        active: widget.filters.consigneeSearch.isNotEmpty,
        onTap: () => _openTextFilter(
          title: 'Consignee Name',
          initial: widget.filters.consigneeSearch,
          onApply: (v) => widget.filters.consigneeSearch = v,
        ),
      ));
    }
    if (widget.enabledFilters['city'] ?? false) {
      chips.add(_chip(
        label: widget.filters.citySearch.isEmpty ? 'City' : 'City: ${widget.filters.citySearch}',
        active: widget.filters.citySearch.isNotEmpty,
        onTap: () => _openTextFilter(
          title: 'City',
          initial: widget.filters.citySearch,
          onApply: (v) => widget.filters.citySearch = v,
        ),
      ));
    }
    if (widget.enabledFilters['phone'] ?? false) {
      chips.add(_chip(
        label: widget.filters.phoneSearch.isEmpty ? 'Phone' : 'Phone: ${widget.filters.phoneSearch}',
        active: widget.filters.phoneSearch.isNotEmpty,
        onTap: () => _openTextFilter(
          title: 'Phone',
          initial: widget.filters.phoneSearch,
          onApply: (v) => widget.filters.phoneSearch = v,
        ),
      ));
    }
    if (widget.enabledFilters['quantity'] ?? false) {
      chips.add(_chip(
        label: widget.filters.quantitySearch.isEmpty ? 'Quantity' : 'Quantity: ${widget.filters.quantitySearch}',
        active: widget.filters.quantitySearch.isNotEmpty,
        onTap: () => _openTextFilter(
          title: 'Quantity',
          initial: widget.filters.quantitySearch,
          onApply: (v) => widget.filters.quantitySearch = v,
        ),
      ));
    }
    if (widget.enabledFilters['punctuality'] ?? false) {
      chips.add(_chip(
        label: widget.filters.punctuality.isEmpty ? 'Punctuality' : 'Punctuality (${widget.filters.punctuality.length})',
        active: widget.filters.punctuality.isNotEmpty,
        onTap: () => _openMultiSelect(
          title: 'Punctuality',
          selected: widget.filters.punctuality,
          options: const [MapEntry('Early', 'Early'), MapEntry('On Time', 'On Time'), MapEntry('Late', 'Late')],
        ),
      ));
    }
    if (widget.enabledFilters['before_hour'] ?? false) {
      chips.add(_chip(
        label: widget.filters.beforeTimeHour == null ? 'Before Time Hour' : 'Before: ${widget.filters.beforeTimeHour!.substring(0, 5)}',
        active: widget.filters.beforeTimeHour != null,
        onTap: () async {
          final action = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Before Time Hour'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Choose a time'),
                    onTap: () => Navigator.pop(context, 'pick'),
                  ),
                  if (widget.filters.beforeTimeHour != null)
                    ListTile(
                      leading: const Icon(Icons.clear, color: Colors.red),
                      title: const Text('Clear filter', style: TextStyle(color: Colors.red)),
                      onTap: () => Navigator.pop(context, 'clear'),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ],
            ),
          );

          if (action == 'clear') {
            widget.filters.beforeTimeHour = null;
            widget.onChanged(widget.filters);
          } else if (action == 'pick') {
            final picked = await showCompactTimePicker(context: context, initialTime: TimeOfDay.now());
            if (picked != null) {
              widget.filters.beforeTimeHour = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
              widget.onChanged(widget.filters);
            }
          }
        },
      ));
    }
    if (widget.enabledFilters['collectable_cash'] ?? false) {
      chips.add(_chip(
        label: widget.filters.collectableCash == null ? 'Collectable Cash' : 'Collectable Cash: ${widget.filters.collectableCash == 'yes' ? 'Yes' : 'No'}',
        active: widget.filters.collectableCash != null,
        onTap: () async {
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Collectable Cash (COD)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: const Text('Yes — has COD'), onTap: () => Navigator.pop(context, 'yes')),
                  ListTile(title: const Text('No — no COD'), onTap: () => Navigator.pop(context, 'no')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Clear')),
              ],
            ),
          );
          if (result != null) {
            widget.filters.collectableCash = result.isEmpty ? null : result;
            widget.onChanged(widget.filters);
          }
        },
      ));
    }

    if (!widget.filters.isEmpty) {
      chips.add(TextButton.icon(
        icon: const Icon(Icons.clear, size: 16),
        label: const Text('Clear filters', style: TextStyle(fontSize: 13)),
        onPressed: () {
          widget.filters.clear();
          widget.onChanged(widget.filters);
        },
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: chips
            .expand((c) => [c, const SizedBox(width: 10)])
            .toList()
          ..removeLast(),
      ),
    );
  }
}