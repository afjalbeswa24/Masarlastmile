import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/manage_columns_dialog.dart';
import '../widgets/manage_filters_dialog.dart';
import '../widgets/date_range_button.dart';
import '../widgets/order_data_grid.dart';
import 'order_edit_screen.dart';
import 'barcode_print_screen.dart';
import 'bulk_edit_dialog.dart';
import 'export_dialog.dart';
import 'add_user_screen.dart';
import 'new_task_screen.dart';
import 'audit_trail_dialog.dart';
import 'dispatcher_bulk_upload_screen.dart';
import 'manage_users_screen.dart';
import 'insights_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tracking_screen.dart';
import '../utils/qatar_time.dart';
import 'reports_screen.dart';

enum _DispatcherTab { orders, insights, tracking, reports }

class DispatcherHomeScreen extends StatefulWidget {
  const DispatcherHomeScreen({super.key});

  @override
  State<DispatcherHomeScreen> createState() => _DispatcherHomeScreenState();
}

class _DispatcherHomeScreenState extends State<DispatcherHomeScreen> {
  _DispatcherTab _currentTab = _DispatcherTab.orders;

  List<Map<String, dynamic>> _orders = [];
  Set<String> _selectedIds = {};
  bool _loading = true;
  final _searchController = TextEditingController();

  final _filters = OrderFilters();
  DateTimeRange? _dateRange;

  Map<String, bool> _columnVisibility = {
    'id': false, 'pod': true, 'audit': true, 'merchant': true, 'status': true,
    'date': true, 'after': true, 'before': true, 'awb': true, 'company': true,
    'driver': true, 'quantity': true, 'cod': true, 'consignee': true,
    'address': true, 'city': true, 'phone': true,
    'delivery_type': true, 'remote_area': true, 'notes': false,
    'delivery_start': false, 'delivery_end': false,
    'collected': false, 'failure_reason': false, 'punctuality': false,
  };

  Map<String, bool> _enabledFilters = {
    'status': true, 'driver': true, 'merchant': true,
    'consignee': false, 'city': false,
  };

