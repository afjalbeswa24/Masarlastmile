import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'qatar_outline.dart';

// ---------------------------------------------------------------------------
// Login-panel animation: a Qatar outline with a hub on the west side. Fifteen
// vans leave together, each covering one area with several stops on straight
// routes, until every order is delivered; then the map fades and runs again
// with a new random order total (always above 1,200).
// ---------------------------------------------------------------------------

const _gold = Color(0xFFD9AF61);
const _pearl = Color(0xFFF3ECDD);
const _green = Color(0xFF5FD6A0);
const _navy2 = Color(0xFF0C2A4A);

const _vanCount = 15;
const _speed = 0.07; // map-heights per second
const _dwell = 0.55; // seconds at each stop
const _loopPad = 4.5; // seconds between runs

class _Stop {
  final double x, y;
  int orders = 0;
  double arr = 0;
  _Stop(this.x, this.y);
}

class _VanRun {
  final List<Offset> route;
  final List<_Stop> stops;
  final double dep;
  final double fin;
  final List<double> arr;
  _VanRun(this.route, this.stops, this.dep, this.fin, this.arr);
}

class _DispatchModel {
  final Size size;
  late final Rect mapRect;
  late final List<Offset> poly;
  late final Offset hub;
  final List<_VanRun> vans = [];
  double end = 1;
  int total = 1;

  _DispatchModel(this.size) {
    final w = size.width, h = size.height;
    final mh = h * 0.86;
    final mw = mh * 282 / 568;
    final mx = w * 0.62 - mw / 2;
    final my = h * 0.07;
    mapRect = Rect.fromLTWH(mx, my, mw, mh);
    poly = [for (final p in kQatarOutline) Offset(mx + p[0] * mw, my + p[1] * mh)];
    hub = Offset(mx + 0.37 * mw, my + 0.606 * mh);

    final rnd = Random(11);
    final minD = max(9.0, mh * 0.032);
    final pts = <Offset>[];
    for (var k = 0; k < 9000 && pts.length < 115; k++) {
      final x = mx + rnd.nextDouble() * mw;
      final y = my + rnd.nextDouble() * mh;
      if (!_inside(poly, x, y) || _edgeDist(poly, x, y) < 6) continue;
      if ((Offset(x, y) - hub).distance < minD * 1.6) continue;
      if (pts.any((c) => (c - Offset(x, y)).distance < minD)) continue;
      pts.add(Offset(x, y));
    }
    if (pts.length < _vanCount) return;

    // k-means into one zone per van (farthest-point start).
    final cen = <Offset>[pts.first];
    while (cen.length < _vanCount) {
      Offset best = pts.first;
      double bd = -1;
      for (final p in pts) {
        final dd = cen.map((c) => (c - p).distance).reduce(min);
        if (dd > bd) {
          bd = dd;
          best = p;
        }
      }
      cen.add(best);
    }
    var asg = List<int>.filled(pts.length, 0);
    for (var it = 0; it < 14; it++) {
      asg = pts.map((p) {
        var bi = 0;
        double bd = double.infinity;
        for (var i = 0; i < cen.length; i++) {
          final dd = (cen[i] - p).distance;
          if (dd < bd) {
            bd = dd;
            bi = i;
          }
        }
        return bi;
      }).toList();
      for (var i = 0; i < cen.length; i++) {
        double sx = 0, sy = 0;
        var n = 0;
        for (var k = 0; k < pts.length; k++) {
          if (asg[k] == i) {
            sx += pts[k].dx;
            sy += pts[k].dy;
            n++;
          }
        }
        if (n > 0) cen[i] = Offset(sx / n, sy / n);
      }
    }

    for (var vi = 0; vi < cen.length; vi++) {
      final left = <Offset>[
        for (var k = 0; k < pts.length; k++)
          if (asg[k] == vi) pts[k]
      ];
      if (left.isEmpty) continue;
      final route = <Offset>[hub];
      final stops = <_Stop>[];
      var cur = hub;
      while (left.isNotEmpty) {
        left.sort((p, q) => (p - cur).distance.compareTo((q - cur).distance));
        var pick = -1;
        for (var i = 0; i < left.length; i++) {
          final p = left[i];
          var ok = true;
          for (var s = 1; s <= 10; s++) {
            if (!_inside(poly, cur.dx + (p.dx - cur.dx) * s / 10, cur.dy + (p.dy - cur.dy) * s / 10)) {
              ok = false;
              break;
            }
          }
          if (ok) {
            pick = i;
            break;
          }
        }
        if (pick < 0) {
          left.removeAt(0);
          continue;
        }
        final p = left.removeAt(pick);
        route.add(p);
        cur = p;
        stops.add(_Stop(p.dx, p.dy));
      }
      if (stops.isEmpty) continue;
      final dep = 2.0 + vi * 0.12;
      var t = dep;
      final arr = <double>[];
      for (var i = 0; i < stops.length; i++) {
        t += (route[i + 1] - route[i]).distance / (h * _speed);
        arr.add(t);
        stops[i].arr = t;
        t += _dwell;
      }
      vans.add(_VanRun(route, stops, dep, t - _dwell, arr));
      end = max(end, t);
    }
    reroll(Random());
  }

