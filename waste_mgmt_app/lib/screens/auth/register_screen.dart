import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl, _confirmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        displayName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Registration failed'), backgroundColor: AppTheme.error),
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
      appBar: AppBar(title: const Text('Create Account'), backgroundColor: Colors.transparent, foregroundColor: AppTheme.primaryDark, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('Full Name', _nameCtrl, Icons.person_outline, hint: 'John Smith',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
                        const SizedBox(height: 16),
                        _field('Email', _emailCtrl, Icons.email_outlined, hint: 'you@example.com', type: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
                        const SizedBox(height: 16),
                        _field('Phone Number', _phoneCtrl, Icons.phone_outlined, hint: '98765 43210', type: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Phone number is required';
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 10 || digits.length > 13) return 'Enter a valid 10-digit phone number';
                            return null;
                          }),
                        const SizedBox(height: 16),
                        _label('Password'),
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
                          validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                        ),
                        const SizedBox(height: 16),
                        _field('Confirm Password', _confirmCtrl, Icons.lock_outline, hint: '••••••••', obscure: true,
                          validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null),
                        const SizedBox(height: 24),
                        _loading
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                          : ElevatedButton(onPressed: _register, child: const Text('Create Account')),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Sign In')),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Citizens self-register. Collectors and Admins are set up by the administrator.', style: TextStyle(fontSize: 12, color: AppTheme.primaryDark))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryDark));

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    String? hint,
    TextInputType? type,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primary),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
