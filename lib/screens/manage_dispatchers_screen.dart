import 'package:flutter/material.dart';
import '../main.dart';

class ManageDispatchersScreen extends StatefulWidget {
  const ManageDispatchersScreen({super.key});

  @override
  State<ManageDispatchersScreen> createState() => _ManageDispatchersScreenState();
}

class _ManageDispatchersScreenState extends State<ManageDispatchersScreen> {
  List<Map<String, dynamic>> _dispatchers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDispatchers();
  }

  Future<void> _loadDispatchers() async {
    setState(() => _loading = true);
    final data = await supabase
        .from('profiles')
        .select('id, full_name, phone, role, can_manage_users')
        .inFilter('role', ['dispatcher', 'master_dispatcher'])
        .order('role');

    setState(() {
      _dispatchers = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _togglePermission(String id, bool value) async {
    await supabase.from('profiles').update({'can_manage_users': value}).eq('id', id);
    _loadDispatchers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Dispatchers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _dispatchers.length,
              itemBuilder: (context, index) {
                final d = _dispatchers[index];
                final isMaster = d['role'] == 'master_dispatcher';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(d['full_name'] ?? 'Unnamed'),
                    subtitle: Text(isMaster ? 'Master Dispatcher' : 'Dispatcher'),
                    trailing: isMaster
                        ? const Chip(label: Text('Full Access'))
                        : Switch(
                            value: d['can_manage_users'] == true,
                            onChanged: (value) => _togglePermission(d['id'], value),
                          ),
                  ),
                );
              },
            ),
    );
  }
}