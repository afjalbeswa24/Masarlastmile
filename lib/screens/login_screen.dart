import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'dispatch_map.dart';

// ---------------------------------------------------------------------------
// Self-contained palette for this screen. Doesn't depend on AppTheme so it
// drops in cleanly — fold these into your shared theme later if you want.
// Inspired by the MASAR app icon's teal gradient, Doha's night skyline, and
// Qatar's pearl-diving heritage (the signature route below is a pearl strand,
// not a generic dotted line).
// ---------------------------------------------------------------------------
class _Palette {
  static const nightTeal = Color(0xFF0A1E33);
  static const brandTeal = Color(0xFF2B7FC4);
  static const brandTealLight = Color(0xFF6BB6E8);
  // Sky-blue background tones — lighter/more vivid than nightTeal/deepTeal,
  // used for the brand panel gradient so it reads as sky blue rather than
  // near-black navy, while still darkening at the edges for text contrast.
  static const skyBlue = Color(0xFF3E8FD6);
  static const skyBlueDeep = Color(0xFF1E5C93);
  static const gold = Color(0xFFD9AF61);
  static const pearl = Color(0xFFF3ECDD);
  static const ink = Color(0xFF0B1F33);
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
          colors: [_Palette.skyBlue, _Palette.skyBlueDeep, _Palette.nightTeal],
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

                // -- Doha skyline (faint) + animated Qatar dispatch map ----
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.45,
                            child: Image.asset(
                              'assets/images/doha_skyline.png',
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.bottomCenter,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(child: DispatchMap()),
                    ],
                  ),
                ),

                Row(
                  children: [
                    _masarBadge(),
                    const SizedBox(width: 8),
                    const Text('ESE Last Mile', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
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
      color: _Palette.brandTealLight, // matches the sign-in button's blue, lighter tint so it reads clearly against the dark panel
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
              const Text('ESE', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2, color: _Palette.ink)),
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
                                    Text.rich(
                    TextSpan(
                      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
                      children: [
                        TextSpan(text: 'ESSENCE ', style: TextStyle(color: const Color(0xFF1C4680))),
                        TextSpan(text: 'EXPRESS', style: TextStyle(color: const Color(0xFF4E9EB8), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('ESSENCE · LAST-MILE LOGISTICS · DOHA', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, letterSpacing: 1.2, color: _Palette.textSecondary)),
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
