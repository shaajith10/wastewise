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

  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('/recycling-records');
      _records = List<Map<String, dynamic>>.from(data['records'] ?? []);
      _recalculateTotals();
    } catch (e) {
      _error = 'Failed to load recycling reports.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _recalculateTotals() {
    final visible = _visibleRecords;
    _totalKg = visible.fold(0.0, (sum, r) => sum + ((r['quantityKg'] as num?)?.toDouble() ?? 0.0));
    _totalPoints = visible.fold(0, (sum, r) => sum + ((r['points'] as num?)?.toInt() ?? 0));
  }

  List<Map<String, dynamic>> get _visibleRecords {
    if (_categoryFilter == null) return _records;
    return _records.where((r) => r['categoryName'] == _categoryFilter).toList();
  }

  List<String> get _availableCategories {
    final set = _records.map((r) => r['categoryName'] as String?).whereType<String>().toSet().toList();
    set.sort();
    return set;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    final str = date.toString();
    return str.length >= 10 ? str.substring(0, 10) : str;
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Remove This Record?',
      message: 'This only removes it from the report. ${record['citizenName'] ?? 'The citizen'} keeps the ${record['points'] ?? 0} points already awarded — this does not touch their wallet.',
      confirmLabel: 'Remove from Report',
      dismissLabel: 'Keep',
      danger: true,
    );
    if (!confirm || !mounted) return;

    try {
      await ApiClient.delete('/recycling-records/${record['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record removed from the report.'), backgroundColor: AppTheme.success),
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
    final visible = _visibleRecords;
    _recalculateTotals();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycling Reports & Analytics'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
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
                    Container(height: 36, width: 1, color: Colors.white30),
                    Column(
                      children: [
                        const Text('Records', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${visible.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              if (_availableCategories.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All'),
                          selected: _categoryFilter == null,
                          onSelected: (_) => setState(() => _categoryFilter = null),
                        ),
                      ),
                      for (final cat in _availableCategories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: _categoryFilter == cat,
                            onSelected: (_) => setState(() => _categoryFilter = cat),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: visible.isEmpty
                  ? const EmptyStateWidget(icon: Icons.bar_chart, title: 'No recycling records found')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: visible.length,
                        itemBuilder: (_, i) {
                          final r = visible[i];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F5E9),
                                child: Icon(Icons.verified, color: AppTheme.success),
                              ),
                              title: Text('${r['categoryName'] ?? "Waste"} — ${r['quantityKg']} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Citizen: ${r['citizenName'] ?? "Citizen"}\nCollector: ${r['collectorName'] ?? "Collector"} • ${_formatDate(r['verifiedAt'])}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r['points'] != null ? '+${r['points']} pts' : '— pts',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 15),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                    tooltip: 'Remove from report',
                                    onPressed: () => _deleteRecord(r),
                                  ),
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
