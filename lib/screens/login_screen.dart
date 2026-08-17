import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

// ---------------------------------------------------------------------------
// Self-contained palette for this screen. Doesn't depend on AppTheme so it
// drops in cleanly — fold these into your shared theme later if you want.
// Inspired by the MASAR app icon's teal gradient, Doha's night skyline, and
// Qatar's pearl-diving heritage (the signature route below is a pearl strand,
// not a generic dotted line).
// ---------------------------------------------------------------------------
class _Palette {
  static const nightTeal = Color(0xFF071E1B);
  static const deepTeal = Color(0xFF0B322C);
  static const brandTeal = Color(0xFF12A187);
  static const brandTealLight = Color(0xFF3FD9B4);
  static const gold = Color(0xFFD9AF61);
  static const pearl = Color(0xFFF3ECDD);
  static const ink = Color(0xFF0B322C);
  static const textSecondary = Color(0xFF6B7A76);
  static const border = Color(0xFFDFE3E0);
  static const fieldBg = Color(0xFFFBFCFB);
  static const danger = Color(0xFFD64545);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;

  // Drives the van along the pearl-strand route.
  late final AnimationController _routeController;

  @override
  void initState() {
    super.initState();
    _routeController = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  }

  @override
  void dispose() {
    _routeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(String label, {required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: _Palette.fieldBg,
      prefixIcon: Icon(icon, size: 18, color: _Palette.textSecondary),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _Palette.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _Palette.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _Palette.brandTeal, width: 1.5)),
    );
  }

  // ---------------------------------------------------------------------
  // Brand panel (wide layout, left side)
  // ---------------------------------------------------------------------

  Widget _brandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.7, -1),
          radius: 1.6,
          colors: [_Palette.deepTeal, _Palette.nightTeal, Color(0xFF04120F)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 44, 40, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESSENCE',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 38, height: 1.02, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white),
                ),
                const Text(
                  'EXPRESS',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 38, height: 1.02, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('LAST-MILE LOGISTICS', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, letterSpacing: 1.6, color: Colors.white.withValues(alpha: 0.55))),
                    const SizedBox(width: 10),
                    _flagChip(),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Every delivery is a pearl on the route.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 21, fontWeight: FontWeight.w700, height: 1.28, color: Colors.white.withValues(alpha: 0.95)),
                ),

                // -- Doha skyline + animated pearl-strand route ------------
                Expanded(
                  flex: 3,
                  child: AnimatedBuilder(
                    animation: _routeController,
                    builder: (context, _) => CustomPaint(painter: _SkylineRoutePainter(_routeController.value), size: Size.infinite),
                  ),
                ),

                Row(
                  children: [
                    _masarBadge(),
                    const SizedBox(width: 8),
                    const Text('MASAR', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
                    Container(margin: const EdgeInsets.symmetric(horizontal: 10), width: 1, height: 12, color: Colors.white.withValues(alpha: 0.2)),
                    Text('Control tower for last-mile delivery', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                    const Spacer(),
                    _liveIndicator(),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
                  child: Row(
                    children: [
                      _feature(Icons.location_on_outlined, 'Real-time tracking', 'Every delivery, live'),
                      const SizedBox(width: 24),
                      _feature(Icons.shield_outlined, 'Secure by design', 'Your fleet, protected'),
                      const SizedBox(width: 24),
                      _feature(Icons.insights_outlined, 'Smart analytics', 'Insights that ship faster'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagChip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.18)), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: _Palette.gold)),
          const SizedBox(width: 6),
          Text('DOHA, QATAR', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, letterSpacing: 1, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _masarBadge() {
    return Image.asset(
      'assets/images/logo.png',
      width: 20,
      height: 20,
      color: Colors.white.withValues(alpha: 0.85),
      colorBlendMode: BlendMode.srcIn,
    );
  }

  Widget _feature(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _Palette.brandTealLight),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveIndicator() {
    return AnimatedBuilder(
      animation: _routeController,
      builder: (context, _) {
        final pulse = (sin(_routeController.value * 2 * pi * 3) + 1) / 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _Palette.brandTealLight.withValues(alpha: 0.45 + pulse * 0.55))),
            const SizedBox(width: 6),
            Text('LIVE DISPATCH', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, letterSpacing: 1, color: Colors.white.withValues(alpha: 0.55))),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Sign-in form (right side, or full screen on narrow layouts)
  // ---------------------------------------------------------------------

  Widget _masarLogo({double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.27),
        boxShadow: [BoxShadow(color: _Palette.brandTeal.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.27),
        child: Image.asset('assets/images/logo.png', width: size, height: size, fit: BoxFit.cover),
      ),
    );
  }

  Widget _formFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _fieldDecoration('Email', icon: Icons.mail_outline)),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: _fieldDecoration(
            'Password',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: _Palette.textSecondary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => _isLoading ? null : _signIn(),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(value: _rememberMe, activeColor: _Palette.brandTeal, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: (v) => setState(() => _rememberMe = v ?? true)),
                  const SizedBox(width: 2),
                  const Text('Remember me', style: TextStyle(fontSize: 12.5, color: Color(0xFF4A534F))),
                ],
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5, color: _Palette.brandTeal, fontWeight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_errorMessage!, style: const TextStyle(color: _Palette.danger, fontSize: 13)),
          ),
        SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _Palette.brandTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            onPressed: _isLoading ? null : _signIn,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text('Sign in', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 16)],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _loginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _masarLogo()),
              const SizedBox(height: 14),
              const Text('MASAR', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2, color: _Palette.ink)),
              const SizedBox(height: 4),
              const Text('LAST-MILE DELIVERY SYSTEM', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9.5, letterSpacing: 1.5, color: _Palette.textSecondary)),
              const SizedBox(height: 26),
              const Text('Welcome back', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              const Text('Sign in to continue to your dashboard', style: TextStyle(fontSize: 13, color: _Palette.textSecondary)),
              const SizedBox(height: 22),
              _formFields(),
              const SizedBox(height: 26),
              const Text('© 2026 Essence Express  ·  Doha, Qatar', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF9AA39E))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 6, child: _brandPanel()),
                Expanded(flex: 5, child: _loginForm()),
              ],
            );
          }
          // Narrow window (or the driver/warehouse app on a phone): a
          // compact teal header instead of squeezing the full brand panel.
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _masarLogo(size: 52),
                  const SizedBox(height: 16),
                  const Text('ESSENCE EXPRESS', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2, color: _Palette.ink)),
                  const SizedBox(height: 6),
                  const Text('MASAR · LAST-MILE LOGISTICS · DOHA', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, letterSpacing: 1.2, color: _Palette.textSecondary)),
                  const SizedBox(height: 30),
                  _formFields(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Faint dot-grid texture behind the brand panel.
// ---------------------------------------------------------------------------
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const step = 24.0;
    for (double gx = 0; gx < size.width; gx += step) {
      for (double gy = 0; gy < size.height; gy += step) {
        canvas.drawCircle(Offset(gx, gy), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// The brand panel's signature element: a stylised Doha night skyline (with
// the Torch tower silhouette over the Corniche) and a delivery route drawn
// as a strand of pearls — a nod to Qatar's pearl-diving heritage and to
// "every mile counts". A van marked EE glides along the strand, lighting
// each pearl gold as it passes each checkpoint from your Orders view, then
// the route closes with an opening oyster before fading and looping.
// ---------------------------------------------------------------------------
class _Checkpoint {
  final String label;
  final double t;
  const _Checkpoint(this.label, this.t);
}

const _checkpoints = [
  _Checkpoint('PICKED UP', 0.04),
  _Checkpoint('IN TRANSIT', 0.36),
  _Checkpoint('OUT FOR DELIVERY', 0.68),
  _Checkpoint('DELIVERED', 0.97),
];

class _SkylineRoutePainter extends CustomPainter {
  final double t;
  const _SkylineRoutePainter(this.t);

  static const _travelEnd = 0.70;
  static const _celebrateEnd = 0.88;

  Path _routePath(Size size) {
    final w = size.width, h = size.height;
    final path = Path();
    path.moveTo(w * 0.02, h * 0.38);
    path.cubicTo(w * 0.16, h * -0.02, w * 0.30, h * 0.82, w * 0.48, h * 0.30);
    path.cubicTo(w * 0.66, h * -0.12, w * 0.80, h * 0.80, w * 0.97, h * 0.24);
    return path;
  }

  void _drawSkyline(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final baseline = h * 0.86;
    final paint = Paint()..color = const Color(0xFF0E4038).withValues(alpha: 0.55);

    void building(double xFrac, double widthFrac, double heightFrac) {
      final bw = w * widthFrac;
      final bh = h * heightFrac;
      final bx = w * xFrac;
      canvas.drawRect(Rect.fromLTWH(bx, baseline - bh, bw, bh), paint);
    }

    building(0.00, 0.028, 0.20);
    building(0.04, 0.022, 0.28);
    building(0.075, 0.03, 0.16);
    building(0.12, 0.02, 0.34);
    building(0.155, 0.026, 0.22);
    // Torch tower — the distinctive Doha landmark on the skyline.
    canvas.drawRect(Rect.fromLTWH(w * 0.20, baseline - h * 0.42, w * 0.014, h * 0.42), paint);
    canvas.drawCircle(Offset(w * 0.207, baseline - h * 0.44), h * 0.032, paint);
    building(0.235, 0.024, 0.24);
    building(0.27, 0.018, 0.34);
    building(0.30, 0.03, 0.18);
    building(0.68, 0.028, 0.18);
    building(0.72, 0.02, 0.30);
    building(0.75, 0.032, 0.22);
    building(0.79, 0.018, 0.36);
    building(0.82, 0.026, 0.16);
    building(0.86, 0.022, 0.26);
    building(0.90, 0.03, 0.14);
    building(0.94, 0.024, 0.24);

    final waterline = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseline), Offset(w, baseline), waterline);

    final reflection = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (double rx = 0.03; rx < 0.95; rx += 0.17) {
      canvas.drawLine(Offset(w * rx, baseline + h * 0.05), Offset(w * rx + w * 0.06, baseline + h * 0.05), reflection);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _drawSkyline(canvas, size);

    final fade = t > _celebrateEnd ? 1.0 - ((t - _celebrateEnd) / (1.0 - _celebrateEnd)) : 1.0;
    if (fade <= 0.01) return;

    final metrics = _routePath(size).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 0) return;

    // Thread (dashed) behind the pearls.
    final threadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22 * fade)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const dashLen = 2.4, gapLen = 8.0;
    var d = 0.0;
    while (d < total) {
      final next = min(d + dashLen, total);
      canvas.drawPath(metric.extractPath(d, next), threadPaint);
      d = next + gapLen;
    }

    final travelProgress = Curves.easeInOut.transform((t / _travelEnd).clamp(0.0, 1.0));
    final travelled = total * travelProgress;

    // Gold thread revealed behind the van.
    canvas.drawPath(
      metric.extractPath(0, travelled),
      Paint()
        ..color = _Palette.gold.withValues(alpha: 0.9 * fade)
        ..strokeWidth = 3.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (final cp in _checkpoints) {
      final cpDist = (cp.t * total).clamp(0.0, total);
      final tangent = metric.getTangentForOffset(cpDist);
      if (tangent == null) continue;
      _drawPearl(canvas, tangent, cp.label, reached: cpDist <= travelled + 1, fade: fade);
    }

    final parcelTangent = metric.getTangentForOffset(travelled.clamp(0.0, total));
    if (parcelTangent == null) return;

    if (t <= _travelEnd) {
      // Average the heading over a wider span of the curve (not just the
      // exact local tangent) so the truck banks gently through this fairly
      // wavy route instead of snapping toward whatever the curve is doing
      // at this exact instant.
      final behindDist = (travelled - 16).clamp(0.0, total);
      final aheadDist = (travelled + 16).clamp(0.0, total);
      final behindTangent = metric.getTangentForOffset(behindDist);
      final aheadTangent = metric.getTangentForOffset(aheadDist);
      double angle;
      if (behindTangent != null && aheadTangent != null) {
        final delta = aheadTangent.position - behindTangent.position;
        angle = atan2(delta.dy, delta.dx);
      } else {
        angle = parcelTangent.angle;
      }
      angle = angle.clamp(-0.13, 0.13); // ~ ±7.5°, was ±14.3°
      _drawVan(canvas, parcelTangent.position, angle, fade);
    } else {
      final endTangent = metric.getTangentForOffset(total);
      final endPos = endTangent?.position ?? parcelTangent.position;
      _drawVan(canvas, endPos, 0, fade);
      final celebrate = Curves.easeOutBack.transform(((t - _travelEnd) / (_celebrateEnd - _travelEnd)).clamp(0.0, 1.0));
      _drawOyster(canvas, endPos, celebrate, fade);
    }
  }

  void _drawPearl(Canvas canvas, ui.Tangent tangent, String label, {required bool reached, required double fade}) {
    final pos = tangent.position;
    canvas.drawCircle(pos, 9, Paint()..color = Colors.white.withValues(alpha: 0.18 * fade)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(pos, reached ? 6.4 : 5.6, Paint()..color = (reached ? _Palette.gold : Colors.white).withValues(alpha: (reached ? 0.95 : 0.26) * fade));
    // Tiny highlight so the reached pearls actually read as pearls.
    if (reached) canvas.drawCircle(pos + const Offset(-1.6, -1.6), 1.5, Paint()..color = Colors.white.withValues(alpha: 0.75 * fade));

    var normal = Offset(-tangent.vector.dy, tangent.vector.dx);
    if (normal.dy > 0) normal = -normal;
    final normLen = normal.distance == 0 ? 1 : normal.distance;
    normal = Offset(normal.dx / normLen, normal.dy / normLen);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 14,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: reached ? Colors.white.withValues(alpha: fade) : Colors.white.withValues(alpha: 0.5 * fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelCenter = pos + normal * 24;
    tp.paint(canvas, Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2));
  }

  void _drawVan(Canvas canvas, Offset pos, double angle, double fade) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    canvas.drawCircle(Offset.zero, 20, Paint()..color = _Palette.gold.withValues(alpha: 0.22 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Cargo box — matches the truck silhouette in the MASAR app icon:
    // one long box body, ESSENCE printed on the side, gold roof accent.
    final cargoRect = const Rect.fromLTWH(-27, -16, 38, 28);
    canvas.drawRRect(RRect.fromRectAndRadius(cargoRect, const Radius.circular(3)), Paint()..color = _Palette.pearl.withValues(alpha: 0.96 * fade));
    canvas.drawRRect(
      RRect.fromRectAndCorners(const Rect.fromLTWH(-27, -16, 38, 6), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
      Paint()..color = _Palette.gold.withValues(alpha: 0.95 * fade),
    );
    final tp = TextPainter(
      text: TextSpan(text: 'ESSENCE', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _Palette.ink.withValues(alpha: fade))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-8 - tp.width / 2, 1 - tp.height / 2));

    // Cab.
    final cabPath = Path()
      ..moveTo(11, 12)
      ..lineTo(11, -8)
      ..quadraticBezierTo(11, -13, 16, -13)
      ..lineTo(25, -13)
      ..quadraticBezierTo(29, -13, 30.5, -9)
      ..lineTo(33, 2)
      ..lineTo(33, 12)
      ..close();
    canvas.drawPath(cabPath, Paint()..color = _Palette.pearl.withValues(alpha: 0.96 * fade));
    final windowPath = Path()
      ..moveTo(15.5, -10.5)
      ..lineTo(24, -10.5)
      ..quadraticBezierTo(26.5, -10.5, 27.5, -8)
      ..lineTo(29, -3)
      ..lineTo(15.5, -3)
      ..close();
    canvas.drawPath(windowPath, Paint()..color = _Palette.ink.withValues(alpha: 0.78 * fade));

    // Wheels.
    final wheel = Paint()..color = const Color(0xFF0B1F1B).withValues(alpha: fade);
    canvas.drawCircle(const Offset(-15, 14), 6.2, wheel);
    canvas.drawCircle(const Offset(22, 14), 6.2, wheel);
    canvas.drawCircle(const Offset(-15, 14), 2.4, Paint()..color = const Color(0xFF555555).withValues(alpha: fade));
    canvas.drawCircle(const Offset(22, 14), 2.4, Paint()..color = const Color(0xFF555555).withValues(alpha: fade));

    canvas.restore();
  }

  void _drawOyster(Canvas canvas, Offset pos, double scale, double fade) {
    if (scale <= 0.01) return;
    canvas.save();
    canvas.translate(pos.dx, pos.dy - 28);

    final shellPaint = Paint()
      ..color = const Color(0xFF0E4038).withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.save();
    canvas.rotate(-0.32 * scale);
    canvas.drawArc(const Rect.fromLTWH(-26, -6, 26, 19), pi * 0.5, pi, false, shellPaint);
    canvas.restore();

    canvas.save();
    canvas.rotate(0.32 * scale);
    canvas.drawArc(const Rect.fromLTWH(0, -6, 26, 19), -pi * 0.5, pi, false, shellPaint);
    canvas.restore();

    canvas.drawCircle(Offset.zero, 8 * scale, Paint()..color = _Palette.pearl.withValues(alpha: fade));
    canvas.drawCircle(Offset(-2.2 * scale, -2.2 * scale), 2.2 * scale, Paint()..color = Colors.white.withValues(alpha: 0.8 * fade));

    if (scale > 0.6) {
      final checkPath = Path()
        ..moveTo(-4.2, 0)
        ..lineTo(-1, 3.2)
        ..lineTo(4.8, -4);
      canvas.drawPath(
        checkPath,
        Paint()
          ..color = _Palette.ink.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkylineRoutePainter oldDelegate) => oldDelegate.t != t;
}