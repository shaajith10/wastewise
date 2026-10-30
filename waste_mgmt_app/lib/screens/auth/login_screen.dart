import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _navigateToDashboard(String? role) {
    if (!mounted) return;
    switch (role) {
      case 'collector':
        context.go('/collector');
        break;
      case 'admin':
        context.go('/admin');
        break;
      default:
        context.go('/citizen');
        break;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted && auth.isLoggedIn) {
        _navigateToDashboard(auth.role);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Login failed'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editServerAddress() async {
    final ctrl = TextEditingController(
      text: ApiClient.baseUrl.replaceFirst(RegExp(r'/api$'), ''),
    );
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Laptop's Wi-Fi IP and port, e.g. http://192.168.1.5:3000", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: ctrl, keyboardType: TextInputType.url, autofocus: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    await ApiClient.setServerOverride(url);
    if (!mounted) return;
    setState(() {});

    final ok = await ApiClient.ping();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Connected to ${ApiClient.baseUrl}' : '❌ Cannot reach ${ApiClient.baseUrl} — same Wi-Fi? server running?'),
      backgroundColor: ok ? AppTheme.success : AppTheme.error,
    ));
  }

  Future<void> _quickDemoLogin(String role) async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.demoLogin(role: role);
      if (mounted && auth.isLoggedIn) {
        _navigateToDashboard(role);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Login failed'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),
              // Logo
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.recycling, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('WasteWise', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
              ),
              const SizedBox(height: 4),
              Center(child: Text('Sign in to your account', style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
              const SizedBox(height: 28),
              // Form
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryDark)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                          ),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 14),
                        const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryDark)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            child: const Text('Forgot password?', style: TextStyle(color: AppTheme.primary)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _loading
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                          : ElevatedButton(onPressed: _login, child: const Text('Sign In')),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Quick Demo Sign In
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text('⚡ Quick Demo Login (Select Role)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: _loading ? null : () => _quickDemoLogin('citizen'),
                            child: const Text('👤 Citizen', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: _loading ? null : () => _quickDemoLogin('collector'),
                            child: const Text('🚛 Collector', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: _loading ? null : () => _quickDemoLogin('admin'),
                            child: const Text('⚙️ Admin', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    const Text('Default logins', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 6),
                    for (final entry in demoAccounts.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          '${entry.key[0].toUpperCase()}${entry.key.substring(1)}:  ${entry.value.email}  /  ${entry.value.password}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text('Register', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _editServerAddress,
                  icon: const Icon(Icons.dns_outlined, size: 16),
                  label: Text('Server: ${ApiClient.baseUrl}', style: const TextStyle(fontSize: 12)),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
