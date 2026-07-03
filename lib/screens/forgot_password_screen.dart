import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/glass.dart';

/// Sends a Firebase password-reset email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _auth = AuthService();

  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    final error = await _auth.sendPasswordReset(_emailController.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      _sent = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text('Reset password'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: _sent
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mark_email_read, size: 64),
                          const SizedBox(height: 16),
                          Text('Check your email',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'We sent a password-reset link to '
                            '${_emailController.text.trim()}.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back to login'),
                          ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_reset, size: 64),
                            const SizedBox(height: 8),
                            Text(
                              "Enter your email and we'll send you a reset link.",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Enter your email'
                                      : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(_error!,
                                  style: TextStyle(
                                      color: theme.colorScheme.error)),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _sending ? null : _send,
                                child: _sending
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Send reset link'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
