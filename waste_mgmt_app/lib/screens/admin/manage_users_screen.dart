import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

const _roles = ['citizen', 'collector', 'admin'];

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('/admin/users');
      _users = List<Map<String, dynamic>>.from(data['users'] ?? []);
    } catch (e) {
      _error = 'Failed to load user accounts.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'citizen';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add User'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) return 'Enter a valid 10-digit phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r[0].toUpperCase() + r.substring(1)))).toList(),
                    onChanged: (v) => setDialogState(() => role = v ?? 'citizen'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      await ApiClient.post('/admin/users', {
        'displayName': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'password': passCtrl.text,
        'role': role,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created! They can log in with the email/password now.'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Could not reach the server.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    try {
      await ApiClient.patch('/admin/users/${user['uid'] ?? user['id']}', {'role': newRole});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user['displayName']} is now $newRole'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Could not reach the server.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final makeActive = user['active'] == false;
    final confirm = await showConfirmDialog(
      context,
      title: makeActive ? 'Reactivate Account?' : 'Deactivate Account?',
      message: makeActive
        ? '${user['displayName']} will be able to log in again.'
        : '${user['displayName']} will no longer be able to log in.',
      confirmLabel: makeActive ? 'Reactivate' : 'Deactivate',
      dismissLabel: 'Cancel',
      danger: !makeActive,
    );
    if (!confirm || !mounted) return;

    try {
      await ApiClient.patch('/admin/users/${user['uid'] ?? user['id']}', {'active': makeActive});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(makeActive ? 'Account reactivated' : 'Account deactivated'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Could not reach the server.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthProvider>().uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
        : _users.isEmpty
          ? const EmptyStateWidget(icon: Icons.people_outline, title: 'No users found')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  final role = u['role'] ?? 'citizen';
                  final email = u['email'] ?? '';
                  final name = u['displayName'] ?? 'User';
                  final pts = u['rewardBalance'] ?? 0;
                  final active = u['active'] != false;
                  final isSelf = (u['uid'] ?? u['id']) == myUid;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'admin' ? Colors.red.shade100 : role == 'collector' ? Colors.blue.shade100 : Colors.green.shade100,
                        child: Icon(
                          role == 'admin' ? Icons.security : role == 'collector' ? Icons.local_shipping : Icons.person,
                          color: role == 'admin' ? Colors.red : role == 'collector' ? Colors.blue : AppTheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (!active)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Chip(
                                label: Text('Inactive', style: TextStyle(fontSize: 10)),
                                backgroundColor: Color(0xFFEEEEEE),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text('$email  •  Role: $role'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(label: Text('$pts pts'), backgroundColor: const Color(0xFFFFF8E1)),
                          PopupMenuButton<String>(
                            enabled: !isSelf,
                            tooltip: isSelf ? "You can't manage your own account here" : 'Manage',
                            onSelected: (value) {
                              if (value == 'toggle_active') {
                                _toggleActive(u);
                              } else {
                                _changeRole(u, value);
                              }
                            },
                            itemBuilder: (ctx) => [
                              for (final r in _roles)
                                if (r != role)
                                  PopupMenuItem(value: r, child: Text('Make ${r[0].toUpperCase()}${r.substring(1)}')),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'toggle_active',
                                child: Text(active ? 'Deactivate' : 'Reactivate'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }
}
