import 'package:flutter/material.dart';
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

  runApp(const MyApp());
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
          child: child!,
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