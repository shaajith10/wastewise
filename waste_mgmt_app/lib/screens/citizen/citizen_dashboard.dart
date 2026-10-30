import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_badge.dart';

class CitizenDashboard extends StatefulWidget {
  const CitizenDashboard({super.key});
  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  List<Map<String, dynamic>> _recentRequests = [];
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
      final data = await ApiClient.get('/pickup-requests?limit=5');
      _recentRequests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
    } catch (e) {
      _error = 'Could not load requests. Is the backend running?';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.displayName?.split(' ').first ?? 'there';
    final balance = auth.rewardBalance;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppTheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryDark, AppTheme.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Hello, $name! 👋', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Ready to recycle today?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats Row ─────────────────────────────────────────
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.stars, iconColor: const Color(0xFFF57F17),
                          title: 'Reward Points', value: '$balance pts',
                          onTap: () => context.go('/citizen/rewards'),
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.local_shipping_outlined, iconColor: AppTheme.primary,
                          title: 'My Requests', value: '${_recentRequests.length}',
                          onTap: () => context.go('/citizen/requests'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Quick Actions ──────────────────────────────────────
                    const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _QuickAction(icon: Icons.add_circle_outline, label: 'Request Pickup', color: AppTheme.primary, onTap: () => context.go('/citizen/submit')),
                        const SizedBox(width: 10),
                        _QuickAction(icon: Icons.history, label: 'Recycling History', color: const Color(0xFF00838F), onTap: () => context.go('/citizen/recycling')),
                        const SizedBox(width: 10),
                        _QuickAction(icon: Icons.stars, label: 'My Rewards', color: const Color(0xFFF57F17), onTap: () => context.go('/citizen/rewards')),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Recent Requests ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Requests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        TextButton(onPressed: () => context.go('/citizen/requests'), child: const Text('See All', style: TextStyle(color: AppTheme.primary))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loading) const LoadingWidget()
                    else if (_error != null) ErrorStateWidget(message: _error!, onRetry: _load)
                    else if (_recentRequests.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.inbox_outlined,
                        title: 'No requests yet',
                        subtitle: 'Submit your first pickup request below.',
                        actionLabel: 'Request Pickup',
                        onAction: () => context.go('/citizen/submit'),
                      )
                    else
                      ...(_recentRequests.map((r) => _RequestTile(request: r, onTap: () => context.go('/citizen/requests/${r['id']}')))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/citizen/submit'),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, value;
  final VoidCallback onTap;
  const _StatCard({required this.icon, required this.iconColor, required this.title, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: iconColor.withOpacity(0.12), child: Icon(icon, color: iconColor, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ])),
          ]),
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}

class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;
  const _RequestTile({required this.request, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? 'Pending';
    final cat = request['categoryName'] ?? '';
    final addr = request['address'] ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.1), child: const Icon(Icons.delete_outline, color: AppTheme.primary)),
        title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(addr, overflow: TextOverflow.ellipsis),
        trailing: StatusBadge(status: status, small: true),
      ),
    );
  }
}