  /// New random order counts for every run; the total is always above 1,200.
  void reroll(Random rnd) {
    final all = [for (final v in vans) ...v.stops];
    if (all.isEmpty) {
      total = 1;
      return;
    }
    for (final s in all) {
      s.orders = 6 + rnd.nextInt(12);
    }
    final target = 1210 + rnd.nextInt(620);
    final raw = all.fold<int>(0, (q, s) => q + s.orders);
    final f = target / raw;
    for (final s in all) {
      s.orders = max(1, (s.orders * f).round());
    }
    var tot = all.fold<int>(0, (q, s) => q + s.orders);
    var i = 0;
    while (tot != target && i < 5000) {
      final s = all[i % all.length];
      if (tot < target) {
        s.orders++;
        tot++;
      } else if (s.orders > 1) {
        s.orders--;
        tot--;
      }
      i++;
    }
    total = tot;
  }

  static bool _inside(List<Offset> poly, double x, double y) {
    var c = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > y) != (b.dy > y) && x < (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy) + a.dx) c = !c;
    }
    return c;
  }

  static double _edgeDist(List<Offset> poly, double x, double y) {
    var m = double.infinity;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (((x - a.dx) * dx + (y - a.dy) * dy) / len2).clamp(0.0, 1.0);
      m = min(m, sqrt(pow(x - a.dx - t * dx, 2) + pow(y - a.dy - t * dy, 2)));
    }
    return m;
  }
}

class DispatchMap extends StatefulWidget {
  const DispatchMap({super.key});

  @override
  State<DispatchMap> createState() => _DispatchMapState();
}

class _DispatchMapState extends State<DispatchMap> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  final Random _rnd = Random();
  _DispatchModel? _model;
  Size? _modelSize;
  int _cycle = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final m = _model;
      if (m != null) {
        final cyc = (d.inMicroseconds / 1e6 / (m.end + _loopPad)).floor();
        if (cyc != _cycle) {
          _cycle = cyc;
          m.reroll(_rnd);
        }
      }
      _time.value = d.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    _ticker.muted = reduce;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        if (size.isEmpty) return const SizedBox.shrink();
        if (_modelSize != size) {
          _modelSize = size;
          _model = _DispatchModel(size);
        }
        return RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: _DispatchPainter(_model!, _time, reduce),
          ),
        );
      },
    );
  }
}

class _DispatchPainter extends CustomPainter {
  final _DispatchModel m;
  final ValueNotifier<double> time;
  final bool still;
  _DispatchPainter(this.m, this.time, this.still) : super(repaint: time);

  @override
  bool shouldRepaint(covariant _DispatchPainter old) => old.m != m || old.still != still;

