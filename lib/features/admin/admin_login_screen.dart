import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/official_service.dart';
import '../../shared/widgets/primary_button.dart';
import '../onboarding/auth/auth_common.dart';

/// Prajadhwani Admin sign-in (email + password). Admin rights are granted
/// only by `functions/src/scripts/makeAdmin.ts` — any other account that
/// signs in here is signed straight back out.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await OfficialService().signInWithEmail(_email.text, _password.text);
      final role = (await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get())
          .data()?['role'];
      if (!mounted) return;
      if (role != 'admin') {
        await AuthService().signOut();
        setState(() {
          _loading = false;
          _error = 'This account is not a Prajadhwani admin.';
        });
        return;
      }
      context.go('/admin');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not sign in. Check your email and password.';
      });
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await OfficialService().sendPasswordReset(email);
      setState(() {
        _error = null;
        _info = 'If $email has an account, a reset link is on its way.';
      });
    } catch (_) {
      setState(() => _error = 'Could not send the reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Prajadhwani Admin',
      subtitle: 'Platform administration: approve officials and monitor the '
          'whole state.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Admin email',
                prefixIcon: Icon(Icons.admin_panel_settings_rounded),
              ),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _password,
              label: 'Password',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _forgot, child: const Text('Forgot password?')),
            ),
            if (_info != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tealMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_info!,
                    style: const TextStyle(color: AppColors.tealDeep)),
              ),
            if (_error != null) AuthErrorBanner(_error!),
            PrimaryButton(
              label: 'Sign in',
              icon: Icons.login_rounded,
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
