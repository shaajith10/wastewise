import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class ManageCollectorsScreen extends StatefulWidget {
  const ManageCollectorsScreen({super.key});

  @override
  State<ManageCollectorsScreen> createState() => _ManageCollectorsScreenState();
}

class _ManageCollectorsScreenState extends State<ManageCollectorsScreen> {
  List<Map<String, dynamic>> _collectors = [];
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
      final data = await ApiClient.get('/collectors');
      _collectors = List<Map<String, dynamic>>.from(data['collectors'] ?? []);
    } catch (e) {
      _error = 'Failed to load collectors list.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showAddCollectorDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController(text: 'Truck');
    final numCtrl = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register New Collector'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Collector Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                TextFormField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                TextFormField(
                  controller: vehicleCtrl,
                  decoration: const InputDecoration(labelText: 'Vehicle Type (e.g. Truck, Van)'),
                ),
                TextFormField(
                  controller: numCtrl,
                  decoration: const InputDecoration(labelText: 'Vehicle License Plate'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiClient.post('/collectors', {
                  'email': emailCtrl.text.trim(),
                  'password': passCtrl.text,
                  'displayName': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'vehicleType': vehicleCtrl.text.trim(),
                  'vehicleNumber': numCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collector account created successfully!'), backgroundColor: AppTheme.success));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Waste Collectors')),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
        : _collectors.isEmpty
          ? EmptyStateWidget(
              icon: Icons.local_shipping_outlined,
              title: 'No collectors registered',
              subtitle: 'Click below to register authorized waste collectors.',
              actionLabel: 'Register Collector',
              onAction: _showAddCollectorDialog,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _collectors.length,
                itemBuilder: (_, i) {
                  final c = _collectors[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.local_shipping, color: AppTheme.primary),
                      ),
                      title: Text(c['displayName'] ?? 'Collector', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${c['email'] ?? ""}\nVehicle: ${c['vehicleType'] ?? "N/A"} (${c['vehicleNumber'] ?? "No Plate"})'),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCollectorDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Collector'),
      ),
    );
  }
}
