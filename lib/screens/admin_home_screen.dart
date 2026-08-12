import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await supabase.from('companies').select().order('created_at', ascending: false);
    setState(() {
      _companies = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _openCreateCompanyDialog() async {
    final companyNameController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool submitting = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Company'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: companyNameController, decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  const Text('First Master Dispatcher account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary Password', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: submitting ? null : () async {
                if (companyNameController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    passwordController.text.trim().length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields (password min. 6 characters)')));
                  return;
                }
                setDialogState(() => submitting = true);
                try {
                  final response = await supabase.functions.invoke('create-company', body: {
                    'companyName': companyNameController.text.trim(),
                    'fullName': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'password': passwordController.text.trim(),
                  });
                  final data = response.data;
                  if (data is Map && data['error'] != null) throw Exception(data['error']);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  setDialogState(() => submitting = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Company'),
            ),
          ],
        ),
      ),
    );

    if (created == true) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> company) async {
    final newValue = !(company['is_active'] as bool);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newValue ? 'Reactivate company?' : 'Suspend company?'),
        content: Text(
          newValue
              ? '${company['name']} will regain access immediately.'
              : '${company['name']} will lose all access immediately — no users there will be able to log in or use the app until reactivated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: newValue ? AppColors.statusDelivered : AppColors.statusFailed),
            onPressed: () => Navigator.pop(context, true),
            child: Text(newValue ? 'Reactivate' : 'Suspend'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('companies').update({'is_active': newValue}).eq('id', company['id']);
      _load();
    }
  }

  Future<void> _viewDetails(Map<String, dynamic> company) async {
    showDialog(
      context: context,
      builder: (_) => _CompanyDetailDialog(company: company),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MASAR — Admin'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => supabase.auth.signOut()),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('${_companies.length} compan${_companies.length == 1 ? 'y' : 'ies'}', style: const TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Company'),
                    onPressed: _openCreateCompanyDialog,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _companies.isEmpty
                      ? const Center(child: Text('No companies yet — create the first one', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _companies.length,
                          itemBuilder: (context, index) {
                            final company = _companies[index];
                            final active = company['is_active'] as bool;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: active ? AppColors.purpleLight : Colors.grey.shade200,
                                  child: Icon(Icons.business, color: active ? AppColors.purple : Colors.grey),
                                ),
                                title: Text(company['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(active ? 'Active' : 'Suspended', style: TextStyle(color: active ? AppColors.statusDelivered : AppColors.statusFailed)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.insights), tooltip: 'View Stats', onPressed: () => _viewDetails(company)),
                                    Switch(
                                      value: active,
                                      activeThumbColor: AppColors.statusDelivered,
                                      onChanged: (_) => _toggleActive(company),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyDetailDialog extends StatefulWidget {
  final Map<String, dynamic> company;
  const _CompanyDetailDialog({required this.company});

  @override
  State<_CompanyDetailDialog> createState() => _CompanyDetailDialogState();
}

class _CompanyDetailDialogState extends State<_CompanyDetailDialog> {
  bool _loading = true;
  int _userCount = 0;
  int _orderCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = widget.company['id'];
    // Admin only sees COUNTS here (via count-only queries) — never the
    // actual order/user rows themselves, keeping operational data private.
    final users = await supabase.from('profiles').select('id').eq('company_id', companyId).count();
    final orders = await supabase.from('orders').select('id').eq('company_id', companyId).count();

    setState(() {
      _userCount = users.count;
      _orderCount = orders.count;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.company['name'] ?? ''),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(leading: const Icon(Icons.people_outline), title: const Text('Total Users'), trailing: Text('$_userCount', style: const TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: const Icon(Icons.local_shipping_outlined), title: const Text('Total Orders'), trailing: Text('$_orderCount', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}