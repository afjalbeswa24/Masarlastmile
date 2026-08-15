import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/merchant_manage_columns_dialog.dart';
import '../widgets/merchant_manage_filters_dialog.dart';
import '../widgets/date_range_button.dart';
import '../widgets/order_data_grid.dart';
import '../widgets/merchant_export_dialog.dart';
import 'order_edit_screen.dart';
import 'barcode_print_screen.dart';
import 'audit_trail_dialog.dart';
import 'bulk_upload_screen.dart';
import 'merchant_new_task_screen.dart';
import '../utils/qatar_time.dart';
import 'package:url_launcher/url_launcher.dart';


class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  Set<String> _selectedIds = {};
  bool _loading = true;
  final _searchController = TextEditingController();
  final _filters = OrderFilters();
  DateTimeRange? _dateRange;

  // Driver is intentionally excluded and not present in the manage-columns list,
  // so merchants never see who's assigned to their deliveries.
  Map<String, bool> _columnVisibility = {
    'id': false, 'pod': true, 'audit': true, 'status': true,
    'date': true, 'after': true, 'before': true, 'awb': true,
    'quantity': true, 'cod': true, 'consignee': true,
    'address': true, 'city': true, 'phone': true,
    'delivery_type': true, 'remote_area': true, 'notes': false,
    // Dispatcher-only columns — explicitly off since the shared grid
    // widget defaults unlisted columns to visible.
    'driver': false, 'delivery_start': false, 'delivery_end': false,
    'failure_reason': false, 'punctuality': false,
  };

  Map<String, bool> _enabledFilters = {
    'status': true, 'consignee': false, 'city': false,
    // Explicitly off — the shared FilterBar defaults any unlisted key to
    // true, and neither Driver nor Merchant belongs on a merchant's own
    // order screen (they're always looking at their own orders).
    'driver': false, 'merchant': false,
  };

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final today = QatarTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    _dateRange = DateTimeRange(start: todayOnly, end: todayOnly);
    _loadOrders();
  }

  Future<void> _loadOrders({List<String>? awbFilter}) async {
    setState(() => _loading = true);
    final merchantId = supabase.auth.currentUser!.id;

    var query = supabase.from('orders').select('''
      id, order_code, order_number, status, consignee_name, phone, full_address, city,
      quantity, cod_amount, delivery_date, delivery_window_start, delivery_window_end,
      notes, proof_photo_url, proof_photo_url_2,
      delivery_type, remote_area, merchant_id,
      merchant:profiles!orders_merchant_id_fkey(full_name),
      company:companies(name)
    ''').eq('merchant_id', merchantId);

    if (awbFilter != null && awbFilter.isNotEmpty) {
      query = query.inFilter('order_code', awbFilter);
    }
    if (_filters.statuses.isNotEmpty) {
      query = query.inFilter('status', _filters.statuses.toList());
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
    if (_dateRange != null) {
      query = query
          .gte('delivery_date', _fmtDate(_dateRange!.start))
          .lte('delivery_date', _fmtDate(_dateRange!.end));
    }

    final data = await query.order('created_at', ascending: false);

    setState(() {
      _orders = List<Map<String, dynamic>>.from(data);
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

  Future<void> _bulkCancel() async {
    final selectedOrders = _orders.where((o) => _selectedIds.contains(o['id'])).toList();
    final cancellable = selectedOrders.where((o) => o['status'] == 'pending').toList();
    final notCancellable = selectedOrders.length - cancellable.length;

    if (cancellable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('None of the selected orders can be cancelled (only "Pending" orders can be cancelled).')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel selected orders?'),
        content: Text(
          notCancellable > 0
              ? '${cancellable.length} order(s) will be cancelled. $notCancellable order(s) can\'t be cancelled since they\'re already in progress.'
              : '${cancellable.length} order(s) will be cancelled.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from('orders').update({'status': 'cancelled'}).inFilter('id', cancellable.map((o) => o['id']).toList());
      _loadOrders();
    }
  }

  Future<void> _exportSelected() async {
    final selectedOrders = _orders.where((o) => _selectedIds.contains(o['id'])).toList();
    if (selectedOrders.isEmpty) return;

    final workbook = xl.Excel.createExcel();
    final sheet = workbook['Orders'];
    workbook.delete('Sheet1');

    // Driver and Punctuality intentionally excluded from merchant exports.
    final columnMap = <String, String>{
      'awb': 'AWB',
      'status': 'Status',
      'quantity': 'Quantity',
      'cod': 'COD Amount',
      'consignee': 'Consignee Name',
      'address': 'Full Address',
      'city': 'City',
      'phone': 'Phone',
      'date': 'Delivery Date',
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
          case 'awb': row.add(xl.TextCellValue(order['order_code'] ?? '')); break;
          case 'status': row.add(xl.TextCellValue(order['status'] ?? '')); break;
          case 'quantity': row.add(xl.TextCellValue('${order['quantity'] ?? ''}')); break;
          case 'cod': row.add(xl.TextCellValue('${order['cod_amount'] ?? ''}')); break;
          case 'consignee': row.add(xl.TextCellValue(order['consignee_name'] ?? '')); break;
          case 'address': row.add(xl.TextCellValue(order['full_address'] ?? '')); break;
          case 'city': row.add(xl.TextCellValue(order['city'] ?? '')); break;
          case 'phone': row.add(xl.TextCellValue(order['phone'] ?? '')); break;
          case 'date': row.add(xl.TextCellValue(order['delivery_date'] ?? '')); break;
          case 'notes': row.add(xl.TextCellValue(order['notes'] ?? '')); break;
        }
      }
      sheet.appendRow(row);
    }

    final bytes = workbook.encode();
    if (bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'my_selected_orders_${DateTime.now().millisecondsSinceEpoch}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
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
                  const SizedBox(width: 12),
                  Text('${_selectedIds.length} selected',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.purple, fontSize: 13)),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.download, size: 18),
                    tooltip: 'Export Selected',
                    onPressed: _exportSelected,
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code, size: 18),
                    tooltip: 'Print Labels',
                    onPressed: () {
                      final selectedOrders = _orders.where((o) => _selectedIds.contains(o['id'])).toList();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BarcodePrintScreen(orders: selectedOrders)));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                    tooltip: 'Cancel',
                    onPressed: _bulkCancel,
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Manage Filters',
                  onPressed: () async {
                    final result = await showDialog<Map<String, bool>>(
                      context: context,
                      builder: (_) => MerchantManageFiltersDialog(enabledFilters: _enabledFilters),
                    );
                    if (result != null) setState(() => _enabledFilters = result);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.view_column),
                  tooltip: 'Manage Columns',
                  onPressed: () async {
                    final result = await showDialog<Map<String, bool>>(
                      context: context,
                      builder: (_) => MerchantManageColumnsDialog(visibility: _columnVisibility),
                    );
                    if (result != null) setState(() => _columnVisibility = result);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  tooltip: 'Bulk Upload',
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkUploadScreen()));
                    _loadOrders();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download Report',
                  onPressed: () => showDialog(context: context, builder: (_) => const MerchantExportDialog()),
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
                const SizedBox(width: 4),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Task'),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantNewTaskScreen()));
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
                          
                        ),
                      ),
          ),
        ],
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