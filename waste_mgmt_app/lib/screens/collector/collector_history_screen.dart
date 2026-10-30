import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_badge.dart';

class CollectorHistoryScreen extends StatefulWidget {
  const CollectorHistoryScreen({super.key});

  @override
  State<CollectorHistoryScreen> createState() => _CollectorHistoryScreenState();
}

class _CollectorHistoryScreenState extends State<CollectorHistoryScreen> {
  List<Map<String, dynamic>> _completed = [];
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
      final data = await ApiClient.get('/pickup-requests');
      final all = List<Map<String, dynamic>>.from(data['requests'] ?? []);
      _completed = all.where((t) => ['Verified', 'Completed'].contains(t['status'])).toList();
    } catch (e) {
      _error = 'Failed to load completed collections.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection History')),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
        : _completed.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.history,
              title: 'No completed collections',
              subtitle: 'Verified collections will be recorded here.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _completed.length,
                itemBuilder: (_, i) {
                  final t = _completed[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.verified, color: AppTheme.success),
                      ),
                      title: Text(t['categoryName'] ?? 'Waste', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Citizen: ${t['citizenName'] ?? "N/A"}\n${t['address'] ?? ""}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(status: t['status'] ?? 'Verified', small: true),
                          const SizedBox(height: 4),
                          Text('${t['quantityKg']} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
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
