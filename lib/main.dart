import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/merchant_home_screen.dart';
import 'screens/dispatcher_home_screen.dart';
import 'screens/warehouse_home_screen.dart';
import 'screens/driver_home_screen.dart';
import 'package:flutter/gestures.dart';
import 'utils/scan_mode_service.dart';
import 'screens/admin_home_screen.dart';


class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        // Mouse intentionally excluded — left-click-drag is now reserved for
        // text selection. Horizontal/vertical scrolling on desktop happens
        // via the visible scrollbars (drag the bar itself) or middle-mouse-
        // button pan, both already built into the dispatcher grid.
      };
}Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ScanModeService.init();

  await Supabase.initialize(
    url: 'https://qqdxvzitanlwgvngcbld.supabase.co',
    publishableKey: 'sb_publishable_ChsDjQQH15MbTVCFjpoLsg_pp8TbCAY',
  );

  await SessionTimeout.init();
  await SessionTimeout.enforce();

  runApp(const MyApp());
}

/// Signs everyone out after [maxIdle] without use, so people must log in
/// again after a long break. Checked on app start, on returning to the app,
/// and on the first tap/click after a long idle period.
class SessionTimeout {
  static const maxIdle = Duration(hours: 6);
  static const _key = 'last_active_ms';
  static SharedPreferences? _prefs;
  static int _lastStamp = 0;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  /// Returns true if the user was just signed out for being idle too long.
  static Future<bool> enforce() async {
    // Web/desktop browser only — the Android app stays signed in.
    if (!kIsWeb) return false;
    final prefs = _prefs;
    final auth = Supabase.instance.client.auth;
    if (prefs == null || auth.currentSession == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_key);
    if (last == null) {
      await prefs.setInt(_key, now);
      _lastStamp = now;
      return false;
    }
    if (now - last > maxIdle.inMilliseconds) {
      _lastStamp = 0;
      await prefs.remove(_key);
      await auth.signOut();
      return true;
    }
    return false;
  }

  /// Records activity (at most once every 30 seconds).
  static void touch() {
    if (!kIsWeb) return;
    final prefs = _prefs;
    if (prefs == null || Supabase.instance.client.auth.currentSession == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastStamp < 30000) return;
    _lastStamp = now;
    prefs.setInt(_key, now);
  }
}

class _ActivityWatcher extends StatefulWidget {
  final Widget child;
  const _ActivityWatcher({required this.child});
  @override
  State<_ActivityWatcher> createState() => _ActivityWatcherState();
}

class _ActivityWatcherState extends State<_ActivityWatcher> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(SessionTimeout.enforce());
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) async {
        if (await SessionTimeout.enforce()) return;
        SessionTimeout.touch();
      },
      child: widget.child,
    );
  }
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESE Last Mile',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: buildAppTheme(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: _ActivityWatcher(child: child!),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return const RoleRouter();
      },
    );
  }
}

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();
    setState(() {
      _role = data['role'] as String;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (_role) {
      case 'super_admin':
        return const AdminHomeScreen();
      case 'merchant':
        return const MerchantHomeScreen();
      case 'warehouse':
        return const WarehouseHomeScreen();
      case 'master_dispatcher':
      case 'dispatcher':
        return const DispatcherHomeScreen();
      case 'driver':
        return const DriverHomeScreen();
      default:
        return const Scaffold(
          body: Center(child: Text('Unknown role. Contact admin.')),
        );
    }
  }
}