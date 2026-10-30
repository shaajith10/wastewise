import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/request_actions.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_badge.dart';

class TaskDetailScreen extends StatefulWidget {
  final String requestId;
  const TaskDetailScreen({super.key, required this.requestId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
  bool _loading = true;
  String? _error;
  bool _updating = false;
  final _scaleWeightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scaleWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('/pickup-requests/${widget.requestId}');
      _task = data['request'] as Map<String, dynamic>?;
      if (_task != null && _scaleWeightCtrl.text.isEmpty) {
        _scaleWeightCtrl.text = (_task!['quantityKg'] ?? '').toString();
      }
    } catch (e) {
      _error = 'Failed to load task details.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _directVerify() async {
    setState(() => _updating = true);
    try {
      final token = _task?['qrToken'] ?? widget.requestId;
      final weight = double.tryParse(_scaleWeightCtrl.text) ?? _task?['quantityKg'];

      final res = await ApiClient.post('/qr/verify', {
        'qrToken': token,
        'actualWeightKg': weight,
      });

      final points = res['points'] ?? 0;
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        context.go('/collector'); // back to the task list once verified
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Pickup verified! Awarded $points reward points to citizen.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
    if (mounted) setState(() => _updating = false);
  }

  Future<void> _releaseTask() async {
    if (await confirmReleaseTask(context, widget.requestId) && mounted) {
      context.go('/collector');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    try {
      await ApiClient.patch('/pickup-requests/${widget.requestId}/status', {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: AppTheme.success));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = _task?['status'] as String? ?? 'Pending';
    final isDone = status == 'Completed' || status == 'Verified';
    final isCancelled = status == 'Cancelled';

    return Scaffold(
      appBar: AppBar(title: const Text('Collection Task Details')),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Collection Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        StatusBadge(status: status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Citizen & Waste Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(height: 20),
                        _infoRow(Icons.person_outline, 'Citizen', _task?['citizenName'] ?? ''),
                        _infoRow(Icons.category_outlined, 'Category', _task?['categoryName'] ?? ''),
                        _infoRow(Icons.scale, 'Declared Weight', '${_task?['quantityKg']} kg'),
                        _infoRow(Icons.location_on_outlined, 'Address', _task?['address'] ?? ''),
                        if ((_task?['description'] ?? '').isNotEmpty)
                          _infoRow(Icons.notes, 'Notes', _task?['description']),
                        _infoRow(Icons.qr_code, 'Request Code', _task?['qrToken'] ?? widget.requestId),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (!isDone && !isCancelled) ...[
                  const Text('Collection Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Actual Measured Scale Weight (kg)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _scaleWeightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              hintText: 'Weight measured on collector scale',
                              prefixIcon: Icon(Icons.scale, color: AppTheme.primary),
                              suffixText: 'kg',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: _updating ? null : _directVerify,
                                  icon: const Icon(Icons.verified),
                                  label: const Text('Verify & Credit Points'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(50, 50),
                                ),
                                onPressed: () => context.go('/collector/scan'),
                                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                tooltip: 'Scan Camera QR',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (releasableStatuses.contains(status)) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _updating ? null : _releaseTask,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Pickup', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ] else if (isCancelled) ...[
                  Card(
                    color: const Color(0xFFEEEEEE),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_outlined, color: Colors.grey, size: 36),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _task?['cancelledBy'] == 'admin'
                                  ? 'This pickup was cancelled by an administrator.'
                                  : 'This pickup was cancelled by the citizen.',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Card(
                    color: const Color(0xFFE8F5E9),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: AppTheme.success, size: 36),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Collection Complete!', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('This pickup was verified and reward points were awarded to ${_task?['citizenName']}.', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
