import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Drives the van along its dispatch route.
  late final AnimationController _routeController;

  @override
  void initState() {
    super.initState();
    _routeController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
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
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
    );
  }

  // ---------------------------------------------------------------------
  // Brand panel (wide layout, left side)
  // ---------------------------------------------------------------------

  Widget _brandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF060B12)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 44, 40, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Company wordmark, dominant --------------------------------
            const Text(
              'ESSENCE',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 42,
                height: 1.02,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            const Text(
              'EXPRESS',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 42,
                height: 1.02,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'LAST-MILE LOGISTICS · DOHA, QATAR',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),

            // -- Live dispatch route, the signature element ------------------
            Expanded(
              child: AnimatedBuilder(
                animation: _routeController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DispatchRoutePainter(_routeController.value),
                    size: Size.infinite,
                  );
                },
              ),
            ),

            // -- MASAR app badge + live status -------------------------------
            Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 20,
                  height: 20,
                  color: Colors.white.withValues(alpha: 0.85),
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(width: 8),
                const Text(
                  'MASAR',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 1,
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Text(
                  'Control tower for last-mile delivery',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                _liveIndicator(),
              ],
            ),
          ],
        ),
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
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purple.withValues(alpha: 0.45 + pulse * 0.55),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '6 ZONES LIVE',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                letterSpacing: 1,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Sign-in form (right side, or full screen on narrow layouts)
  // ---------------------------------------------------------------------

  Widget _loginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SIGN IN',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Sign in to your account', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration('Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _fieldDecoration('Password'),
                onSubmitted: (_) => _isLoading ? null : _signIn(),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.statusFailed, fontSize: 13)),
                ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ),
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
          final isWide = constraints.maxWidth >= 800;
          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 5, child: _brandPanel()),
                Expanded(flex: 4, child: _loginForm()),
              ],
            );
          }
          // Narrow window (or the driver/warehouse app running on a phone):
          // drop the route animation and give a compact header instead of
          // squeezing the full brand panel.
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ESSENCE EXPRESS',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MASAR · LAST-MILE LOGISTICS',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _fieldDecoration('Email')),
                  const SizedBox(height: 16),
                  TextField(controller: _passwordController, obscureText: true, decoration: _fieldDecoration('Password')),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.statusFailed)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign In'),
                    ),
                  ),
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
// Live dispatch route — the brand panel's signature element.
// An abstract winding route (not tied to real geography, so it can't look
// "broken" the way a hand-traced map can) with six zone stops pulled from
// the ops dashboard, including Al Khor. A van drives the full route on a
// loop, leaving a brightened trail behind it. It's drawn side-view, so it
// mirrors horizontally rather than rotating past vertical, and only ever
// tilts slightly — keeping it right-side-up at every point on the curve.
// ---------------------------------------------------------------------------

class _RouteStop {
  final String label;
  final double t; // fraction along the route, 0..1
  final bool isHub;
  const _RouteStop(this.label, this.t, {this.isHub = false});
}

const _routeStops = [
  _RouteStop('AL KHOR', 0.04),
  _RouteStop('LUSAIL', 0.20),
  _RouteStop('AL RAYYAN', 0.38),
  _RouteStop('DOHA CENTRAL', 0.56, isHub: true),
  _RouteStop('BARWA CITY', 0.78),
  _RouteStop('AL WUKAIR', 0.96),
];

class _DispatchRoutePainter extends CustomPainter {
  final double t; // 0..1, looping
  const _DispatchRoutePainter(this.t);

  // A gentle, guaranteed-smooth S-curve running top to bottom. Built from
  // cubic beziers rather than traced points, so it can't render "broken"
  // at odd sizes the way a hand-plotted shape can.
  Path _routePath(Size size) {
    final w = size.width, h = size.height;
    final path = Path();
    path.moveTo(w * 0.22, h * 0.03);
    path.cubicTo(w * 0.80, h * 0.10, w * 0.02, h * 0.26, w * 0.58, h * 0.34);
    path.cubicTo(w * 0.98, h * 0.41, w * 0.06, h * 0.53, w * 0.32, h * 0.65);
    path.cubicTo(w * 0.52, h * 0.75, w * 0.90, h * 0.83, w * 0.56, h * 0.96);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Faint dot-grid texture.
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, gridPaint);
      }
    }

    final metrics = _routePath(size).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 0) return;

    // Dashed route line.
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const dashLen = 6.0, gapLen = 5.0;
    var d = 0.0;
    while (d < total) {
      final next = min(d + dashLen, total);
      canvas.drawPath(metric.extractPath(d, next), dashPaint);
      d = next + gapLen;
    }

    // Brightened trail behind the van.
    final travelled = total * t;
    canvas.drawPath(
      metric.extractPath(0, travelled),
      Paint()
        ..color = AppColors.purple.withValues(alpha: 0.55)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Zone stops.
    for (final stop in _routeStops) {
      final tangent = metric.getTangentForOffset((stop.t * total).clamp(0, total));
      if (tangent != null) {
        _drawStop(canvas, tangent.position, stop.label, isHub: stop.isHub);
      }
    }

    // Van.
    final vanTangent = metric.getTangentForOffset(travelled.clamp(0, total));
    if (vanTangent != null) {
      _drawVan(canvas, vanTangent.position, vanTangent.angle);
    }
  }

  void _drawStop(Canvas canvas, Offset pos, String label, {required bool isHub}) {
    canvas.drawCircle(
      pos,
      isHub ? 8 : 4.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(pos, isHub ? 3.6 : 2.2, Paint()..color = isHub ? const Color(0xFFF5A623) : Colors.white.withValues(alpha: 0.8));

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 8.5,
          letterSpacing: 0.4,
          color: Colors.white.withValues(alpha: isHub ? 0.85 : 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + (isHub ? 12 : 9)));
  }

  void _drawVan(Canvas canvas, Offset pos, double angle) {
    // The van icon is side-view (asymmetric top/bottom: roof vs. wheels),
    // so it must never rotate past vertical or it reads as upside-down.
    // Mirror horizontally when heading left, and only ever apply a small
    // tilt — the standard treatment for 2D vehicle sprites following a path.
    final direction = Offset(cos(angle), sin(angle));
    final movingLeft = direction.dx < 0;
    final tilt = atan2(direction.dy, direction.dx.abs()).clamp(-0.45, 0.45);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (movingLeft) canvas.scale(-1, 1);
    canvas.rotate(tilt);

    // Soft glow.
    canvas.drawCircle(
      Offset.zero,
      8,
      Paint()
        ..color = AppColors.purple.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Two short trailing speed-lines behind the van.
    final trailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-9, -1.5), const Offset(-5, -1.5), trailPaint);
    canvas.drawLine(const Offset(-9, 1.5), const Offset(-6, 1.5), trailPaint..color = Colors.white.withValues(alpha: 0.2));

    // Van body (nose points toward +x, the direction of travel).
    final bodyRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -3.5, 12, 7), const Radius.circular(2));
    canvas.drawRRect(bodyRect, Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Windshield hint near the front.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, -2.3, 3, 4.6), const Radius.circular(1)),
      Paint()..color = AppColors.navy.withValues(alpha: 0.7),
    );

    // Wheels.
    final wheelPaint = Paint()..color = AppColors.navy;
    canvas.drawCircle(const Offset(-3, 3.8), 1.5, wheelPaint);
    canvas.drawCircle(const Offset(3, 3.8), 1.5, wheelPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DispatchRoutePainter oldDelegate) => oldDelegate.t != t;
}