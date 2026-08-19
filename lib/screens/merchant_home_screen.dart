import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'merchant_orders_screen.dart';

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  String _companyName = '';

  @override
  void initState() {
    super.initState();
    _loadCompanyName();
  }

  Future<void> _loadCompanyName() async {
    final merchantId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from('profiles')
        .select('company:companies(name)')
        .eq('id', merchantId)
        .maybeSingle();

    setState(() {
      _companyName = profile?['company']?['name'] ?? 'Essence Express';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Text(_companyName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                const Spacer(),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.purple,
                  child: Text(
                    (supabase.auth.currentUser?.email ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () => supabase.auth.signOut(),
                ),
              ],
            ),
          ),
          const Expanded(child: MerchantOrdersScreen()),
        ],
      ),
    );
  }
}