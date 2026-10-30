import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/request_actions.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_badge.dart';

class ManageRequestsScreen extends StatefulWidget {
  const ManageRequestsScreen({super.key});

  @override
  State<ManageRequestsScreen> createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _collectors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reqRes = await ApiClient.get('/pickup-requests');
      _requests = List<Map<String, dynamic>>.from(reqRes['requests'] ?? []);
      final colRes = await ApiClient.get('/collectors');
      _collectors = List<Map<String, dynamic>>.from(colRes['collectors'] ?? []);
    } catch (e) {
      _error = 'Failed to load requests or collectors list.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _assignCollector(String requestId) async {
    if (_collectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No collectors available. Add collectors first.')));
      return;
    }

    Map<String, dynamic>? selectedCollector;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Assign Collector'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select an authorized collector for this request:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedCollector,
                hint: const Text('Choose Collector'),
                items: _collectors.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text('${c['displayName'] ?? c['email']} (${c['vehicleType'] ?? "Vehicle"})'),
                  );
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedCollector = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)), // theme default is full-width
              onPressed: selectedCollector == null ? null : () => Navigator.pop(ctx, selectedCollector),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    try {
      await ApiClient.post('/pickup-requests/$requestId/assign', {
        'collectorUid': result['uid'] ?? result['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned to ${result['displayName']}'), backgroundColor: AppTheme.success));
        _loadData();
      }
    } catch (e) {
      final msg = e is ApiException ? e.message : '$e';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    if (await confirmCancelRequest(context, requestId)) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Pickup Requests')),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _loadData)
        : _requests.isEmpty
          ? const EmptyStateWidget(icon: Icons.inbox, title: 'No pickup requests found')
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _requests.length,
                itemBuilder: (_, i) {
                  final r = _requests[i];
                  final status = r['status'] ?? 'Pending';
                  final collectorName = r['collectorName'];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(r['categoryName'] ?? 'Waste', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              StatusBadge(status: status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Citizen: ${r['citizenName'] ?? "N/A"}  •  ${r['quantityKg']} kg'),
                          Text('Address: ${r['address'] ?? ""}'),
                          if (collectorName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Assigned Collector: $collectorName', style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
                            ),
                          const SizedBox(height: 10),
                          if (cancellableStatuses.contains(status))
                            Row(
                              children: [
                                if (status == 'Pending') ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _assignCollector(r['id']),
                                      icon: const Icon(Icons.person_add, size: 18),
                                      label: const Text('Assign Collector'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.error,
                                      side: const BorderSide(color: AppTheme.error),
                                    ),
                                    onPressed: () => _cancelRequest(r['id']),
                                    icon: const Icon(Icons.cancel_outlined, size: 18),
                                    label: const Text('Cancel Request'),
                                  ),
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
    );
  }
}
