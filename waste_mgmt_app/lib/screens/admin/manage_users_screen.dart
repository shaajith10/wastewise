import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
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

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'admin' ? Colors.red.shade100 : role == 'collector' ? Colors.blue.shade100 : Colors.green.shade100,
                        child: Icon(
                          role == 'admin' ? Icons.security : role == 'collector' ? Icons.local_shipping : Icons.person,
                          color: role == 'admin' ? Colors.red : role == 'collector' ? Colors.blue : AppTheme.primary,
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$email  •  Role: $role'),
                      trailing: Chip(
                        label: Text('$pts pts'),
                        backgroundColor: const Color(0xFFFFF8E1),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
