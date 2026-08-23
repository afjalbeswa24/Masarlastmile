import 'dart:math';

import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' as fw;
import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class BarcodePrintScreen extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  const BarcodePrintScreen({super.key, required this.orders});

  @override
  State<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _LabelPreset {
  final String name;
  final double pageWidthMm;
  final double pageHeightMm;
  final int columns;
  final int rows;
  // True for pre-cut sticker sheets where the die-cuts butt right up
  // against each other and against the page edge — printing with any page
  // margin or inter-label spacing drifts the grid off the real cut lines
  // as it goes down the page, which is what caused content to overlap
  // onto the next physical sticker.
  final bool zeroGap;
  const _LabelPreset(this.name, this.pageWidthMm, this.pageHeightMm, this.columns, this.rows, {this.zeroGap = false});

  int get perPage => columns * rows;
}

const _presets = [
  _LabelPreset('A4 sheet · 3×4 (12 per page)', 210, 297, 3, 4),
  _LabelPreset('A4 sheet · 2×8 (16 per page)', 210, 297, 2, 8),
  _LabelPreset('A4 sheet · 2×4 (8 per page)', 210, 297, 2, 4),
  _LabelPreset('A4 sheet · 2×2 (4 per page)', 210, 297, 2, 2),
  _LabelPreset('A4 sheet · 2×7 (14 per page)', 210, 297, 2, 7),
  // Matches a die-cut sheet of 37×105mm stickers, 2 columns x 8 rows,
  // 0 gap: 2x105=210mm fills the A4 width exactly, 8x37=296mm ≈ the
  // 297mm A4 height (within a fraction of a mm), so with zero margin and
  // zero spacing each printed cell lands exactly on its physical sticker.
  _LabelPreset('Pre-cut sticker sheet · 37×105mm, 2×8 (0 margin)', 210, 297, 2, 8, zeroGap: true),
  _LabelPreset('Shipping label 4×6 in (1 per page)', 101.6, 152.4, 1, 1),
  _LabelPreset('Sticker 3×2 in (1 per page)', 76.2, 50.8, 1, 1),
];

class _BarcodePrintScreenState extends State<BarcodePrintScreen> {
  List<Map<String, dynamic>> _labels = [];
  bool _loading = true;
  String _style = 'compact'; // 'compact' or 'detailed'
  int _presetIndex = 0;
  bool _useCustomSize = false;
  double _customWidthMm = 100;
  double _customHeightMm = 150;

  double get _mmToPt => 2.83465;

  // The current label layout, derived from whichever preset (or custom
  // size) is selected — replaces what used to be fixed A4/3-column
  // constants, since different merchants print on different paper or
  // pre-cut sticker sizes.
  _LabelPreset get _activePreset => _useCustomSize
      ? _LabelPreset('Custom', _customWidthMm, _customHeightMm, 1, 1)
      : _presets[_presetIndex];

  double get _pageWidth => _activePreset.pageWidthMm * _mmToPt;
  double get _pageHeight => _activePreset.pageHeightMm * _mmToPt;
  // Trimmed from 16pt down to 10pt for multi-label pages — most printers
  // still handle a ~3.5mm margin fine, and the space it frees up goes
  // straight into _labelSpacing below rather than into the labels
  // themselves, so there's a clearer visible gap between columns.
  double get _pageMargin {
    if (_activePreset.zeroGap) return 0;
    return _activePreset.perPage == 1 ? 6 : 10;
  }

  double get _labelSpacing => _activePreset.zeroGap ? 0 : 10;
  double get _labelWidth => (_pageWidth - (_pageMargin * 2) - (_labelSpacing * (_activePreset.columns - 1))) / _activePreset.columns;
  double get _labelHeight => (_pageHeight - (_pageMargin * 2) - (_labelSpacing * (_activePreset.rows - 1))) / _activePreset.rows;

