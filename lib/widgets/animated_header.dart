import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/qatar_time.dart';

bool _reduceMotion(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

// ───────────────────────── Live pill (pulsing dot) ─────────────────────────
class LivePill extends StatefulWidget {
  const LivePill({super.key});
  @override
  State<LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<LivePill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !_reduceMotion(context)) {
      _c.repeat();
      _started = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x2234D399),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x5534D399)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 14, height: 14,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _PulsePainter(_c.value)),
          ),
        ),
        const SizedBox(width: 5),
        const Text('LIVE', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ]),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double t;
  _PulsePainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final ring = Paint()..color = const Color(0xFF34D399).withValues(alpha: (1 - t) * 0.55);
    canvas.drawCircle(c, 3 + t * 4, ring);
    canvas.drawCircle(c, 3, Paint()..color = const Color(0xFF34D399));
  }

  @override
  bool shouldRepaint(_PulsePainter o) => o.t != t;
}

// ───────────────────────── Count-up number ─────────────────────────
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const CountUp({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final d = _reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 700);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: d,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(v.round().toString(), style: style),
    );
  }
}

// ───────────────────────── Nav tab with sliding underline ─────────────────────────
class HeaderTab extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool brand;
  const HeaderTab({super.key, required this.label, required this.active, required this.onTap, this.brand = false});
  @override
  State<HeaderTab> createState() => _HeaderTabState();
}

class _HeaderTabState extends State<HeaderTab> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final d = _reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 220);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedDefaultTextStyle(
              duration: d,
              style: TextStyle(
                color: widget.active ? Colors.white : (_hover ? Colors.white : Colors.white60),
                fontWeight: widget.active || widget.brand ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
              child: Text(widget.label),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: d,
              curve: Curves.easeOutCubic,
              height: 2,
              width: widget.active ? 22 : (_hover ? 10 : 0),
              decoration: BoxDecoration(color: const Color(0xFF54A8EE), borderRadius: BorderRadius.circular(2)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Icon button with hover lift ─────────────────────────
class HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  const HoverIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});
  @override
  State<HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<HoverIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final d = _reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 150);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        duration: d,
        offset: _hover ? const Offset(0, -0.08) : Offset.zero,
        child: IconButton(
          icon: Icon(widget.icon, color: _hover ? Colors.white : Colors.white70),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

// ───────────────────────── Refresh button: spins on tap ─────────────────────────
class SpinRefreshButton extends StatefulWidget {
  final VoidCallback onPressed;
  const SpinRefreshButton({super.key, required this.onPressed});
  @override
  State<SpinRefreshButton> createState() => _SpinRefreshButtonState();
}

class _SpinRefreshButtonState extends State<SpinRefreshButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Refresh',
      icon: RotationTransition(turns: CurvedAnimation(parent: _c, curve: Curves.easeInOut), child: const Icon(Icons.refresh, color: Colors.white70)),
      onPressed: () {
        if (!_reduceMotion(context)) _c.forward(from: 0);
        widget.onPressed();
      },
    );
  }
}

// ───────────────────────── Logo tile ─────────────────────────
class HeaderLogo extends StatelessWidget {
  const HeaderLogo({super.key});
  @override
  Widget build(BuildContext context) {
    final d = _reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 600);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.85 + 0.15 * v, child: child)),
      child: Container(
        width: 32, height: 32,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      ),
    );
  }
}

// ───────────────────────── KPI strip (live from Supabase) ─────────────────────────
class _Kpi {
  int total = 0, hub = 0, transit = 0, delivered = 0, exceptions = 0;
  // cumulative stage reach for the merchant tracker
  int reachedPicked = 0, reachedHub = 0, reachedOfd = 0;
}

const _rank = {'pending': 0, 'picked_up': 1, 'sorted': 2, 'assigned': 2, 'out_for_delivery': 3, 'delivered': 4};

class HeaderKpiStrip extends StatefulWidget {
  /// Merchant variant shows a 4-step progress track instead of the truck route.
  final bool merchant;
  /// Bump this number to force a reload (e.g. when the user hits refresh).
  final int refreshTick;
  const HeaderKpiStrip({super.key, this.merchant = false, this.refreshTick = 0});
  @override
  State<HeaderKpiStrip> createState() => _HeaderKpiStripState();
}

