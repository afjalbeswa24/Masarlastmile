import 'dart:math';
import 'dart:ui' as ui;

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

  // Drives the parcel through its delivery stages.
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

            // -- Live delivery progress, the signature element ---------------
            Expanded(
              child: AnimatedBuilder(
                animation: _routeController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DeliveryProgressPainter(_routeController.value),
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
              'LIVE DISPATCH',
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
          // drop the progress animation and give a compact header instead
          // of squeezing the full brand panel.
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
// Live delivery progress — the brand panel's signature element.
// A parcel travels left to right along a curved route through the same
// stages your Orders view already uses, lighting up each checkpoint as it
// passes, then celebrates with a checkmark at "Delivered" before fading
// and looping. No geography involved, so nothing here can look "broken."
// ---------------------------------------------------------------------------

class _Checkpoint {
  final String label;
  final double t; // fraction along the curve, 0..1
  const _Checkpoint(this.label, this.t);
}

const _checkpoints = [
  _Checkpoint('PICKED UP', 0.04),
  _Checkpoint('IN TRANSIT', 0.36),
  _Checkpoint('OUT FOR DELIVERY', 0.68),
  _Checkpoint('DELIVERED', 0.97),
];

class _DeliveryProgressPainter extends CustomPainter {
  final double t; // 0..1, looping
  const _DeliveryProgressPainter(this.t);

  // Timing within one loop: the parcel travels for the first 70% of the
  // cycle, the checkmark celebrates for the next 18%, then everything
  // fades out over the last 12% so the loop restart is never a visible snap.
  static const _travelEnd = 0.70;
  static const _celebrateEnd = 0.88;

  // A gentle left-to-right wave. Built from cubic beziers rather than
  // traced points, so it stays smooth at any panel size.
  Path _routePath(Size size) {
    final w = size.width, h = size.height;
    final path = Path();
    path.moveTo(w * 0.03, h * 0.55);
    path.cubicTo(w * 0.18, h * 0.14, w * 0.32, h * 0.92, w * 0.50, h * 0.50);
    path.cubicTo(w * 0.68, h * 0.10, w * 0.82, h * 0.90, w * 0.97, h * 0.46);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Faint dot-grid texture.
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const step = 24.0;
    for (double gx = 0; gx < size.width; gx += step) {
      for (double gy = 0; gy < size.height; gy += step) {
        canvas.drawCircle(Offset(gx, gy), 1.0, gridPaint);
      }
    }

    final fade = t > _celebrateEnd ? 1.0 - ((t - _celebrateEnd) / (1.0 - _celebrateEnd)) : 1.0;
    if (fade <= 0.01) return;

    final metrics = _routePath(size).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 0) return;

    // Dashed route line.
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16 * fade)
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

    final travelProgress = Curves.easeInOut.transform((t / _travelEnd).clamp(0.0, 1.0));
    final travelled = total * travelProgress;

    // Brightened trail behind the parcel.
    canvas.drawPath(
      metric.extractPath(0, travelled),
      Paint()
        ..color = AppColors.purple.withValues(alpha: 0.55 * fade)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Checkpoints.
    for (final cp in _checkpoints) {
      final cpDist = (cp.t * total).clamp(0.0, total);
      final tangent = metric.getTangentForOffset(cpDist);
      if (tangent == null) continue;
      _drawCheckpoint(canvas, tangent, cp.label, reached: cpDist <= travelled + 1, fade: fade);
    }

    final parcelTangent = metric.getTangentForOffset(travelled.clamp(0.0, total));
    if (parcelTangent == null) return;

    if (t <= _travelEnd) {
      _drawParcel(canvas, parcelTangent.position, parcelTangent.angle, fade);
    } else {
      final endTangent = metric.getTangentForOffset(total);
      final endPos = endTangent?.position ?? parcelTangent.position;
      _drawParcel(canvas, endPos, 0, fade);
      final celebrate = Curves.easeOutBack.transform(((t - _travelEnd) / (_celebrateEnd - _travelEnd)).clamp(0.0, 1.0));
      _drawCheckBadge(canvas, endPos, celebrate, fade);
    }
  }

  void _drawCheckpoint(Canvas canvas, ui.Tangent tangent, String label, {required bool reached, required double fade}) {
    final pos = tangent.position;
    canvas.drawCircle(
      pos,
      4,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(pos, 2.4, Paint()..color = (reached ? AppColors.purple : Colors.white).withValues(alpha: (reached ? 0.85 : 0.18) * fade));

    // Anchor the label to the outward (upward-biased) side of the curve
    // so it never sits on top of the route line regardless of the local
    // tangent direction.
    var normal = Offset(-tangent.vector.dy, tangent.vector.dx);
    if (normal.dy > 0) normal = -normal;
    final normLen = normal.distance == 0 ? 1 : normal.distance;
    normal = Offset(normal.dx / normLen, normal.dy / normLen);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 9.5,
          letterSpacing: 0.5,
          fontWeight: reached ? FontWeight.w600 : FontWeight.w400,
          color: Colors.white.withValues(alpha: (reached ? 0.9 : 0.4) * fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelCenter = pos + normal * 14;
    tp.paint(canvas, Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2));
  }

  void _drawParcel(Canvas canvas, Offset pos, double angle, double fade) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // Soft glow.
    canvas.drawCircle(
      Offset.zero,
      9,
      Paint()
        ..color = AppColors.purple.withValues(alpha: 0.28 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Box body — a cross-taped parcel is symmetric, so it reads correctly
    // at any rotation angle (unlike an asymmetric side-view icon).
    final boxRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-5.5, -5.5, 11, 11), const Radius.circular(2));
    canvas.drawRRect(boxRect, Paint()..color = Colors.white.withValues(alpha: 0.95 * fade));

    final tapePaint = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.75 * fade)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -5.5), const Offset(0, 5.5), tapePaint);
    canvas.drawLine(const Offset(-5.5, 0), const Offset(5.5, 0), tapePaint);

    canvas.restore();
  }

  void _drawCheckBadge(Canvas canvas, Offset pos, double scale, double fade) {
    if (scale <= 0.01) return;
    canvas.save();
    canvas.translate(pos.dx, pos.dy - 16);
    canvas.scale(scale);

    canvas.drawCircle(Offset.zero, 8, Paint()..color = AppColors.purple.withValues(alpha: fade));
    final checkPath = Path()
      ..moveTo(-3.6, 0)
      ..lineTo(-1, 3)
      ..lineTo(4, -3.5);
    canvas.drawPath(
      checkPath,
      Paint()
        ..color = AppColors.navy.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DeliveryProgressPainter oldDelegate) => oldDelegate.t != t;
}