import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_badge.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'All';

  final _statuses = ['All', 'Pending', 'Assigned', 'Accepted', 'Collected', 'Verified', 'Completed', 'Cancelled'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final url = _statusFilter == 'All' ? '/pickup-requests' : '/pickup-requests?status=$_statusFilter';
      final data = await ApiClient.get(url);
      _requests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
    } catch (e) {
      _error = 'Failed to load requests.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Requests')),
    body: Column(
      children: [
        // Filter chips
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _statuses.length,
            itemBuilder: (_, i) {
              final s = _statuses[i];
              final selected = s == _statusFilter;
              return FilterChip(
                selected: selected,
                label: Text(s),
                selectedColor: AppTheme.primary.withOpacity(0.15),
                checkmarkColor: AppTheme.primary,
                onSelected: (_) { setState(() => _statusFilter = s); _load(); },
              );
            },
          ),
        ),
        Expanded(
          child: _loading ? const LoadingWidget()
            : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
            : _requests.isEmpty
              ? EmptyStateWidget(icon: Icons.inbox_outlined, title: 'No $_statusFilter requests', subtitle: 'Pull to refresh or submit a new request.')
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _requests.length,
                  itemBuilder: (_, i) => _RequestCard(request: _requests[i]),
                ),
              ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.go('/citizen/submit'),
      icon: const Icon(Icons.add),
      label: const Text('New Request'),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? 'Pending';
    final cat = request['categoryName'] ?? '';
    final qty = request['quantityKg'];
    final addr = request['address'] ?? '';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () => context.go('/citizen/requests/${request['id']}'),
        leading: CircleAvatar(
          backgroundColor: AppTheme.statusColor(status).withOpacity(0.12),
          child: Icon(Icons.delete_outline, color: AppTheme.statusColor(status)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w700))),
            StatusBadge(status: status, small: true),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$qty kg  •  $addr', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.primary),
      ),
    );
  }
}