  // The detailed/compact templates below were originally tuned with fixed
  // font sizes, paddings, and QR dimensions for the taller presets (2x4,
  // 3x4, ~199pt label height). At denser presets like 2x8 (16-per-page,
  // ~97pt tall), that fixed content no longer fits and pdf widgets
  // silently drop whatever overflows an Expanded — which is what was
  // causing the missing QR/box code and the corrupted glyph near the date.
  // This scales every size proportionally to the actual label height
  // instead, so content shrinks together rather than getting dropped.
  double get _scaleFactor {
    const referenceHeight = 199.0; // pt, height the original fixed sizes were tuned for
    return (_labelHeight / referenceHeight).clamp(0.5, 1.0);
  }

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

    // Detailed labels need the merchant's address, which isn't part of the
    // usual order list query — fetch it separately for whichever merchants
    // are actually involved here.
    final merchantIds = widget.orders.map((o) => o['merchant_id'] as String?).whereType<String>().toSet().toList();
    final Map<String, String> merchantAddresses = {};
    if (merchantIds.isNotEmpty) {
      final merchants = await supabase.from('profiles').select('id, address').inFilter('id', merchantIds);
      for (final m in merchants) {
        merchantAddresses[m['id'] as String] = (m['address'] as String?) ?? '';
      }
    }

    final boxList = List<Map<String, dynamic>>.from(boxes);
    final labels = <Map<String, dynamic>>[];

