import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _stats;
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
      final data = await ApiClient.get('/admin/stats');
      _stats = data['stats'] as Map<String, dynamic>?;
    } catch (e) {
      _error = 'Failed to load system statistics.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showConfirmDialog(context, title: 'Sign Out', message: 'Sign out of admin console?', danger: true);
              if (confirm && mounted) {
                await context.read<AuthProvider>().logout();
                if (mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppTheme.primaryDark,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(auth.displayName ?? 'Administrator', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('System Management & Analytics', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('System Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (_loading) const LoadingWidget()
              else if (_error != null) ErrorStateWidget(message: _error!, onRetry: _load)
              else ...[
                Row(
                  children: [
                    _StatTile(icon: Icons.people, color: Colors.blue, title: 'Citizens', value: '${_stats?['totalCitizens'] ?? 0}'),
                    const SizedBox(width: 10),
                    _StatTile(icon: Icons.local_shipping, color: Colors.indigo, title: 'Collectors', value: '${_stats?['totalCollectors'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatTile(icon: Icons.list_alt, color: Colors.orange, title: 'Total Requests', value: '${_stats?['totalRequests'] ?? 0}'),
                    const SizedBox(width: 10),
                    _StatTile(icon: Icons.eco, color: AppTheme.primary, title: 'Total Recycled', value: '${_stats?['totalKgRecycled'] ?? 0} kg'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatTile(icon: Icons.stars, color: Colors.amber.shade800, title: 'Rewards Issued', value: '${_stats?['totalRewardsIssued'] ?? 0} pts'),
                    const SizedBox(width: 10),
                    _StatTile(icon: Icons.verified_user, color: Colors.teal, title: 'Verifications', value: '${_stats?['totalRecyclingRecords'] ?? 0}'),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const Text('Management Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _AdminToolTile(icon: Icons.list_alt, title: 'Manage Pickup Requests', subtitle: 'View, assign collectors, and monitor status', onTap: () => context.go('/admin/requests')),
              _AdminToolTile(icon: Icons.people, title: 'Manage Users', subtitle: 'View citizens and account statuses', onTap: () => context.go('/admin/users')),
              _AdminToolTile(icon: Icons.local_shipping, title: 'Manage Collectors', subtitle: 'Register and manage authorized collectors', onTap: () => context.go('/admin/collectors')),
              _AdminToolTile(icon: Icons.category, title: 'Waste Categories', subtitle: 'Configure waste types and icons', onTap: () => context.go('/admin/categories')),
              _AdminToolTile(icon: Icons.stars, title: 'Reward Rules', subtitle: 'Configure points per kg per category', onTap: () => context.go('/admin/reward-rules')),
              _AdminToolTile(icon: Icons.bar_chart, title: 'Recycling Reports', subtitle: 'Inspect system-wide verified recycling records', onTap: () => context.go('/admin/reports')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value;
  const _StatTile({required this.icon, required this.color, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminToolTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _AdminToolTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.1), child: Icon(icon, color: AppTheme.primary)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.primary),
        onTap: onTap,
      ),
    );
  }
}
