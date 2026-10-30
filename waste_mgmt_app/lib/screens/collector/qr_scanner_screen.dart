import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final _manualTokenCtrl = TextEditingController();

  bool _verifying = false;
  bool _manualMode = false;
  String? _resultMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyToken(String token) async {
    if (_verifying || token.isEmpty) return;
    setState(() {
      _verifying = true;
      _resultMessage = null;
    });

    try {
      final res = await ApiClient.post('/qr/verify', {'qrToken': token.trim()});
      final alreadyDone = res['alreadyAwarded'] == true && res['points'] == null;
      final message = alreadyDone
          ? 'This pickup was already verified.'
          : 'Awarded ${res['points'] ?? 0} reward points to citizen.';
      setState(() {
        _isSuccess = true;
        _resultMessage = '✅ Verification Successful!\n$message';
      });
      _goToTasks('✅ Pickup verified! $message');
    } on ApiException catch (e) {
      setState(() {
        _isSuccess = false;
        _resultMessage = '❌ Verification Failed:\n${e.message}';
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _resultMessage = '❌ Verification Error:\n$e';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// After a successful scan, show the result briefly, then return to the task list.
  Future<void> _goToTasks(String snackText) async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.go('/collector');
    messenger.showSnackBar(SnackBar(content: Text(snackText), backgroundColor: AppTheme.success));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify QR Code'),
        actions: [
          IconButton(
            icon: Icon(_manualMode ? Icons.camera_alt : Icons.keyboard),
            tooltip: _manualMode ? 'Switch to Camera' : 'Manual Entry',
            onPressed: () => setState(() => _manualMode = !_manualMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_resultMessage != null) ...[
              Card(
                color: _isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error,
                        color: _isSuccess ? AppTheme.success : AppTheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _resultMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isSuccess ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _resultMessage = null),
                        child: const Text('Scan Another QR'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (_manualMode) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Manual QR Token Input', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Use this mode for testing or if camera is unavailable.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _manualTokenCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Paste QR token or request ID here...',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _verifying
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                        : ElevatedButton.icon(
                            onPressed: () => _verifyToken(_manualTokenCtrl.text),
                            icon: const Icon(Icons.verified),
                            label: const Text('Submit Verification'),
                          ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 320,
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _verifyToken(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Align Citizen QR code within the frame to verify collection.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _manualMode = true),
                icon: const Icon(Icons.keyboard),
                label: const Text('Switch to Manual Token Entry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
