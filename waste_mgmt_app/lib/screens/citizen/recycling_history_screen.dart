import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class RecyclingHistoryScreen extends StatefulWidget {
  const RecyclingHistoryScreen({super.key});

  @override
  State<RecyclingHistoryScreen> createState() => _RecyclingHistoryScreenState();
}

class _RecyclingHistoryScreenState extends State<RecyclingHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  double _totalKg = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch verified requests or recycling records
      final data = await ApiClient.get('/pickup-requests?status=Verified');
      _records = List<Map<String, dynamic>>.from(data['requests'] ?? []);
      _totalKg = _records.fold(0.0, (sum, r) => sum + ((r['quantityKg'] as num?)?.toDouble() ?? 0.0));
    } catch (e) {
      _error = 'Failed to load recycling history.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recycling History')),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
        : Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primary]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.eco, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Recycled', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('${_totalKg.toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _records.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.history,
                      title: 'No recycling records yet',
                      subtitle: 'Complete verified pickup requests to build your recycling history.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _records.length,
                        itemBuilder: (_, i) {
                          final r = _records[i];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F5E9),
                                child: Icon(Icons.recycling, color: AppTheme.primary),
                              ),
                              title: Text(r['categoryName'] ?? 'Recycling', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(r['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${r['quantityKg']} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                                  const Text('Verified', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ),
            ],
          ),
    );
  }
}
