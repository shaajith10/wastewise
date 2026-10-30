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
  Map<String, dynamic>? _rules;
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
      final data = await ApiClient.get('/admin/reward-rules');
      _rules = data['rules'] as Map<String, dynamic>?;
    } catch (e) {
      _error = 'Failed to load reward rules.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showEditRuleDialog(String key, num currentVal) async {
    final ctrl = TextEditingController(text: '$currentVal');
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Rule: $key'),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Points per KG'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final n = num.tryParse(ctrl.text);
              if (n != null) Navigator.pop(ctx, n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final updatedRules = Map<String, dynamic>.from(_rules ?? {});
      updatedRules[key] = result;
      try {
        await ApiClient.post('/admin/reward-rules', {'rules': updatedRules});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reward rule updated!'), backgroundColor: AppTheme.success));
        _load();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reward Rules Configuration')),
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
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: (_rules ?? {}).entries.map((entry) {
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF8E1),
                          child: Icon(Icons.stars, color: Color(0xFFF57F17)),
                        ),
                        title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${entry.value} points per kg'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: AppTheme.primary),
                          onPressed: () => _showEditRuleDialog(entry.key, entry.value as num),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
    );
  }
}
