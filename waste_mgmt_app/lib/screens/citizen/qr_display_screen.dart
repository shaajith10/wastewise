import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class QrDisplayScreen extends StatefulWidget {
  final String requestId;
  const QrDisplayScreen({super.key, required this.requestId});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  Map<String, dynamic>? _request;
  bool _loading = true;
  String? _error;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Poll so the citizen sees "Verified" as soon as the collector scans.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    final wasVerified = _request?['qrVerified'] == true;
    try {
      final data = await ApiClient.get('/pickup-requests/${widget.requestId}');
      _request = data['request'] as Map<String, dynamic>?;
    } catch (e) {
      // A failed background poll keeps the QR on screen; only report on manual refresh.
      if (!silent) _error = 'Failed to load QR code.';
    }
    if (!mounted) return;

    final justVerified = _request?['qrVerified'] == true && !wasVerified && _request != null;
    if (_request?['qrVerified'] == true) {
      _pollTimer?.cancel();
      if (!wasVerified) context.read<AuthProvider>().refreshProfile(); // pull new points balance
    }
    setState(() => _loading = false);

    // Only auto-leave when verification happens while this page is open (from the
    // 10s poll), not when opening an already-verified request's QR page.
    if (justVerified && silent) _leaveAfterVerified();
  }

  Future<void> _leaveAfterVerified() async {
    await Future.delayed(const Duration(seconds: 2)); // let the "Verified" message be seen
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.go('/citizen/requests');
    messenger.showSnackBar(const SnackBar(
      content: Text('🎉 Pickup verified! Reward points added to your wallet.'),
      backgroundColor: AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final qrToken = _request?['qrToken'] as String? ?? widget.requestId;
    final catName = _request?['categoryName'] ?? 'Pickup';
    final status = _request?['status'] ?? '';
    final verified = _request?['qrVerified'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Collection Verification QR')),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorStateWidget(message: _error!, onRetry: _load)
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          catName,
                          style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (verified) ...[
                        const Icon(Icons.check_circle, color: AppTheme.success, size: 80),
                        const SizedBox(height: 12),
                        const Text('Collection Verified!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        const SizedBox(height: 8),
                        const Text('Reward points have been credited to your account.', textAlign: TextAlign.center),
                      ] else ...[
                        QrImageView(
                          data: qrToken,
                          version: QrVersions.auto,
                          size: 240,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.primaryDark),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppTheme.primaryDark),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Show this QR code to the collector',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: $status',
                          style: TextStyle(color: AppTheme.statusColor(status), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Status updates automatically every 10 seconds',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The collector will scan this code to confirm collection and release your reward points.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Refresh Status'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