  @override
  void initState() {
    super.initState();
    final today = QatarTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    _dateRange = DateTimeRange(start: todayOnly, end: todayOnly);
    _loadOrders();
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadOrders({List<String>? awbFilter}) async {
    setState(() => _loading = true);

    var query = supabase.from('orders').select('''
      id, order_code, order_number, status, consignee_name, phone, full_address, city,
      quantity, cod_amount, delivery_date, delivery_window_start, delivery_window_end,
      assigned_driver_id, assigned_collection_id, merchant_id, company_id, notes, proof_photo_url,
      delivered_at, out_for_delivery_at, collected_amount, failure_reason, proof_photo_url_2,
      delivered_lat, delivered_lng, delivery_type, remote_area,
      driver:profiles!orders_assigned_driver_id_fkey(full_name),
      merchant:profiles!orders_merchant_id_fkey(full_name),
      company:companies(name)
    ''');

    if (awbFilter != null && awbFilter.isNotEmpty) {
      query = query.inFilter('order_code', awbFilter);
    }
    if (_filters.statuses.isNotEmpty) {
      query = query.inFilter('status', _filters.statuses.toList());
    }
    if (_filters.driverIds.isNotEmpty) {
      final wantsUnassigned = _filters.driverIds.contains('__unassigned__');
      final realDriverIds = _filters.driverIds.where((id) => id != '__unassigned__').toList();

      if (wantsUnassigned && realDriverIds.isNotEmpty) {
        query = query.or('assigned_driver_id.is.null,assigned_driver_id.in.(${realDriverIds.join(',')})');
      } else if (wantsUnassigned) {
        query = query.filter('assigned_driver_id', 'is', null);
      } else {
        query = query.inFilter('assigned_driver_id', realDriverIds);
      }
    }
    if (_filters.merchantIds.isNotEmpty) {
      query = query.inFilter('merchant_id', _filters.merchantIds.toList());
    }
    if (_filters.companyIds.isNotEmpty) {
      query = query.inFilter('company_id', _filters.companyIds.toList());
    }
    if (_filters.consigneeSearch.isNotEmpty) {
      query = query.ilike('consignee_name', '%${_filters.consigneeSearch}%');
    }
    if (_filters.citySearch.isNotEmpty) {
      query = query.ilike('city', '%${_filters.citySearch}%');
    }
    if (_filters.phoneSearch.isNotEmpty) {
      query = query.ilike('phone', '%${_filters.phoneSearch}%');
    }
    if (_filters.quantitySearch.isNotEmpty) {
      final qty = int.tryParse(_filters.quantitySearch);
      if (qty != null) query = query.eq('quantity', qty);
    }
    if (_filters.beforeTimeHour != null) {
      query = query.eq('delivery_window_end', _filters.beforeTimeHour!);
    }
    if (_filters.collectableCash == 'yes') {
      query = query.gt('cod_amount', 0);
    } else if (_filters.collectableCash == 'no') {
      query = query.or('cod_amount.eq.0,cod_amount.is.null');
    }
    if (_dateRange != null) {
      query = query
          .gte('delivery_date', _fmtDate(_dateRange!.start))
          .lte('delivery_date', _fmtDate(_dateRange!.end));
    }

    final data = await query.order('created_at', ascending: false);
    var orders = List<Map<String, dynamic>>.from(data);

    if (_filters.punctuality.isNotEmpty) {
      orders = orders.where((o) {
        if (o['status'] != 'delivered' || o['delivered_at'] == null) return false;
        final start = o['delivery_window_start'] as String?;
        final end = o['delivery_window_end'] as String?;
        if (start == null || end == null) return false;
        final delivered = DateTime.parse(o['delivered_at']).toLocal();
        final hm = '${delivered.hour.toString().padLeft(2, '0')}:${delivered.minute.toString().padLeft(2, '0')}:00';
        final label = hm.compareTo(start) < 0 ? 'Early' : (hm.compareTo(end) > 0 ? 'Late' : 'On Time');
        return _filters.punctuality.contains(label);
      }).toList();
    }

    setState(() {
      _orders = orders;
      _selectedIds = {};
      _loading = false;
    });
  }

  void _runSearch() {
    final raw = _searchController.text.trim();
    if (raw.isEmpty) {
      _loadOrders();
      return;
    }
    final awbList = raw.split(RegExp(r'\s+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    _loadOrders(awbFilter: awbList);
  }

  String _fmtDateTimeForExport(String? iso) {
    if (iso == null) return '';
    final d = QatarTime.fromIso(iso);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _punctualityForExport(Map<String, dynamic> o) {
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

  Future<void> _exportSelected() async {
    final selectedOrders = _orders.where((o) => _selectedIds.contains(o['id'])).toList();
    if (selectedOrders.isEmpty) return;

    final workbook = xl.Excel.createExcel();
    final sheet = workbook['Orders'];
    workbook.delete('Sheet1');

    final columnMap = <String, String>{
      'id': 'ID',
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
      'consignee': 'Consignee Name',
      'address': 'Full Address',
      'city': 'City',
      'phone': 'Phone',
      'delivery_start': 'Delivery Start',
      'delivery_end': 'Delivery End',
      'collected': 'Collected Amount',
      'failure_reason': 'Failure Reason',
      'punctuality': 'Punctuality',
      'notes': 'Notes',
    };

    final activeKeys = columnMap.keys.where((k) => _columnVisibility[k] ?? false).toList();
    if (activeKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No columns are currently visible. Enable some via Manage Columns first.')),
      );
      return;
    }

    sheet.appendRow(activeKeys.map((k) => xl.TextCellValue(columnMap[k]!)).toList());

    for (final order in selectedOrders) {
      final row = <xl.CellValue>[];
      for (final key in activeKeys) {
        switch (key) {
          case 'id':
            row.add(xl.TextCellValue('${order['order_number'] ?? ''}'));
            break;
          case 'merchant':
            row.add(xl.TextCellValue(order['merchant']?['full_name'] ?? ''));
            break;
          case 'status':
            row.add(xl.TextCellValue(order['status'] ?? ''));
            break;
          case 'date':
            row.add(xl.TextCellValue(order['delivery_date'] ?? ''));
            break;
          case 'after':
            row.add(xl.TextCellValue(order['delivery_window_start'] ?? ''));
            break;
          case 'before':
            row.add(xl.TextCellValue(order['delivery_window_end'] ?? ''));
            break;
          case 'awb':
            row.add(xl.TextCellValue(order['order_code'] ?? ''));
            break;
          case 'company':
            row.add(xl.TextCellValue(order['company']?['name'] ?? ''));
            break;
          case 'driver':
            row.add(xl.TextCellValue(order['driver']?['full_name'] ?? 'Unassigned'));
            break;
          case 'quantity':
            row.add(xl.TextCellValue('${order['quantity'] ?? ''}'));
            break;
          case 'cod':
            row.add(xl.TextCellValue('${order['cod_amount'] ?? ''}'));
            break;
          case 'consignee':
            row.add(xl.TextCellValue(order['consignee_name'] ?? ''));
            break;
          case 'address':
            row.add(xl.TextCellValue(order['full_address'] ?? ''));
            break;
          case 'city':
            row.add(xl.TextCellValue(order['city'] ?? ''));
            break;
          case 'phone':
            row.add(xl.TextCellValue(order['phone'] ?? ''));
            break;
          case 'delivery_start':
            row.add(xl.TextCellValue(_fmtDateTimeForExport(order['out_for_delivery_at'])));
            break;
          case 'delivery_end':
            row.add(xl.TextCellValue(_fmtDateTimeForExport(order['delivered_at'])));
            break;
          case 'collected':
            row.add(xl.TextCellValue(order['collected_amount'] != null ? '${order['collected_amount']}' : ''));
            break;
          case 'failure_reason':
            row.add(xl.TextCellValue(order['failure_reason'] ?? ''));
            break;
          case 'punctuality':
            row.add(xl.TextCellValue(_punctualityForExport(order)));
            break;
          case 'notes':
            row.add(xl.TextCellValue(order['notes'] ?? ''));
            break;
        }
      }
      sheet.appendRow(row);
    }

    final bytes = workbook.encode();
    if (bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'selected_orders_${DateTime.now().millisecondsSinceEpoch}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Widget _navItem(String label, _DispatcherTab tab) {
    final active = _currentTab == tab;
    return InkWell(
      onTap: () => setState(() => _currentTab = tab),
      child: _NavTab(label: label, active: active),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case _DispatcherTab.insights:
        return const InsightsScreen();
      case _DispatcherTab.tracking:
        return const TrackingScreen();
      case _DispatcherTab.reports:
        return const ReportsScreen();
      case _DispatcherTab.orders:
        return _buildOrdersBody();
    }
  }

  Widget _buildOrdersBody() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by AWB',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _runSearch),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
              if (_selectedIds.isNotEmpty) ...[
                const SizedBox(width: 14),
                Text('${_selectedIds.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.purple, fontSize: 13)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.download, size: 18),
                  tooltip: 'Export Selected',
                  onPressed: _exportSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code, size: 18),
                  tooltip: 'Print Barcodes',
                  onPressed: () {
                    final selectedOrders = _orders.where((o) => _selectedIds.contains(o['id'])).toList();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BarcodePrintScreen(orders: selectedOrders)));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 18),
                  tooltip: 'Bulk Edit',
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => BulkEditDialog(orderIds: _selectedIds.toList()),
                    );
                    if (changed == true) _loadOrders();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete orders?'),
                        content: Text('This will permanently delete ${_selectedIds.length} order(s). This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await supabase.from('orders').delete().inFilter('id', _selectedIds.toList());
                      _loadOrders();
                    }
                  },
                ),
              ],
              const Spacer(),
              DateRangeButton(
                range: _dateRange,
                onChanged: (r) {
                  setState(() => _dateRange = r);
                  _loadOrders();
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Manage Filters', style: TextStyle(fontSize: 13)),
                onPressed: () async {
                  final result = await showDialog<Map<String, bool>>(
                    context: context,
                    builder: (_) => ManageFiltersDialog(enabledFilters: _enabledFilters),
                  );
                  if (result != null) setState(() => _enabledFilters = result);
                },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Task'),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewTaskScreen()));
                  _loadOrders();
                },
              ),
            ],
          ),
        ),
        FilterBar(
          filters: _filters,
          enabledFilters: _enabledFilters,
          onChanged: (f) => _loadOrders(),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? const Center(child: Text('No orders found', style: TextStyle(color: AppColors.textSecondary)))
                  : Container(
                      color: Colors.white,
                      child: OrderDataGrid(
                        orders: _orders,
                        columnVisibility: _columnVisibility,
                        selectedIds: _selectedIds,
                        onSelectionChanged: (ids) => setState(() => _selectedIds = ids),
                        onEdit: (order) async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderEditScreen(orderId: order['id'])));
                          _loadOrders();
                        },
                        onViewPod: (order) => showDialog(
                          context: context,
                          builder: (_) => _PodViewerDialog(
                            photoUrl1: order['proof_photo_url'],
                            photoUrl2: order['proof_photo_url_2'],
                          ),
                        ),
                        onViewAudit: (orderId, orderCode) => showDialog(
                          context: context,
                          builder: (_) => AuditTrailDialog(orderId: orderId, orderCode: orderCode),
                        ),
                        onViewLocation: (lat, lng) => launchUrl(
                          Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                          webOnlyWindowName: '_blank',
                        ),
                        onReschedule: (order) async {
                          final changed = await showDialog<bool>(
                            context: context,
                            builder: (_) => BulkEditDialog(orderIds: [order['id']], initialStatus: 'rescheduled'),
                          );
                          if (changed == true) _loadOrders();
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top nav bar — always visible, never rebuilt when switching tabs
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                _navItem('Essence Express', _DispatcherTab.insights),
                const SizedBox(width: 32),
                _navItem('Orders', _DispatcherTab.orders),
                const SizedBox(width: 20),
                _navItem('Tracking', _DispatcherTab.tracking),
                const SizedBox(width: 20),
                _navItem('Reports', _DispatcherTab.reports),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.people_alt, color: Colors.white70),
                  tooltip: 'Manage Users',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white70),
                  tooltip: 'Add User',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddUserScreen())),
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.white70),
                  tooltip: 'Bulk Upload Orders',
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const DispatcherBulkUploadScreen()));
                    _loadOrders();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.view_column, color: Colors.white70),
                  tooltip: 'Manage Columns',
                  onPressed: () async {
                    final result = await showDialog<Map<String, bool>>(
                      context: context,
                      builder: (_) => ManageColumnsDialog(visibility: _columnVisibility),
                    );
                    if (result != null) setState(() => _columnVisibility = result);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white70),
                  tooltip: 'Export Orders',
                  onPressed: () => showDialog(context: context, builder: (_) => ExportDialog(columnVisibility: _columnVisibility)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: () { _searchController.clear(); _loadOrders(); },
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.purple,
                  child: Text(
                    (supabase.auth.currentUser?.email ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () => supabase.auth.signOut(),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final bool active;
  const _NavTab({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: active ? Colors.white : Colors.white60,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        fontSize: 14,
      ),
    );
  }
}

class _PodViewerDialog extends StatelessWidget {
  final String? photoUrl1;
  final String? photoUrl2;
  const _PodViewerDialog({this.photoUrl1, this.photoUrl2});

  Widget _photoBlock(String url, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Image.network(url, fit: BoxFit.contain, height: 300),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text('Open $label in new tab (to save/copy)'),
            onPressed: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoUrl1 != null && photoUrl1!.isNotEmpty) _photoBlock(photoUrl1!, 'Photo 1'),
              if (photoUrl2 != null && photoUrl2!.isNotEmpty) _photoBlock(photoUrl2!, 'Photo 2'),
            ],
          ),
        ),
      ),
    );
  }
}