    for (final order in widget.orders) {
      final orderBoxes = boxList.where((b) => b['order_id'] == order['id']).toList();
      final total = orderBoxes.isEmpty ? 1 : orderBoxes.length;
      final merchantAddress = merchantAddresses[order['merchant_id']] ?? '';
      if (orderBoxes.isEmpty) {
        labels.add({...order, 'box_code': order['order_code'], 'box_number': 1, 'box_total': 1, 'merchant_address': merchantAddress});
      } else {
        for (final b in orderBoxes) {
          labels.add({...order, 'box_code': b['box_code'], 'box_number': b['box_number'], 'box_total': total, 'merchant_address': merchantAddress});
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
    // '--' rather than an em dash: the default PDF core font ('pdf'
    // package's base Helvetica) doesn't include the em dash glyph, so it
    // rendered as an unreadable tofu box whenever delivery_date or
    // delivery_window_end was null.
    final datePart = date ?? '--';
    final timePart = before != null && before.length >= 5 ? before.substring(0, 5) : '--';
    return '$datePart - $timePart';
  }

  // Draws a dashed rectangle the exact size of one physical die-cut cell
  // (_labelWidth x _labelHeight) — a visible cutting/alignment guide,
  // independent of whatever padding shrinks the printed content inside
  // it. Print a test sheet on plain paper and hold it against the real
  // sticker sheet: if the dashed lines land on the actual cut lines, the
  // math is right and any remaining drift is coming from the printer/
  // print-dialog scaling rather than this file.
  pw.Widget _cutGuide(double width, double height) {
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (PdfGraphics canvas, PdfPoint size) {
        canvas
          ..setColor(PdfColors.grey500)
          ..setLineWidth(0.5);

        void dashedLine(double x1, double y1, double x2, double y2) {
          const dash = 2.5, gap = 2.0;
          final dx = x2 - x1, dy = y2 - y1;
          final length = sqrt(dx * dx + dy * dy);
          if (length == 0) return;
          final ux = dx / length, uy = dy / length;
          var pos = 0.0;
          while (pos < length) {
            final segEnd = pos + dash < length ? pos + dash : length;
            canvas.moveTo(x1 + ux * pos, y1 + uy * pos);
            canvas.lineTo(x1 + ux * segEnd, y1 + uy * segEnd);
            pos += dash + gap;
          }
        }

        dashedLine(0, 0, size.x, 0);
        dashedLine(size.x, 0, size.x, size.y);
        dashedLine(size.x, size.y, 0, size.y);
        dashedLine(0, size.y, 0, 0);
        canvas.strokePath();
      },
    );
  }

  pw.Widget _buildCompactLabelPdf(
    Map<String, dynamic> label, {
    double leftPad = 9,
    double rightPad = 9,
    double topExtra = 0,
    double bottomExtra = 0,
  }) {
    final companyName = label['company']?['name'] ?? '';
    final merchantName = label['merchant']?['full_name'] ?? '';
    final consigneeName = label['consignee_name'] ?? '';
    final city = label['city'] ?? '';
    final boxCode = label['box_code'] ?? '';
    final boxNumber = label['box_number'] ?? 1;
    final boxTotal = label['box_total'] ?? 1;
    final codAmount = label['cod_amount'] ?? 0;
    final hasCod = codAmount is num && codAmount > 0;

    // Presets like 16-per-page produce short, wide cells rather than the
    // tall cells the stacked layout below was designed for — no amount of
    // shrinking makes a portrait layout fit a landscape cell well, so this
    // uses a left-QR / right-info layout instead, sized directly off the
    // real available space rather than one blanket scale factor.
    if (_labelWidth > _labelHeight) {
      // Subtracting topExtra + bottomExtra here too: those insets (added
      // for the first/last row on the zero-gap preset) eat into the same
      // vertical space the QR sizes itself against. Without this, row 1's
      // QR needed more room than was actually left after its extra top
      // inset, and pdf's layout silently dropped the QR rather than
      // erroring — this shrinks the QR by exactly the inset instead.
      final qrSize = (_labelHeight - 24 - topExtra - bottomExtra).clamp(20.0, 85.0);
      // leftPad/rightPad let the caller give less padding at the seam
      // between two columns and more at the true outer page edge —
      // topExtra/bottomExtra do the same for the top/bottom-most rows,
      // which sit right at the printer's hardware-unprintable zone.
      final content = pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(leftPad, 3 + topExtra, rightPad, 5 + bottomExtra),
        child: pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                width: qrSize + 10,
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(barcode: bc.Barcode.qrCode(), data: boxCode, width: qrSize, height: qrSize, drawText: false),
                    pw.SizedBox(height: 2),
                    pw.Text(boxCode, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5), textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Text(companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), maxLines: 1, overflow: pw.TextOverflow.clip),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              if (hasCod)
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
                                  child: pw.Text('COD $codAmount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6)),
                                )
                              else
                                pw.SizedBox(),
                              pw.Text(_fmtDateTime(label), style: const pw.TextStyle(fontSize: 6.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.Divider(height: 0.5, thickness: 0.5),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: pw.Text('FROM: $merchantName', style: const pw.TextStyle(fontSize: 6.5), maxLines: 1, overflow: pw.TextOverflow.clip),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(consigneeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), maxLines: 1, overflow: pw.TextOverflow.clip),
                        ),
                      ),
                    ),
                    pw.Divider(height: 0.5, thickness: 0.5),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Box $boxNumber/$boxTotal', style: const pw.TextStyle(fontSize: 6.5)),
                          pw.Text(city, style: const pw.TextStyle(fontSize: 6.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      // The dashed rectangle marks the exact physical die-cut boundary —
      // print this on plain paper first and hold it against the real
      // sticker sheet to confirm alignment before running actual stock.
      return _activePreset.zeroGap ? pw.Stack(children: [_cutGuide(_labelWidth, _labelHeight), content]) : content;
    }

    final s = _scaleFactor;
    final qrSize = (66.0 * s).clamp(26.0, 66.0); // never let the QR get unscannably small

    return pw.Padding(
      padding: pw.EdgeInsets.fromLTRB(3 * s, 0, 3 * s, 3 * s),
      child: pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
        child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 5 * s),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11 * s), maxLines: 1, overflow: pw.TextOverflow.clip),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (hasCod)
                      pw.Container(
                        padding: pw.EdgeInsets.symmetric(horizontal: 4 * s, vertical: 1 * s),
                        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                        child: pw.Text('COD $codAmount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: (7 * s).clamp(5.0, 7.0))),
                      )
                    else
                      pw.SizedBox(),
                    pw.Text(_fmtDateTime(label), style: pw.TextStyle(fontSize: 8 * s)),
                  ],
                ),
              ],
            ),
          ),
          pw.Divider(height: 0.5, thickness: 0.5),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 4 * s),
            child: pw.Text('FROM: $merchantName', style: pw.TextStyle(fontSize: 8 * s), maxLines: 1, overflow: pw.TextOverflow.clip),
          ),
          pw.Divider(height: 0.5, thickness: 0.5),
          pw.Expanded(
            child: pw.Center(
              child: pw.BarcodeWidget(
                barcode: bc.Barcode.qrCode(),
                data: boxCode,
                width: qrSize,
                height: qrSize,
                drawText: false,
              ),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 3 * s),
            child: pw.Center(child: pw.Text(boxCode, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: (8.5 * s).clamp(6.0, 8.5)))),
          ),
          pw.Divider(height: 0.5, thickness: 0.5),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 5 * s),
            child: pw.Text('TO: $consigneeName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9 * s), maxLines: 1, overflow: pw.TextOverflow.clip),
          ),
          pw.Divider(height: 0.5, thickness: 0.5),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 5 * s),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Box $boxNumber of $boxTotal', style: pw.TextStyle(fontSize: 8 * s)),
                pw.Text(city, style: pw.TextStyle(fontSize: 8 * s)),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  pw.Widget _buildDetailedLabelPdf(
    Map<String, dynamic> label, {
    double leftPad = 9,
    double rightPad = 9,
    double topExtra = 0,
    double bottomExtra = 0,
  }) {
    final companyName = label['company']?['name'] ?? '';
    final merchantName = label['merchant']?['full_name'] ?? '';
    final merchantAddress = label['merchant_address'] ?? '';
    final consigneeName = label['consignee_name'] ?? '';
    final consigneeAddress = label['full_address'] ?? '';
    final boxCode = label['box_code'] ?? '';
    final boxNumber = label['box_number'] ?? 1;
    final boxTotal = label['box_total'] ?? 1;
    final deliveryType = (label['delivery_type'] ?? 'standard').toString();
    final codAmount = (label['cod_amount'] ?? 0);
    final hasCod = codAmount is num && codAmount > 0;

    // Short, wide cells (e.g. 2x8 / 16-per-page) have height as the scarce
    // dimension, not width — the old header+QR-row+footer stack wasted a
    // lot of that height on two separate chrome rows and left the QR
    // capped well under what the cell could actually fit. This layout puts
    // everything in a single row so the QR can use almost the full label
    // height, and folds company/date/COD/delivery/box info around the
    // FROM/TO block instead of in their own rows, freeing enough space to
    // show the address lines too.
    if (_labelWidth > _labelHeight) {
      // Same reasoning as the compact template — account for
      // topExtra/bottomExtra so the QR shrinks instead of risking the
      // same silent-drop overflow on an edge row.
      final qrSize = (_labelHeight - 28 - topExtra - bottomExtra).clamp(26.0, 95.0);
      // Same leftPad/rightPad/topExtra/bottomExtra reasoning as the
      // compact template.
      final content = pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(leftPad, 3 + topExtra, rightPad, 5 + bottomExtra),
        child: pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                width: qrSize + 12,
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(barcode: bc.Barcode.qrCode(), data: boxCode, width: qrSize, height: qrSize, drawText: false),
                    pw.SizedBox(height: 2),
                    pw.Text(boxCode, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5), textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Text(companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), maxLines: 1, overflow: pw.TextOverflow.clip),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              if (hasCod)
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
                                  child: pw.Text('COD $codAmount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6)),
                                )
                              else
                                pw.SizedBox(),
                              pw.Text(_fmtDateTime(label), style: const pw.TextStyle(fontSize: 6.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.Divider(height: 0.5, thickness: 0.5),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('FROM: $merchantName', style: const pw.TextStyle(fontSize: 6.5), maxLines: 1, overflow: pw.TextOverflow.clip),
                            if (merchantAddress.isNotEmpty)
                              pw.Text(merchantAddress, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700), maxLines: 1, overflow: pw.TextOverflow.clip),
                          ],
                        ),
                      ),
                    ),
                    pw.Divider(height: 0.5, thickness: 0.5),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('TO: $consigneeName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), maxLines: 1, overflow: pw.TextOverflow.clip),
                            if (consigneeAddress.isNotEmpty)
                              pw.Text(consigneeAddress, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700), maxLines: 1, overflow: pw.TextOverflow.clip),
                          ],
                        ),
                      ),
                    ),
                    pw.Divider(height: 0.5, thickness: 0.5),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(deliveryType[0].toUpperCase() + deliveryType.substring(1), style: const pw.TextStyle(fontSize: 6)),
                          pw.Text('Box $boxNumber/$boxTotal', style: const pw.TextStyle(fontSize: 6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      return _activePreset.zeroGap ? pw.Stack(children: [_cutGuide(_labelWidth, _labelHeight), content]) : content;
    }

    final s = _scaleFactor;
    final qrSize = (44.0 * s).clamp(22.0, 44.0); // never let the QR get unscannably small
    final showAddress = s > 0.7; // only tall enough presets can afford the extra address lines

    return pw.Padding(
      padding: pw.EdgeInsets.fromLTRB(3 * s, 0, 3 * s, 3 * s),
      child: pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 4 * s),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text(companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10 * s), maxLines: 1, overflow: pw.TextOverflow.clip)),
                  if (hasCod)
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(horizontal: 4 * s, vertical: 1 * s),
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                      child: pw.Text('COD $codAmount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: (7 * s).clamp(5.0, 7.0))),
                    ),
                ],
              ),
            ),
            pw.Divider(height: 0.5, thickness: 0.5),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Left: QR + tracking code
                  pw.Container(
                    width: qrSize + 10,
                    padding: pw.EdgeInsets.all(4 * s),
                    decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.BarcodeWidget(barcode: bc.Barcode.qrCode(), data: boxCode, width: qrSize, height: qrSize, drawText: false),
                        pw.SizedBox(height: 3 * s),
                        pw.Text(boxCode, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: (6.5 * s).clamp(5.0, 6.5)), textAlign: pw.TextAlign.center),
                      ],
                    ),
                  ),
                  // Right: FROM / TO blocks
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                          child: pw.Padding(
                            padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 3 * s),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text('FROM', style: pw.TextStyle(fontSize: (6 * s).clamp(4.5, 6.0), color: PdfColors.grey600)),
                                pw.Text(merchantName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: (8 * s).clamp(5.5, 8.0)), maxLines: 1, overflow: pw.TextOverflow.clip),
                                if (merchantAddress.isNotEmpty && showAddress)
                                  pw.Text(merchantAddress, style: pw.TextStyle(fontSize: 6.5 * s), maxLines: 1, overflow: pw.TextOverflow.clip),
                              ],
                            ),
                          ),
                        ),
                        pw.Divider(height: 0.5, thickness: 0.5),
                        pw.Expanded(
                          child: pw.Padding(
                            padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 3 * s),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text('TO', style: pw.TextStyle(fontSize: (6 * s).clamp(4.5, 6.0), color: PdfColors.grey600)),
                                pw.Text(consigneeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: (8.5 * s).clamp(6.0, 8.5)), maxLines: 1, overflow: pw.TextOverflow.clip),
                                if (consigneeAddress.isNotEmpty && showAddress)
                                  pw.Text(consigneeAddress, style: pw.TextStyle(fontSize: 6.5 * s), maxLines: 1, overflow: pw.TextOverflow.clip),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.Divider(height: 0.5, thickness: 0.5),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 6 * s, vertical: 4 * s),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Delivery', style: pw.TextStyle(fontSize: (6.5 * s).clamp(5.0, 6.5))),
                  pw.Text(deliveryType[0].toUpperCase() + deliveryType.substring(1), style: pw.TextStyle(fontSize: (6.5 * s).clamp(5.0, 6.5))),
                  pw.Text('Box $boxNumber/$boxTotal', style: pw.TextStyle(fontSize: (6.5 * s).clamp(5.0, 6.5))),
                  pw.Text(_fmtDateTime(label), style: pw.TextStyle(fontSize: (6.5 * s).clamp(5.0, 6.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printLabels() async {
    final doc = pw.Document();
    final buildLabel = _style == 'detailed' ? _buildDetailedLabelPdf : _buildCompactLabelPdf;
    final preset = _activePreset;
    final perPage = preset.perPage;
    final pageFormat = PdfPageFormat(_pageWidth, _pageHeight);

    for (var i = 0; i < _labels.length; i += perPage) {
      final pageLabels = _labels.skip(i).take(perPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(_pageMargin),
          build: (context) {
            if (perPage == 1) {
              // Single label per page (shipping labels / individually-fed
              // stickers) — no grid needed, just the one label filling the page.
              return buildLabel(pageLabels.first);
            }
            // Three separate safeguards on this grid:
            // 1. pw.GridView sizes each row by dividing the page's available
            //    height across however many rows are actually present in its
            //    children — not by the preset's fixed row count. So a partial
            //    last page (e.g. 12 labels left on a 16-per-page/2x8 preset)
            //    would get taller rows, enlarging every label on that page.
            //    Padding to a full `perPage` set of cells with invisible
            //    placeholders keeps row count — and label size — identical
            //    on every page, including the last.
            // 2. pw.Container doesn't clip its own children by default, so
            //    content still too wide for its cell (a long merchant name,
            //    an unusually long COD amount) paints straight through the
            //    cell border into the neighboring column instead of
            //    disappearing — this caused header text to visibly bleed
            //    into the next label. ClipRect makes overflow invisible
            //    instead, as a backstop on top of the header layout fix.
            // 3. On the zero-gap sticker preset, only cells touching a true
            //    page edge need extra inset — the center seam between the
            //    two columns had more padding than it needed, and only the
            //    first/last row sits in the printer's hardware-unprintable
            //    zone. This rebalances padding per cell instead of adding
            //    a blanket margin that would very slightly shrink every
            //    row and risk misaligning the rows that already print fine.
            final cells = List<pw.Widget>.generate(
              perPage,
              (idx) {
                if (idx >= pageLabels.length) return pw.SizedBox();
                final rowIndex = idx ~/ preset.columns;
                final colIndex = idx % preset.columns;
                final isFirstRow = rowIndex == 0;
                final isLastRow = rowIndex == preset.rows - 1;
                final isLeftmostCol = colIndex == 0;
                final isRightmostCol = colIndex == preset.columns - 1;

                final leftPad = preset.zeroGap ? (isLeftmostCol ? 12.0 : 4.0) : 9.0;
                final rightPad = preset.zeroGap ? (isRightmostCol ? 12.0 : 4.0) : 9.0;
                final topExtra = preset.zeroGap && isFirstRow ? 11.0 : 0.0;
                final bottomExtra = preset.zeroGap && isLastRow ? 11.0 : 0.0;

                final widget = _style == 'detailed'
                    ? _buildDetailedLabelPdf(pageLabels[idx], leftPad: leftPad, rightPad: rightPad, topExtra: topExtra, bottomExtra: bottomExtra)
                    : _buildCompactLabelPdf(pageLabels[idx], leftPad: leftPad, rightPad: rightPad, topExtra: topExtra, bottomExtra: bottomExtra);
                return pw.ClipRect(child: widget);
              },
            );
            return pw.GridView(
              crossAxisCount: preset.columns,
              childAspectRatio: _labelWidth / _labelHeight,
              children: cells,
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  Widget _compactPreview(Map<String, dynamic> label) {
    final companyName = label['company']?['name'] ?? '';
    final merchantName = label['merchant']?['full_name'] ?? '';
    final consigneeName = label['consignee_name'] ?? '';
    final city = label['city'] ?? '';
    final boxCode = label['box_code'] ?? '';
    final boxNumber = label['box_number'] ?? 1;
    final boxTotal = label['box_total'] ?? 1;
    final codAmount = label['cod_amount'] ?? 0;
    final hasCod = codAmount is num && codAmount > 0;

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
                Row(
                  children: [
                    if (hasCod)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: Colors.black45), borderRadius: BorderRadius.circular(4)),
                          child: Text('COD $codAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                    Text(_fmtDateTime(label), style: const TextStyle(fontSize: 10)),
                  ],
                ),
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
  }

  Widget _detailedPreview(Map<String, dynamic> label) {
    final companyName = label['company']?['name'] ?? '';
    final merchantName = label['merchant']?['full_name'] ?? '';
    final merchantAddress = label['merchant_address'] ?? '';
    final consigneeName = label['consignee_name'] ?? '';
    final consigneeAddress = label['full_address'] ?? '';
    final boxCode = label['box_code'] ?? '';
    final boxNumber = label['box_number'] ?? 1;
    final boxTotal = label['box_total'] ?? 1;
    final deliveryType = (label['delivery_type'] ?? 'standard').toString();
    final codAmount = label['cod_amount'] ?? 0;
    final hasCod = codAmount is num && codAmount > 0;

    return Container(
      width: 260,
      decoration: BoxDecoration(border: Border.all(color: Colors.black54), borderRadius: BorderRadius.circular(4)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                if (hasCod)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black45), borderRadius: BorderRadius.circular(4)),
                    child: Text('COD $codAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 84,
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black26))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      fw.BarcodeWidget(barcode: fw.Barcode.qrCode(), data: boxCode, width: 64, height: 64, drawText: false),
                      const SizedBox(height: 4),
                      Text(boxCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 9), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FROM', style: TextStyle(fontSize: 9, color: Colors.black45)),
                            Text(merchantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
                            if (merchantAddress.isNotEmpty)
                              Text(merchantAddress, style: const TextStyle(fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TO', style: TextStyle(fontSize: 9, color: Colors.black45)),
                            Text(consigneeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                            if (consigneeAddress.isNotEmpty)
                              Text(consigneeAddress, style: const TextStyle(fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(deliveryType[0].toUpperCase() + deliveryType.substring(1), style: const TextStyle(fontSize: 9)),
                Text('Box $boxNumber/$boxTotal', style: const TextStyle(fontSize: 9)),
                Text(_fmtDateTime(label), style: const TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLayoutDialog() async {
    int tempPreset = _presetIndex;
    bool tempCustom = _useCustomSize;
    final widthController = TextEditingController(text: _customWidthMm.toStringAsFixed(0));
    final heightController = TextEditingController(text: _customHeightMm.toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Paper & Label Size'),
              content: SizedBox(
                width: 340,
                child: RadioGroup<int>(
                  groupValue: tempCustom ? -1 : tempPreset,
                  onChanged: (v) => setDialogState(() {
                    if (v == -1) {
                      tempCustom = true;
                    } else {
                      tempPreset = v!;
                      tempCustom = false;
                    }
                  }),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._presets.asMap().entries.map((entry) {
                        return RadioListTile<int>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name, style: const TextStyle(fontSize: 14)),
                          value: entry.key,
                        );
                      }),
                      const RadioListTile<int>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Custom size (mm)', style: TextStyle(fontSize: 14)),
                        value: -1,
                      ),
                      if (tempCustom)
                        Padding(
                          padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: widthController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Width (mm)', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: heightController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Height (mm)', isDense: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                    if (tempCustom)
                      const Padding(
                        padding: EdgeInsets.only(left: 32, top: 4),
                        child: Text('One label per page — for pre-cut stickers fed individually.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ),
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _presetIndex = tempPreset;
                      _useCustomSize = tempCustom;
                      if (tempCustom) {
                        _customWidthMm = double.tryParse(widthController.text) ?? _customWidthMm;
                        _customHeightMm = double.tryParse(heightController.text) ?? _customHeightMm;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Labels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_square),
            tooltip: 'Paper & Label Size',
            onPressed: _loading ? null : _openLayoutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: _loading ? null : _printLabels,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Text('Label style:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'compact', label: Text('Compact')),
                          ButtonSegment(value: 'detailed', label: Text('Detailed')),
                        ],
                        selected: {_style},
                        onSelectionChanged: (s) => setState(() => _style = s.first),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.crop_square, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _useCustomSize
                              ? 'Custom · ${_customWidthMm.toStringAsFixed(0)}×${_customHeightMm.toStringAsFixed(0)} mm'
                              : _presets[_presetIndex].name,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(onPressed: _openLayoutDialog, child: const Text('Change')),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _labels.map((label) => _style == 'detailed' ? _detailedPreview(label) : _compactPreview(label)).toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}