import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/qatar_time.dart';
import '../widgets/status_pill.dart';

class _ColDef {
  final String key;
  final String label;
  final double width;
  final bool sortable;
  final Comparable Function(Map<String, dynamic> order)? sortValue;
  final Widget Function(BuildContext context, Map<String, dynamic> order) cellBuilder;

  _ColDef({
    required this.key,
    required this.label,
    required this.width,
    this.sortable = false,
    this.sortValue,
    required this.cellBuilder,
  });
}

class OrderDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final Map<String, bool> columnVisibility;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final void Function(Map<String, dynamic> order) onEdit;
  final void Function(Map<String, dynamic> order) onViewPod;
  final void Function(String orderId, String orderCode) onViewAudit;
  final void Function(double lat, double lng)? onViewLocation;
  final void Function(Map<String, dynamic> order)? onReschedule;

  const OrderDataGrid({
    super.key,
    required this.orders,
    required this.columnVisibility,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onEdit,
    required this.onViewPod,
    required this.onViewAudit,
    this.onViewLocation,
    this.onReschedule,
  });

  @override
  State<OrderDataGrid> createState() => _OrderDataGridState();
}

class _OrderDataGridState extends State<OrderDataGrid> {
  final ScrollController _hController = ScrollController();
  final ScrollController _vControllerLeft = ScrollController();
  final ScrollController _vControllerRight = ScrollController();
  bool _syncingScroll = false;

  static const double _rowHeight = 52;
  static const double _headerHeight = 44;
  static const double _checkboxWidth = 44;

  String? _sortKey;
  bool _sortAscending = true;
  int _rowsPerPage = 50;
  int _currentPage = 0;

  Offset? _panStart;
  double _panStartH = 0;
  double _panStartV = 0;

