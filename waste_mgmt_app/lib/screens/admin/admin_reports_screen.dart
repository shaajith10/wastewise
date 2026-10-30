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

  Future<void> _addRecord() async {
    List<Map<String, dynamic>> citizens;
    List<Map<String, dynamic>> categories;
    try {
      final usersData = await ApiClient.get('/admin/users');
      citizens = List<Map<String, dynamic>>.from(usersData['users'] ?? [])
          .where((u) => u['role'] == 'citizen').toList();
      final catData = await ApiClient.get('/admin/categories');
      categories = List<Map<String, dynamic>>.from(catData['categories'] ?? []);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load citizens/categories.'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }
    if (!mounted) return;

    if (citizens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No citizen accounts exist yet — add one in Manage Users first.')),
      );
      return;
    }
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No waste categories exist yet — add one in Manage Categories first.')),
      );
      return;
    }

    Map<String, dynamic>? selectedCitizen = citizens.first;
    Map<String, dynamic>? selectedCategory = categories.first;
    DateTime selectedDate = DateTime.now();
    final qtyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Recycling Record'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedCitizen,
                    decoration: const InputDecoration(labelText: 'Citizen'),
                    isExpanded: true,
                    items: citizens.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c['displayName'] ?? c['email'] ?? 'Citizen', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedCitizen = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Waste Category'),
                    isExpanded: true,
                    items: categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c['name'] ?? 'Category'));
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategory = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (kg)', suffixText: 'kg'),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a weight greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date Recycled'),
                    subtitle: Text(_formatDate(selectedDate.toIso8601String())),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reward points are calculated automatically from this category\'s rate and credited to the citizen immediately.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate() || selectedCitizen == null || selectedCategory == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add Record'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted || selectedCitizen == null || selectedCategory == null) return;

    try {
      final res = await ApiClient.post('/recycling-records', {
        'citizenUid': selectedCitizen!['uid'] ?? selectedCitizen!['id'],
        'categoryId': selectedCategory!['id'],
        'categoryName': selectedCategory!['name'],
        'quantityKg': double.parse(qtyCtrl.text),
        'verifiedAt': selectedDate.toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added! ${selectedCitizen!['displayName']} earned +${res['points']} pts.'), backgroundColor: AppTheme.success),
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
                          final isManual = r['source'] == 'manual';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isManual ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9),
                                child: Icon(isManual ? Icons.edit_note : Icons.verified, color: isManual ? Colors.blue : AppTheme.success),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text('${r['categoryName'] ?? "Waste"} — ${r['quantityKg']} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  if (isManual)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Chip(
                                        label: Text('Manual', style: TextStyle(fontSize: 10)),
                                        backgroundColor: Color(0xFFE3F2FD),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                ],
                              ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecord,
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
      ),
    );
  }
}
