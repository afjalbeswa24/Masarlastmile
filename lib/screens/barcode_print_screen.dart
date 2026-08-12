import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' as fw;
import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../main.dart';

class BarcodePrintScreen extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  const BarcodePrintScreen({super.key, required this.orders});

  @override
  State<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _BarcodePrintScreenState extends State<BarcodePrintScreen> {
  List<Map<String, dynamic>> _labels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    final orderIds = widget.orders.map((o) => o['id'] as String).toList();
    final boxes = await supabase
        .from('order_boxes')
        .select('order_id, box_number, box_code')
        .inFilter('order_id', orderIds)
        .order('box_number');

    final boxList = List<Map<String, dynamic>>.from(boxes);
    final labels = <Map<String, dynamic>>[];

    for (final order in widget.orders) {
      final orderBoxes = boxList.where((b) => b['order_id'] == order['id']).toList();
      final total = orderBoxes.isEmpty ? 1 : orderBoxes.length;
      if (orderBoxes.isEmpty) {
        labels.add({...order, 'box_code': order['order_code'], 'box_number': 1, 'box_total': 1});
      } else {
        for (final b in orderBoxes) {
          labels.add({...order, 'box_code': b['box_code'], 'box_number': b['box_number'], 'box_total': total});
        }
      }
    }

    setState(() {
      _labels = labels;
      _loading = false;
    });
  }

  String _fmtDateTime(Map<String, dynamic> label) {
    final date = label['delivery_date'] as String?;
    final before = label['delivery_window_end'] as String?;
    final datePart = date ?? '—';
    final timePart = before != null && before.length >= 5 ? before.substring(0, 5) : '—';
    return '$datePart - $timePart';
  }

  // A4 = 595 x 842 pt. 3 columns x 4 rows = 12 labels per page.
  static const double _pageMargin = 16;
  static const double _labelSpacing = 4;
  static const double _a4Width = 595.28;
  static const double _a4Height = 841.89;
  static const double _labelWidth = (_a4Width - (_pageMargin * 2) - (_labelSpacing * 2)) / 3;
  static const double _labelHeight = (_a4Height - (_pageMargin * 2) - (_labelSpacing * 3)) / 4;

  Future<void> _printLabels() async {
    final doc = pw.Document();

    pw.Widget buildLabel(Map<String, dynamic> label) {
      final companyName = label['company']?['name'] ?? '';
      final merchantName = label['merchant']?['full_name'] ?? '';
      final consigneeName = label['consignee_name'] ?? '';
      final city = label['city'] ?? '';
      final boxCode = label['box_code'] ?? '';
      final boxNumber = label['box_number'] ?? 1;
      final boxTotal = label['box_total'] ?? 1;

      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
          child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(_fmtDateTime(label), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.Divider(height: 0.5, thickness: 0.5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text('FROM: $merchantName', style: const pw.TextStyle(fontSize: 8), maxLines: 1, overflow: pw.TextOverflow.clip),
            ),
            pw.Divider(height: 0.5, thickness: 0.5),
            pw.Expanded(
              child: pw.Center(
                child: pw.BarcodeWidget(
                  barcode: bc.Barcode.qrCode(),
                  data: boxCode,
                  width: 78,
                  height: 78,
                  drawText: false,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Center(child: pw.Text(boxCode, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
            ),
            pw.Divider(height: 0.5, thickness: 0.5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text('TO: $consigneeName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), maxLines: 1, overflow: pw.TextOverflow.clip),
            ),
            pw.Divider(height: 0.5, thickness: 0.5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Box $boxNumber of $boxTotal', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(city, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],
          ),
        ),
      );
    }

    // Chunk into pages of 12 (3 columns x 4 rows), using GridView for exact,
    // non-overlapping cell placement (Wrap doesn't lock content to fixed cells reliably).
    for (var i = 0; i < _labels.length; i += 12) {
      final pageLabels = _labels.skip(i).take(12).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_pageMargin),
          build: (context) {
            return pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: _labelWidth / _labelHeight,
              children: pageLabels.map(buildLabel).toList(),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Labels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: _loading ? null : _printLabels,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _labels.map((label) {
                  final companyName = label['company']?['name'] ?? '';
                  final merchantName = label['merchant']?['full_name'] ?? '';
                  final consigneeName = label['consignee_name'] ?? '';
                  final city = label['city'] ?? '';
                  final boxCode = label['box_code'] ?? '';
                  final boxNumber = label['box_number'] ?? 1;
                  final boxTotal = label['box_total'] ?? 1;

                  return Container(
                    width: 190,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black54), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                              Text(_fmtDateTime(label), style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: Text('FROM: $merchantName', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: fw.BarcodeWidget(barcode: fw.Barcode.qrCode(), data: boxCode, width: 100, height: 100, drawText: false),
                        ),
                        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(boxCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
                        const Divider(height: 1),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('TO: $consigneeName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Box $boxNumber of $boxTotal', style: const TextStyle(fontSize: 10)),
                              Text(city, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}