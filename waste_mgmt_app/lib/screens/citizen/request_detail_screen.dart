import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/api_client.dart';
import '../../core/request_actions.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_badge.dart';

const _statusOrder = ['Pending', 'Assigned', 'Accepted', 'Collected', 'Verified', 'Completed'];

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});
  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  Map<String, dynamic>? _request;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('/pickup-requests/${widget.requestId}');
      _request = data['request'] as Map<String, dynamic>?;
    } catch (e) {
      _error = 'Could not load request details.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancel() async {
    if (await confirmCancelRequest(context, widget.requestId) && mounted) {
      context.go('/citizen/requests');
    }
  }

  bool get _canCancel => cancellableStatuses.contains(_request?['status']);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Request Details'),
      actions: _canCancel
        ? [IconButton(onPressed: _cancel, icon: const Icon(Icons.cancel_outlined), tooltip: 'Cancel Request')]
        : null,
    ),
    body: _loading ? const LoadingWidget()
      : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
      : RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: _buildContent(),
          ),
        ),
  );

  Widget _buildContent() {
    final r = _request!;
    final status = r['status'] as String? ?? 'Pending';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Tracker
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  StatusBadge(status: status),
                ]),
                const SizedBox(height: 16),
                _StatusStepper(currentStatus: status),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Details
        _detailCard('Waste Details', [
          _row(Icons.category_outlined, 'Category', r['categoryName'] ?? ''),
          _row(Icons.scale, 'Quantity', '${r['quantityKg'] ?? '?'} kg'),
          if ((r['description'] ?? '').isNotEmpty) _row(Icons.notes, 'Description', r['description']),
        ]),
        const SizedBox(height: 8),
        _detailCard('Pickup Location', [
          _row(Icons.location_on_outlined, 'Address', r['address'] ?? ''),
          if (r['collectorName'] != null) _row(Icons.person_outlined, 'Collector', r['collectorName']),
        ]),
        const SizedBox(height: 8),
        // QR button if status warrants it
        if (['Pending', 'Assigned', 'Accepted', 'Collected'].contains(status)) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_2, color: AppTheme.primary, size: 32),
              title: const Text('Show QR Code', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Collector scans this to verify collection'),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.primary),
              onTap: () => context.go('/citizen/requests/${widget.requestId}/qr'),
            ),
          ),
          const SizedBox(height: 12),
          // 1-Click Verification Demo Button
          Card(
            color: const Color(0xFFE8F5E9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF81C784))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xFFF57F17), size: 22),
                      SizedBox(width: 8),
                      Text('Demo Collector Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Simulate waste collection & instantly credit your reward points without switching devices:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Complete Pickup & Credit Points Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _simulateCollectorVerify,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_canCancel) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Future<void> _simulateCollectorVerify() async {
    final qty = (_request?['quantityKg'] as num?)?.toDouble() ?? 5.0;
    final category = _request?['categoryName'] ?? 'Recyclable Waste';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFFF57F17)),
            SizedBox(width: 8),
            Text('Verify & Credit Points'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm collection of $qty kg of $category.'),
            const SizedBox(height: 10),
            const Text('This will complete the request and immediately credit reward points to your wallet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Award Points'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final res = await ApiClient.post('/qr/verify', {
        'token': widget.requestId,
        'actualWeightKg': qty,
      });

      if (mounted) Navigator.pop(context); // close progress

      final pts = res['pointsAwarded'] ?? 0;

      // Sync wallet
      await context.read<AuthProvider>().refreshProfile();
      await _load();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.stars, color: Color(0xFFF57F17), size: 48),
                ),
                const SizedBox(height: 16),
                const Text('🎉 Pickup Completed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('+$pts Reward Points', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.success)),
                const SizedBox(height: 8),
                const Text('Points have been credited directly to your Eco-Wallet!', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.go('/citizen/rewards');
                        },
                        child: const Text('View Wallet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Widget _detailCard(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Divider(height: 20),
          ...children,
        ],
      ),
    ),
  );

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.primary),
      const SizedBox(width: 10),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

class _StatusStepper extends StatelessWidget {
  final String currentStatus;
  const _StatusStepper({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    if (currentStatus == 'Cancelled') {
      return const Center(child: Chip(label: Text('Request Cancelled'), backgroundColor: Color(0xFFEEEEEE)));
    }
    final currentIdx = _statusOrder.indexOf(currentStatus);
    return Row(
      children: _statusOrder.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        final done = i <= currentIdx;
        final active = i == currentIdx;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: done ? AppTheme.primary : Colors.grey.shade300,
                    child: active
                      ? const Icon(Icons.circle, size: 10, color: Colors.white)
                      : done
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(s, style: TextStyle(fontSize: 8, fontWeight: done ? FontWeight.w700 : FontWeight.normal, color: done ? AppTheme.primary : Colors.grey)),
                ],
              ),
              if (i < _statusOrder.length - 1)
                Expanded(child: Container(height: 2, color: i < currentIdx ? AppTheme.primary : Colors.grey.shade300, margin: const EdgeInsets.only(bottom: 16))),
            ],
          ),
        );
      }).toList(),
    );
  }
}