  late final List<_ColDef> _allColumns = [
    _ColDef(
      key: 'id', label: 'ID', width: 60, sortable: true,
      sortValue: (o) => o['order_number'] ?? 0,
      cellBuilder: (ctx, o) => Text('${o['order_number'] ?? ''}'),
    ),
    _ColDef(
      key: 'pod', label: 'POD', width: 44,
      cellBuilder: (ctx, o) {
        final hasPhoto = (o['proof_photo_url'] ?? '').toString().isNotEmpty;
        return hasPhoto
            ? IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.image, size: 16, color: AppColors.purple),
                onPressed: () => widget.onViewPod(o),
              )
            : Icon(Icons.image_not_supported, size: 16, color: Colors.grey.shade300);
      },
    ),
    
    _ColDef(
      key: 'audit', label: 'Audit', width: 44,
      cellBuilder: (ctx, o) => IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
        onPressed: () => widget.onViewAudit(o['id'], o['order_code'] ?? ''),
      ),
    ),
    _ColDef(
      key: 'merchant', label: 'Merchant', width: 120, sortable: true,
      sortValue: (o) => (o['merchant']?['full_name'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['merchant']?['full_name'] ?? '—', child: Text(o['merchant']?['full_name'] ?? '—', overflow: TextOverflow.ellipsis)),
    ),
    _ColDef(
      key: 'status', label: 'Status', width: 170, sortable: true,
      sortValue: (o) => (o['status'] ?? '') as String,
      cellBuilder: (ctx, o) {
        final status = o['status'] ?? 'pending';
        if (status == 'failed' && widget.onReschedule != null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusPill(status: status),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => widget.onReschedule!(o),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Reschedule', style: TextStyle(color: AppColors.purple, fontSize: 11, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                ),
              ),
            ],
          );
        }
        return StatusPill(status: status);
      },
    ),
    _ColDef(
      key: 'date', label: 'Delivery Date', width: 100, sortable: true,
      sortValue: (o) => (o['delivery_date'] ?? '') as String,
      cellBuilder: (ctx, o) => Text(o['delivery_date'] ?? '—', style: const TextStyle(color: AppColors.textSecondary)),
    ),
    _ColDef(
      key: 'after', label: 'After', width: 70, sortable: true,
      sortValue: (o) => (o['delivery_window_start'] ?? '') as String,
      cellBuilder: (ctx, o) => Text(o['delivery_window_start'] != null ? QatarTime.trimSeconds(o['delivery_window_start']) : '—', style: const TextStyle(color: AppColors.textSecondary)),
    ),
    _ColDef(
      key: 'before', label: 'Before', width: 70, sortable: true,
      sortValue: (o) => (o['delivery_window_end'] ?? '') as String,
      cellBuilder: (ctx, o) => Text(o['delivery_window_end'] != null ? QatarTime.trimSeconds(o['delivery_window_end']) : '—', style: const TextStyle(color: AppColors.textSecondary)),
    ),
    _ColDef(
      key: 'awb', label: 'AWB', width: 140, sortable: true,
      sortValue: (o) => (o['order_code'] ?? '') as String,
      cellBuilder: (ctx, o) => InkWell(
        onTap: () => widget.onEdit(o),
        child: Text(
          o['order_code'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.purple, decoration: TextDecoration.underline),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
    _ColDef(
      key: 'company', label: 'Company', width: 100, sortable: true,
      sortValue: (o) => (o['company']?['name'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['company']?['name'] ?? '—', child: Text(o['company']?['name'] ?? '—', overflow: TextOverflow.ellipsis)),
    ),
    _ColDef(
      key: 'driver', label: 'Driver', width: 120, sortable: true,
      sortValue: (o) => (o['driver']?['full_name'] ?? '') as String,
      cellBuilder: (ctx, o) {
        final driverName = o['driver']?['full_name'] as String?;
        final isUnassigned = driverName == null || driverName.isEmpty;
        final display = isUnassigned ? 'Unassigned' : driverName;
        return Tooltip(
          message: display,
          child: Text(
            display,
            style: TextStyle(
              color: isUnassigned ? AppColors.statusFailed : AppColors.textSecondary,
              fontStyle: isUnassigned ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    ),
    _ColDef(
      key: 'quantity', label: 'Quantity', width: 80, sortable: true,
      sortValue: (o) => (o['quantity'] ?? 0) as int,
      cellBuilder: (ctx, o) => Text('${o['quantity'] ?? ''}'),
    ),
    _ColDef(
      key: 'cod', label: 'COD Amount', width: 100, sortable: true,
      sortValue: (o) => (o['cod_amount'] ?? 0) as num,
      cellBuilder: (ctx, o) => Text('${o['cod_amount'] ?? 0}'),
    ),
    _ColDef(
      key: 'consignee', label: 'Consignee Name', width: 150, sortable: true,
      sortValue: (o) => (o['consignee_name'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['consignee_name'] ?? '', child: Text(o['consignee_name'] ?? '', overflow: TextOverflow.ellipsis)),
    ),
    _ColDef(
      key: 'address', label: 'Full Address', width: 220, sortable: true,
      sortValue: (o) => (o['full_address'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['full_address'] ?? '', child: Text(o['full_address'] ?? '', overflow: TextOverflow.ellipsis)),
    ),
    _ColDef(
      key: 'city', label: 'City', width: 100, sortable: true,
      sortValue: (o) => (o['city'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['city'] ?? '', child: Text(o['city'] ?? '', style: const TextStyle(color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
    ),
    _ColDef(
      key: 'phone', label: 'Phone', width: 120, sortable: true,
      sortValue: (o) => (o['phone'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['phone'] ?? '', child: Text(o['phone'] ?? '', overflow: TextOverflow.ellipsis)),
    ),
    _ColDef(
      key: 'delivery_start', label: 'Delivery Start', width: 140, sortable: true,
      sortValue: (o) => (o['out_for_delivery_at'] ?? '') as String,
      cellBuilder: (ctx, o) => Text(_fmtDateTime(o['out_for_delivery_at']), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ),
    _ColDef(
      key: 'delivery_end', label: 'Delivery End', width: 140, sortable: true,
      sortValue: (o) => (o['delivered_at'] ?? '') as String,
      cellBuilder: (ctx, o) => Text(_fmtDateTime(o['delivered_at']), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ),
    _ColDef(
      key: 'collected', label: 'Collected Amount', width: 130, sortable: true,
      sortValue: (o) => (o['collected_amount'] ?? 0) as num,
      cellBuilder: (ctx, o) => Text(o['collected_amount'] != null ? '${o['collected_amount']}' : '—'),
    ),
    _ColDef(
      key: 'failure_reason', label: 'Failure Reason', width: 180, sortable: true,
      sortValue: (o) => (o['failure_reason'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['failure_reason'] ?? '—', child: Text(o['failure_reason'] ?? '—', overflow: TextOverflow.ellipsis)),
    ),
    _ColDef(
      key: 'punctuality', label: 'Punctuality', width: 100, sortable: true,
      sortValue: (o) => _punctualityOf(o),
      cellBuilder: (ctx, o) {
        final p = _punctualityOf(o);
        if (p.isEmpty) return const Text('—', style: TextStyle(color: AppColors.textSecondary));
        final color = p == 'On Time' ? AppColors.statusDelivered : (p == 'Early' ? AppColors.statusPending : AppColors.statusFailed);
        return Text(p, style: TextStyle(color: color, fontWeight: FontWeight.w600));
      },
    ),
    
    _ColDef(
      key: 'delivery_type', label: 'Delivery Type', width: 110, sortable: true,
      sortValue: (o) => (o['delivery_type'] ?? 'standard') as String,
      cellBuilder: (ctx, o) => Text(_deliveryTypeLabel(o['delivery_type']), style: const TextStyle(color: AppColors.textSecondary)),
    ),
    _ColDef(
      key: 'remote_area', label: 'Remote Area', width: 100, sortable: true,
      sortValue: (o) => (o['remote_area'] == true) ? 1 : 0,
      cellBuilder: (ctx, o) {
        final isRemote = o['remote_area'] == true;
        return Text(
          isRemote ? 'Yes' : 'No',
          style: TextStyle(color: isRemote ? AppColors.statusAssigned : AppColors.textSecondary, fontWeight: isRemote ? FontWeight.w600 : FontWeight.normal),
        );
      },
    ),
    _ColDef(
      key: 'notes', label: 'Notes', width: 160, sortable: true,
      sortValue: (o) => (o['notes'] ?? '') as String,
      cellBuilder: (ctx, o) => Tooltip(message: o['notes'] ?? '', child: Text(o['notes'] ?? '', overflow: TextOverflow.ellipsis)),
    ),
  ];

  static String _deliveryTypeLabel(String? type) {
    switch (type) {
      case 'express': return 'Express';
      case 'same_day': return 'Same Day';
      case 'on_demand': return 'On Demand';
      default: return 'Standard';
    }
  }

  static String _fmtDateTime(String? iso) {
    if (iso == null) return '—';
    final d = QatarTime.fromIso(iso);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _punctualityOf(Map<String, dynamic> o) {
    if (o['status'] != 'delivered' || o['delivered_at'] == null) return '';
    final start = o['delivery_window_start'] as String?;
    final end = o['delivery_window_end'] as String?;
    if (start == null || end == null) return '';
    final delivered = QatarTime.fromIso(o['delivered_at']);
    final hm = QatarTime.hm(delivered);
    if (hm.compareTo(start) < 0) return 'Early';
    if (hm.compareTo(end) > 0) return 'Late';
    return 'On Time';
  }

  // Frozen columns: always POD + Audit (if visible). Everything else scrolls.
  static const _frozenKeys = {'pod', 'audit'};

  List<_ColDef> get _visibleColumns =>
      _allColumns.where((c) => widget.columnVisibility[c.key] ?? (c.key != 'notes' && c.key != 'id' && c.key != 'delivery_start' && c.key != 'delivery_end' && c.key != 'collected' && c.key != 'failure_reason' && c.key != 'punctuality' && c.key != 'location')).toList();

  List<_ColDef> get _frozenColumns => _visibleColumns.where((c) => _frozenKeys.contains(c.key)).toList();
  List<_ColDef> get _scrollableColumns => _visibleColumns.where((c) => !_frozenKeys.contains(c.key)).toList();

  List<Map<String, dynamic>> get _sortedOrders {
    final list = List<Map<String, dynamic>>.from(widget.orders);
    if (_sortKey != null) {
      final col = _allColumns.firstWhere((c) => c.key == _sortKey);
      if (col.sortValue != null) {
        list.sort((a, b) {
          final va = col.sortValue!(a);
          final vb = col.sortValue!(b);
          final cmp = Comparable.compare(va, vb);
          return _sortAscending ? cmp : -cmp;
        });
      }
    }
    return list;
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _vControllerLeft.addListener(() {
      if (_syncingScroll) return;
      _syncingScroll = true;
      if (_vControllerRight.hasClients && _vControllerRight.offset != _vControllerLeft.offset) {
        _vControllerRight.jumpTo(_vControllerLeft.offset.clamp(0.0, _vControllerRight.position.maxScrollExtent));
      }
      _syncingScroll = false;
    });
    _vControllerRight.addListener(() {
      if (_syncingScroll) return;
      _syncingScroll = true;
      if (_vControllerLeft.hasClients && _vControllerLeft.offset != _vControllerRight.offset) {
        _vControllerLeft.jumpTo(_vControllerRight.offset.clamp(0.0, _vControllerLeft.position.maxScrollExtent));
      }
      _syncingScroll = false;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kMiddleMouseButton != 0) {
      _panStart = event.position;
      _panStartH = _hController.hasClients ? _hController.offset : 0;
      _panStartV = _vControllerRight.hasClients ? _vControllerRight.offset : 0;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_panStart == null) return;
    final delta = event.position - _panStart!;
    if (_hController.hasClients) {
      final target = (_panStartH - delta.dx).clamp(0.0, _hController.position.maxScrollExtent);
      _hController.jumpTo(target);
    }
    if (_vControllerRight.hasClients) {
      final target = (_panStartV - delta.dy).clamp(0.0, _vControllerRight.position.maxScrollExtent);
      _vControllerRight.jumpTo(target);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _panStart = null;
  }

  Widget _headerCell(_ColDef col) {
    final isSorted = _sortKey == col.key;
    return SizedBox(
      width: col.width,
      height: _headerHeight,
      child: InkWell(
        onTap: col.sortable ? () => _toggleSort(col.key) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  col.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textPrimary),
                ),
              ),
              if (col.sortable) ...[
                const SizedBox(width: 2),
                Icon(
                  isSorted ? (_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down) : Icons.unfold_more,
                  size: 16,
                  color: isSorted ? AppColors.purple : Colors.grey.shade400,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataCell(_ColDef col, Map<String, dynamic> order) {
    return SizedBox(
      width: col.width,
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Align(alignment: Alignment.centerLeft, child: col.cellBuilder(context, order)),
      ),
    );
  }

  @override
  void dispose() {
    _hController.dispose();
    _vControllerLeft.dispose();
    _vControllerRight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frozenCols = _frozenColumns;
    final scrollCols = _scrollableColumns;
    final sorted = _sortedOrders;
    final totalItems = sorted.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _rowsPerPage).ceil();
    if (_currentPage >= totalPages) _currentPage = totalPages - 1;
    if (_currentPage < 0) _currentPage = 0;

    final start = totalItems == 0 ? 0 : _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, totalItems);
    final pageOrders = totalItems == 0 ? <Map<String, dynamic>>[] : sorted.sublist(start, end);

    final showLocationColumn = widget.onViewLocation != null;
    final frozenWidth = _checkboxWidth + (showLocationColumn ? 44 : 0) + frozenCols.fold<double>(0, (sum, c) => sum + c.width);
    final scrollableWidth = scrollCols.fold<double>(0, (sum, c) => sum + c.width);

    final allSelected = widget.orders.isNotEmpty && widget.selectedIds.length == widget.orders.length;

    return SelectionArea(
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== FROZEN SECTION: checkbox + POD + Audit =====
                SizedBox(
                  width: frozenWidth,
                  child: Column(
                    children: [
                      Container(
                        color: AppColors.background,
                        child: Row(
                          children: [
                            SizedBox(
                              width: _checkboxWidth,
                              height: _headerHeight,
                              child: Checkbox(
                                value: allSelected,
                                onChanged: (v) {
                                  if (v == true) {
                                    widget.onSelectionChanged(widget.orders.map((o) => o['id'] as String).toSet());
                                  } else {
                                    widget.onSelectionChanged({});
                                  }
                                },
                              ),
                            ),
                            if (showLocationColumn)
                              SizedBox(
                                width: 44,
                                height: _headerHeight,
                                child: const Center(child: Icon(Icons.location_on, size: 16, color: AppColors.textSecondary)),
                              ),
                            ...frozenCols.map(_headerCell),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      Expanded(
                        child: Scrollbar(
                          controller: _vControllerLeft,
                          thumbVisibility: true,
                          interactive: true,
                          notificationPredicate: (n) => n.depth == 0,
                          child: SingleChildScrollView(
                            controller: _vControllerLeft,
                            child: Column(
                              children: pageOrders.map((order) {
                                final id = order['id'] as String;
                                final isSelected = widget.selectedIds.contains(id);
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.purpleLight : Colors.white,
                                    border: const Border(bottom: BorderSide(color: AppColors.rowDivider, width: 1)),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: _checkboxWidth,
                                        height: _rowHeight,
                                        child: Checkbox(
                                          value: isSelected,
                                          onChanged: (v) {
                                            final newSet = Set<String>.from(widget.selectedIds);
                                            if (v == true) { newSet.add(id); } else { newSet.remove(id); }
                                            widget.onSelectionChanged(newSet);
                                          },
                                        ),
                                      ),
                                      if (showLocationColumn)
                                        SizedBox(
                                          width: 44,
                                          height: _rowHeight,
                                          child: Center(
                                            child: (order['delivered_lat'] != null && order['delivered_lng'] != null)
                                                ? IconButton(
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                                                    tooltip: 'View delivery location',
                                                    onPressed: () => widget.onViewLocation!(order['delivered_lat'], order['delivered_lng']),
                                                  )
                                                : Icon(Icons.location_off, size: 16, color: Colors.grey.shade300),
                                          ),
                                        ),
                                      ...frozenCols.map((c) => _dataCell(c, order)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                // ===== SCROLLABLE SECTION: everything else =====
                Expanded(
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    child: Scrollbar(
                      controller: _hController,
                      thumbVisibility: true,
                      interactive: true,
                      notificationPredicate: (n) => n.depth == 0,
                      child: SingleChildScrollView(
                        controller: _hController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: scrollableWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: AppColors.background,
                                child: Row(
                                  children: [
                                    ...scrollCols.map(_headerCell),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.border),
                              Expanded(
                                child: Scrollbar(
                                  controller: _vControllerRight,
                                  thumbVisibility: true,
                                  interactive: true,
                                  notificationPredicate: (n) => n.depth == 0,
                                  child: SingleChildScrollView(
                                    controller: _vControllerRight,
                                    child: Column(
                                      children: pageOrders.map((order) {
                                        final id = order['id'] as String;
                                        final isSelected = widget.selectedIds.contains(id);
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.purpleLight : Colors.white,
                                            border: const Border(bottom: BorderSide(color: AppColors.rowDivider, width: 1)),
                                          ),
                                          child: Row(
                                            children: [
                                              ...scrollCols.map((c) => _dataCell(c, order)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Items per page:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  underline: const SizedBox(),
                  items: [50, 100, 200, 500]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() { _rowsPerPage = v; _currentPage = 0; });
                  },
                ),
                const Spacer(),
                Text(
                  totalItems == 0 ? '0 items' : '${start + 1}-$end of $totalItems',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}