  void _label(Canvas c, String text, Offset at, TextAlign align, Color col, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style.copyWith(color: col)), textDirection: TextDirection.ltr)..layout();
    final dx = align == TextAlign.center ? at.dx - tp.width / 2 : (align == TextAlign.right ? at.dx - tp.width : at.dx);
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _van(Canvas c, Offset p, double a, double al) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(a);
    final glow = Paint()
      ..shader = ui.Gradient.radial(Offset.zero, 13, [_gold.withValues(alpha: 0.5 * al), _gold.withValues(alpha: 0)]);
    c.drawRect(const Rect.fromLTWH(-13, -13, 26, 26), glow);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -3.6, 12, 7.2), const Radius.circular(2.2)), Paint()..color = _pearl.withValues(alpha: al));
    c.drawRect(const Rect.fromLTWH(-6, -3.6, 3.5, 7.2), Paint()..color = _gold.withValues(alpha: al));
    c.drawRect(const Rect.fromLTWH(2.5, -2.6, 2.6, 5.2), Paint()..color = const Color(0xFF0B1F33).withValues(alpha: al));
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (m.vans.isEmpty) return;
    final end = m.end;
    final loop = end + _loopPad;
    final t = still ? end + 0.5 : time.value % loop;
    final fade = t > end + 2.2 ? (1 - ((t - end - 2.2) / (loop - end - 2.2))).clamp(0.0, 1.0) : 1.0;
    final w = size.width, h = size.height;

    canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, fade));

    // Qatar: fill, dot grid, glowing outline.
    final path = Path()..addPolygon(m.poly, true);
    canvas.drawPath(path, Paint()..color = _navy2.withValues(alpha: 0.55));
    canvas.save();
    canvas.clipPath(path);
    final gs = max(11.0, m.mapRect.height / 42);
    final dot = Paint()..color = const Color(0xFF9FC3E6).withValues(alpha: 0.22);
    for (var x = m.mapRect.left; x < m.mapRect.right; x += gs) {
      for (var y = m.mapRect.top; y < m.mapRect.bottom; y += gs) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1.4, 1.4), dot);
      }
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF78BEFF).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFAAD2F5).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );

    var delivered = 0;
    for (final v in m.vans) {
      for (final s in v.stops) {
        final done = t >= s.arr;
        if (done) delivered += s.orders;
        canvas.drawCircle(Offset(s.x, s.y), done ? 3.2 : 2.3, Paint()..color = done ? _green : Colors.white.withValues(alpha: 0.4));
        if (done && t - s.arr < 0.8) {
          final q = (t - s.arr) / 0.8;
          canvas.drawCircle(
            Offset(s.x, s.y),
            3 + q * 14,
            Paint()
              ..color = _green.withValues(alpha: (1 - q) * 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }
      }
      if (t < v.dep) continue;
      var pos = v.route.first;
      var ang = 0.0;
      for (var i = 0; i < v.stops.length; i++) {
        final a = v.route[i], b = v.route[i + 1];
        final t0 = i == 0 ? v.dep : v.arr[i - 1] + _dwell;
        final t1 = v.arr[i];
        if (t < t0) break;
        final k = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
        final e = Offset(a.dx + (b.dx - a.dx) * k, a.dy + (b.dy - a.dy) * k);
        canvas.drawLine(
          a,
          e,
          Paint()
            ..color = _gold.withValues(alpha: k < 1 ? 0.7 : 0.2)
            ..strokeWidth = k < 1 ? 1.6 : 1,
        );
        pos = e;
        ang = atan2(b.dy - a.dy, b.dx - a.dx);
      }
      final fin = t > v.fin + 0.4;
      _van(canvas, pos, ang, fin ? (1 - (t - v.fin - 0.4) / 0.8).clamp(0.0, 1.0) : 1.0);
    }

    // Hub.
    final pu = (t % 2) / 2;
    canvas.drawCircle(
      m.hub,
      8 + pu * 28,
      Paint()
        ..color = _gold.withValues(alpha: (1 - pu) * 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(m.hub, 11, Paint()..color = _navy2.withValues(alpha: 0.95));
    canvas.drawCircle(m.hub, 7, Paint()..color = _pearl);
    canvas.drawCircle(
      m.hub,
      7,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final fs = (w / 60).clamp(9.0, 11.5);
    _label(canvas, 'HUB', m.hub + const Offset(0, 26), TextAlign.center, Colors.white, TextStyle(fontFamily: 'JetBrainsMono', fontSize: fs, fontWeight: FontWeight.w700));

    // Counters (left).
    final sx = w * 0.04, sy = h * 0.16, gap = h * 0.19;
    final bs = (w / 22).clamp(18.0, 28.0);
    final loaded = t >= 2.0 ? m.total - delivered : 0;
    final rows = <(String, int, Color)>[
      ('PICKED UP', t > 0.3 ? m.total : 0, _gold),
      ('HUB ARRIVED', t > 1.0 ? m.total : 0, _gold),
      ('OUT FOR DELIVERY', loaded, _gold),
      ('DELIVERED', delivered, _green),
    ];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final y = sy + i * gap;
      canvas.drawRect(Rect.fromLTWH(sx, y - bs * 0.5, 3, bs * 1.15), Paint()..color = r.$3);
      _label(canvas, r.$1, Offset(sx + 12, y - bs * 0.28), TextAlign.left, Colors.white.withValues(alpha: 0.75), TextStyle(fontFamily: 'JetBrainsMono', fontSize: fs, fontWeight: FontWeight.w700));
      _label(canvas, _fmt(r.$2), Offset(sx + 12, y + bs * 0.38), TextAlign.left, Colors.white, TextStyle(fontFamily: 'SpaceGrotesk', fontSize: bs, fontWeight: FontWeight.w700));
    }
    final bw = w * 0.26, by = sy + 4 * gap - gap * 0.3;
    canvas.drawRect(Rect.fromLTWH(sx, by, bw, 3), Paint()..color = Colors.white.withValues(alpha: 0.16));
    canvas.drawRect(Rect.fromLTWH(sx, by, bw * (m.total == 0 ? 0 : delivered / m.total), 3), Paint()..color = _green);

    canvas.restore();
  }
}
