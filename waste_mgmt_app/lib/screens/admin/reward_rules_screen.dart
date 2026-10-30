import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class RewardRulesScreen extends StatefulWidget {
  const RewardRulesScreen({super.key});

  @override
  State<RewardRulesScreen> createState() => _RewardRulesScreenState();
}

class _RewardRulesScreenState extends State<RewardRulesScreen> {
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _categories = [];
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
      final rulesData = await ApiClient.get('/admin/reward-rules');
      _rules = List<Map<String, dynamic>>.from(rulesData['rules'] ?? []);
      final catData = await ApiClient.get('/admin/categories');
      _categories = List<Map<String, dynamic>>.from(catData['categories'] ?? []);
    } catch (e) {
      _error = 'Failed to load reward rules.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Categories that don't have a reward rule yet (e.g. just added in Manage Categories).
  List<Map<String, dynamic>> get _categoriesWithoutRule {
    final ruledIds = _rules.map((r) => r['categoryId']).toSet();
    return _categories.where((c) => !ruledIds.contains(c['id'])).toList();
  }

  Future<void> _editRule(Map<String, dynamic> rule) async {
    final ctrl = TextEditingController(text: '${rule['pointsPerKg'] ?? 0}');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: ${rule['categoryName']}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Points per KG', suffixText: 'pts/kg'),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n < 0) return 'Enter a valid, non-negative number';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, double.parse(ctrl.text));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    try {
      await ApiClient.patch('/admin/reward-rules/${rule['id']}', {'pointsPerKg': result});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${rule['categoryName']} is now $result pts/kg'), backgroundColor: AppTheme.success),
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

  Future<void> _addRule() async {
    final available = _categoriesWithoutRule;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every waste category already has a reward rule.')),
      );
      return;
    }

    Map<String, dynamic>? selectedCategory = available.first;
    final ctrl = TextEditingController(text: '15');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Reward Rule'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Waste Category'),
                  items: available.map((c) => DropdownMenuItem(value: c, child: Text(c['name'] ?? 'Category'))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Points per KG', suffixText: 'pts/kg'),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0) return 'Enter a valid, non-negative number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate() || selectedCategory == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add Rule'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted || selectedCategory == null) return;
    try {
      await ApiClient.post('/admin/reward-rules', {
        'categoryId': selectedCategory!['id'],
        'categoryName': selectedCategory!['name'],
        'pointsPerKg': double.parse(ctrl.text),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reward rule added!'), backgroundColor: AppTheme.success),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reward Rules Configuration'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFFFF8E1),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF57F17)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Points are multiplied by waste weight (kg) upon QR verification.', style: TextStyle(fontSize: 12, color: AppTheme.primaryDark)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _rules.isEmpty
                  ? const EmptyStateWidget(icon: Icons.stars_outlined, title: 'No reward rules yet', subtitle: 'Add one for each waste category.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: _rules.map((rule) {
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF8E1),
                                child: Icon(Icons.stars, color: Color(0xFFF57F17)),
                              ),
                              title: Text(rule['categoryName'] ?? 'Category', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${rule['pointsPerKg'] ?? 0} points per kg'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.primary),
                                onPressed: () => _editRule(rule),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRule,
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
    );
  }
}
