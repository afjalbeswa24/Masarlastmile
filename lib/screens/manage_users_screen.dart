import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _myRole;
  String _roleFilter = 'all';

  final _roles = ['all', 'master_dispatcher', 'dispatcher', 'driver', 'warehouse', 'merchant'];

  @override
  void initState() {
    super.initState();
    _loadMyRole();
    _load();
  }

  Future<void> _loadMyRole() async {
    final data = await supabase.from('profiles').select('role').eq('id', supabase.auth.currentUser!.id).single();
    setState(() => _myRole = data['role'] as String);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await supabase.from('profiles').select().order('role');
    setState(() {
      _users = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered =>
      _roleFilter == 'all' ? _users : _users.where((u) => u['role'] == _roleFilter).toList();

  Future<void> _openEditSheet(Map<String, dynamic> user) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditUserSheet(user: user, myRole: _myRole ?? ''),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _roles.map((r) {
                    final active = _roleFilter == r;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(r == 'all' ? 'All' : statusLabel(r)),
                        selected: active,
                        onSelected: (_) => setState(() => _roleFilter = r),
                        selectedColor: AppColors.purpleLight,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text('No users found', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final user = _filtered[index];
                            final isMaster = user['role'] == 'master_dispatcher';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isMaster ? AppColors.purple : AppColors.background,
                                  child: Icon(Icons.person, color: isMaster ? Colors.white : AppColors.textSecondary),
                                ),
                                title: Text(user['full_name'] ?? 'Unnamed'),
                                subtitle: Text('${user['email'] ?? ''} — ${_roleLabel(user['role'])}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openEditSheet(user),
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

  String _roleLabel(String? role) {
    switch (role) {
      case 'master_dispatcher': return 'Master Dispatcher';
      case 'dispatcher': return 'Dispatcher';
      case 'driver': return 'Driver';
      case 'warehouse': return 'Warehouse';
      case 'merchant': return 'Merchant';
      default: return role ?? '';
    }
  }
}

class _EditUserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final String myRole;
  const _EditUserSheet({required this.user, required this.myRole});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _awbPrefixController;
  late String _role;
  late bool _canManageUsers;
  bool _saving = false;

  final _editableRoles = ['dispatcher', 'driver', 'warehouse', 'merchant'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['full_name'] ?? '');
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _awbPrefixController = TextEditingController(text: widget.user['awb_prefix'] ?? '');
    _role = widget.user['role'] ?? 'driver';
    _canManageUsers = widget.user['can_manage_users'] == true;
  }

  bool get _isMaster => widget.user['role'] == 'master_dispatcher';
  bool get _iAmMaster => widget.myRole == 'master_dispatcher';

  Future<void> _save() async {
    if (_role == 'merchant' && _awbPrefixController.text.trim().isNotEmpty) {
      final prefix = _awbPrefixController.text.trim();
      if (prefix.length != 3 || !RegExp(r'^[A-Za-z]+$').hasMatch(prefix)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AWB Prefix must be exactly 3 letters')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };
      if (!_isMaster) {
        updates['role'] = _role;
        updates['can_manage_users'] = _role == 'dispatcher' ? _canManageUsers : false;
        if (_role == 'merchant') {
          updates['awb_prefix'] = _awbPrefixController.text.trim().toUpperCase();
        }
      }

      await supabase.from('profiles').update(updates).eq('id', widget.user['id']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _promoteToMaster() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Make Master Dispatcher?'),
        content: Text('${widget.user['full_name']} will get full control over all users and orders. This cannot be undone from the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;

    await supabase.from('profiles').update({'role': 'master_dispatcher'}).eq('id', widget.user['id']);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController(text: widget.user['email'] ?? '');
    final newEmail = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'New email', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Update')),
        ],
      ),
    );
    if (newEmail == null || newEmail.isEmpty) return;

    try {
      final response = await supabase.functions.invoke('manage-user', body: {
        'action': 'update_email',
        'targetUserId': widget.user['id'],
        'newEmail': newEmail,
      });
      final data = response.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email updated successfully')));
        setState(() => widget.user['email'] = newEmail);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
  Future<void> _resetPassword() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Reset')),
        ],
      ),
    );
    if (newPassword == null || newPassword.isEmpty) return;

    try {
      final response = await supabase.functions.invoke('manage-user', body: {
        'action': 'reset_password',
        'targetUserId': widget.user['id'],
        'newPassword': newPassword,
      });
      final data = response.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this user?'),
        content: Text('${widget.user['full_name']} (${widget.user['email']}) will be permanently removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await supabase.functions.invoke('manage-user', body: {
        'action': 'delete_user',
        'targetUserId': widget.user['id'],
      });
      final data = response.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.user['email'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            if (_isMaster)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Chip(label: Text('Master Dispatcher — full access')),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: _editableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              if (_role == 'dispatcher')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Can manage users'),
                  value: _canManageUsers,
                  onChanged: (v) => setState(() => _canManageUsers = v),
                ),
              if (_role == 'merchant') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _awbPrefixController,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'AWB Prefix (3 letters)',
                    hintText: 'e.g. NTP',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ],
              if (_iAmMaster) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Make Master Dispatcher'),
                  onPressed: _promoteToMaster,
                ),
              ],
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.email_outlined),
              label: const Text('Change Email'),
              onPressed: _changeEmail,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reset Password'),
              onPressed: _resetPassword,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete User', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              onPressed: _deleteUser,
            ),
          ],
        ),
      ),
    );
  }
}