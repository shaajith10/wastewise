import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false, _sent = false;

  Future<void> _send() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().sendPasswordReset(_emailCtrl.text.trim());
      setState(() { _sent = true; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    }
  }

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset Password'), backgroundColor: Colors.transparent, foregroundColor: AppTheme.primaryDark, elevation: 0),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: _sent
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read_outlined, color: AppTheme.primary, size: 72),
              const SizedBox(height: 16),
              const Text('Email sent!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Check your inbox at ${_emailCtrl.text} for reset instructions.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Back to Login')),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the email address associated with your account:', style: TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary)),
              ),
              const SizedBox(height: 24),
              _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary)) : ElevatedButton(onPressed: _send, child: const Text('Send Reset Email')),
            ],
          ),
    ),
  );
}
