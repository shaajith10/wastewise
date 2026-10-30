import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  double _totalKg = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('/admin/activity');
      _records = List<Map<String, dynamic>>.from(data['activities'] ?? []);
      _totalKg = _records.fold(0.0, (sum, r) => sum + ((r['quantityKg'] as num?)?.toDouble() ?? 0.0));
      _totalPoints = _records.fold(0, (sum, r) => sum + ((r['pointsAwarded'] as num?)?.toInt() ?? 0));
    } catch (e) {
      _error = 'Failed to load activity reports.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recycling Reports & Analytics')),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total Recycled', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${_totalKg.toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(height: 36, width: 1, color: Colors.white30),
                    Column(
                      children: [
                        const Text('Points Distributed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('$_totalPoints pts', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _records.isEmpty
                  ? const EmptyStateWidget(icon: Icons.bar_chart, title: 'No activity records found')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _records.length,
                        itemBuilder: (_, i) {
                          final r = _records[i];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F5E9),
                                child: Icon(Icons.verified, color: AppTheme.success),
                              ),
                              title: Text('${r['categoryName'] ?? "Waste"} (${r['quantityKg']} kg)', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Citizen: ${r['citizenId'] ?? "N/A"}\nCollector: ${r['collectorId'] ?? "N/A"}'),
                              trailing: Text('+${r['pointsAwarded'] ?? 0} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 15)),
                              isThreeLine: true,
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