class _HeaderKpiStripState extends State<HeaderKpiStrip> with SingleTickerProviderStateMixin {
  _Kpi _k = _Kpi();
  bool _loaded = false;
  Timer? _timer;
  late final AnimationController _truck = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  bool _anim = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_anim && !_reduceMotion(context)) {
      _truck.repeat();
      _anim = true;
    }
  }

  @override
  void didUpdateWidget(HeaderKpiStrip old) {
    super.didUpdateWidget(old);
    if (old.refreshTick != widget.refreshTick) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _truck.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final n = QatarTime.now();
      final today = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
      final rows = await supabase.from('orders').select('status').eq('delivery_date', today).timeout(const Duration(seconds: 15));
      final k = _Kpi();
      for (final r in rows as List) {
        final s = r['status'] as String? ?? 'pending';
        if (s == 'cancelled') continue;
        k.total++;
        if (s == 'sorted') k.hub++;
        if (s == 'out_for_delivery') k.transit++;
        if (s == 'delivered') k.delivered++;
        if (s == 'failed' || s == 'rescheduled' || s == 'returned_to_shipper') k.exceptions++;
        final rk = _rank[s];
        if (rk != null) {
          if (rk >= 1) k.reachedPicked++;
          if (rk >= 2) k.reachedHub++;
          if (rk >= 3) k.reachedOfd++;
        }
      }
      if (mounted) setState(() { _k = k; _loaded = true; });
    } catch (_) {
      // Header stats are decorative; never block the screen on them.
    }
  }

  Widget _tile(String label, int v, Color dot) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 2),
        _loaded
            ? CountUp(key: ValueKey('$label$v'), value: v, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))
            : const Text('–', style: TextStyle(color: Colors.white38, fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = _k.total == 0 ? 0.0 : _k.delivered / _k.total;
    return Container(
      color: const Color(0xFF173A66),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _tile("Today's orders", _k.total, const Color(0xFF54A8EE)),
          _tile('Hub Arrived', _k.hub, const Color(0xFFA78BFA)),
          _tile('Out for delivery', _k.transit, const Color(0xFFFBBF24)),
          _tile('Delivered', _k.delivered, const Color(0xFF34D399)),
          _tile('Exceptions', _k.exceptions, const Color(0xFFF87171)),
          const SizedBox(width: 6),
          widget.merchant ? _stepTrack() : _truckRoute(pct),
        ]),
      ),
    );
  }

  // Dispatcher: a small truck driving along a route; progress = delivered share.
  Widget _truckRoute(double pct) {
    return SizedBox(
      width: 220, height: 34,
      child: AnimatedBuilder(
        animation: _truck,
        builder: (_, __) => CustomPaint(painter: _RoutePainter(_anim ? _truck.value : 0.5, pct)),
      ),
    );
  }

  // Merchant: Picked up → Hub Arrived → Out for delivery → Delivered
  Widget _stepTrack() {
    final t = _k.total;
    final steps = [
      ('Picked up', _k.reachedPicked),
      ('Hub Arrived', _k.reachedHub),
      ('Out for delivery', _k.reachedOfd),
      ('Delivered', _k.delivered),
    ];
    final d = _reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 800);
    return SizedBox(
      width: 330,
      child: Row(children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: t == 0 ? 0 : steps[i].$2 / t),
                duration: d,
                curve: Curves.easeOutCubic,
                builder: (_, f, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: f, minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF54A8EE)),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(steps[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9)),
            ]),
          ),
          if (i < steps.length - 1) const SizedBox(width: 6),
        ],
      ]),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final double t; // truck loop 0..1
  final double done; // delivered share 0..1
  _RoutePainter(this.t, this.done);

  @override
  void paint(Canvas canvas, Size s) {
    final y = s.height * 0.62;
    final path = Path()
      ..moveTo(2, y)
      ..cubicTo(s.width * 0.25, y - 14, s.width * 0.45, y + 12, s.width * 0.65, y - 4)
      ..cubicTo(s.width * 0.8, y - 14, s.width * 0.9, y, s.width - 4, y - 6);
    final base = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawPath(path, base);
    final m = path.computeMetrics().first;
    final prog = Paint()..color = const Color(0xFF54A8EE)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    canvas.drawPath(m.extractPath(0, m.length * done.clamp(0.02, 1.0)), prog);
    // stops
    for (final f in [0.0, 0.33, 0.66, 1.0]) {
      final p = m.getTangentForOffset(m.length * f)!.position;
      canvas.drawCircle(p, 3, Paint()..color = f <= done ? const Color(0xFF34D399) : Colors.white38);
    }
    // truck
    final tan = m.getTangentForOffset(m.length * t)!;
    canvas.save();
    canvas.translate(tan.position.dx, tan.position.dy - 5);
    final body = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -4, 10, 7), const Radius.circular(1.5)), body);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, -2, 5, 5), const Radius.circular(1.5)), Paint()..color = const Color(0xFF54A8EE));
    canvas.drawCircle(const Offset(-4, 4), 1.6, Paint()..color = const Color(0xFF0F2744));
    canvas.drawCircle(const Offset(5, 4), 1.6, Paint()..color = const Color(0xFF0F2744));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoutePainter o) => o.t != t || o.done != done;
}

// ───────────────────────── Thin sweep bar shown while loading ─────────────────────────
class HeaderProgressSweep extends StatefulWidget {
  final bool active;
  const HeaderProgressSweep({super.key, required this.active});
  @override
  State<HeaderProgressSweep> createState() => _HeaderProgressSweepState();
}

class _HeaderProgressSweepState extends State<HeaderProgressSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didUpdateWidget(HeaderProgressSweep old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating && !_reduceMotion(context)) {
      _c.repeat();
    } else if (!widget.active) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: widget.active
          ? AnimatedBuilder(
              animation: _c,
              builder: (_, __) => LayoutBuilder(builder: (_, box) {
                final w = box.maxWidth * 0.3;
                final x = (box.maxWidth + w) * _c.value - w;
                return Stack(children: [
                  Positioned(left: x, width: w, top: 0, bottom: 0, child: const ColoredBox(color: Color(0xFF54A8EE))),
                ]);
              }),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Convenience: Essence brand lockup used on the left of both headers.
class HeaderBrand extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  const HeaderBrand({super.key, required this.name, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const HeaderLogo(),
        const SizedBox(width: 10),
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
        const SizedBox(width: 10),
        const LivePill(),
      ]),
    );
  }
}
