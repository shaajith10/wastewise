import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/api_client.dart';
import '../../core/request_actions.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_badge.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _availableRequests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final myUid = auth.uid;

      final data = await ApiClient.get('/pickup-requests');
      final allRequests = List<Map<String, dynamic>>.from(data['requests'] ?? []);

      _myTasks = allRequests.where((t) => t['collectorUid'] == myUid).toList();
      _availableRequests = allRequests.where((t) => t['status'] == 'Pending').toList();
    } catch (e) {
      _error = 'Failed to load collection tasks: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _claimTask(String requestId) async {
    try {
      await ApiClient.post('/pickup-requests/$requestId/claim', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pickup task claimed! Citizen notified.'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not claim task: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final activeCount = _myTasks.where((t) => t['status'] != 'Completed' && t['status'] != 'Cancelled').length;
    final completedCount = _myTasks.where((t) => t['status'] == 'Completed').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Collector Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Citizen QR',
            onPressed: () => context.go('/collector/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showConfirmDialog(context, title: 'Sign Out', message: 'Sign out of collector portal?', danger: true);
              if (confirm && mounted) {
                await context.read<AuthProvider>().logout();
                if (mounted) context.go('/login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.assignment), text: 'My Tasks ($activeCount)'),
            Tab(icon: const Icon(Icons.near_me), text: 'Available Nearby (${_availableRequests.length})'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            // Header stats banner
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.primary,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.local_shipping, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.displayName ?? 'Authorized Collector', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('$activeCount Active Collections • $completedCount Verified & Completed', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(60, 36),
                    ),
                    onPressed: () => context.go('/collector/scan'),
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Scan QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Tab view
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: My Tasks
                  _loading
                    ? const LoadingWidget(message: 'Loading your assigned tasks...')
                    : _error != null
                      ? ErrorStateWidget(message: _error!, onRetry: _load)
                      : _myTasks.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.assignment_turned_in_outlined,
                            title: 'No active tasks',
                            subtitle: 'Check the "Available Nearby" tab to claim new pickup requests from citizens.',
                            actionLabel: 'View Available Requests',
                            onAction: () => _tabController.animateTo(1),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _myTasks.length,
                            itemBuilder: (_, i) => _TaskCard(
                              task: _myTasks[i],
                              onRefresh: _load,
                              isAssigned: true,
                              onCancel: () async {
                                if (await confirmReleaseTask(context, _myTasks[i]['id'])) _load();
                              },
                            ),
                          ),

                  // Tab 2: Available Community Requests
                  _loading
                    ? const LoadingWidget(message: 'Searching for nearby requests...')
                    : _availableRequests.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.check_circle_outline,
                          title: 'All caught up!',
                          subtitle: 'There are currently no unclaimed pickup requests in the community.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _availableRequests.length,
                          itemBuilder: (_, i) => _TaskCard(
                            task: _availableRequests[i],
                            onRefresh: _load,
                            isAssigned: false,
                            onClaim: () => _claimTask(_availableRequests[i]['id']),
                            onCancel: () async {
                              if (await confirmCancelUnclaimedRequest(context, _availableRequests[i]['id'])) _load();
                            },
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onRefresh;
  final bool isAssigned;
  final VoidCallback? onClaim;
  final VoidCallback? onCancel;

  const _TaskCard({
    required this.task,
    required this.onRefresh,
    required this.isAssigned,
    this.onClaim,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = task['status'] ?? 'Pending';
    final cat = task['categoryName'] ?? 'Waste';
    final qty = task['quantityKg'] ?? 0;
    final address = task['address'] ?? '';
    final citizen = task['citizenName'] ?? 'Citizen';
    final isDone = status == 'Completed' || status == 'Verified';
    final isCancelled = status == 'Cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: const Icon(Icons.recycling, color: AppTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Citizen: $citizen', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              const Icon(Icons.scale, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('$qty kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(address, style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 14),

            // Action Buttons
            if (!isAssigned) ...[
              ElevatedButton.icon(
                onPressed: onClaim,
                icon: const Icon(Icons.near_me, size: 18),
                label: const Text('Accept & Pick Up Request'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Request'),
                ),
              ],
            ] else if (isCancelled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_outlined, color: Colors.grey, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      task['cancelledBy'] == 'admin' ? 'Cancelled by admin' : 'Cancelled by citizen',
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ] else if (isDone) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                    SizedBox(width: 6),
                    Text('Verified & Rewarded', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/collector/tasks/${task['id']}'),
                      child: const Text('Details'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/collector/scan'),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Verify QR'),
                    ),
                  ),
                ],
              ),
              if (onCancel != null && releasableStatuses.contains(status))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Pickup'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
