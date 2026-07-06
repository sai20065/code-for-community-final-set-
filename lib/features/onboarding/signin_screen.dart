import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/current_user_profile_provider.dart';
import '../../app/providers/onboarding_progress_provider.dart';
import '../../app/theme.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/primary_button.dart';

enum _AuthMethod { phone, email }

/// Returning-citizen entry point — strict sign-in only, no account
/// creation. Distinct from `SignUpScreen`: a phone/email that doesn't
/// already have a `users/{uid}` profile with `signupCompletedAt` set is
/// treated as an error here ("no account found"), not silently turned into
/// a new signup, so the two flows never blur together.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMethod _method = _AuthMethod.phone;
  String? _verificationId;
  bool _codeSent = false;
  bool _sendingCode = false;
  bool _loading = false;
  String? _error;

  /// After any successful auth, a real account must already have a
  /// completed profile — otherwise this credential never went through Sign
  /// Up, so we sign back out and point the citizen there instead.
  Future<void> _onAuthenticated(User user) async {
    final profile = await ref.read(firestoreServiceProvider).getUser(user.uid);
    if (profile == null || profile.signupCompletedAt == null) {
      await _authService.signOut();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No account found for this — please Sign Up first.';
      });
      return;
    }
    await ref.read(onboardingProgressProvider.notifier).advanceTo(OnboardingStep.done);
    if (!mounted) return;
    if (profile.role == UserRole.official) {
      context.go('/official/dashboard');
    } else {
      context.go('/home');
    }
  }

  Future<void> _sendCode() async {
    final digits = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    await _authService.startPhoneVerification(
      phoneNumber: '+91$digits',
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _codeSent = true;
          _verificationId = verificationId;
        });
      },
      onAutoVerified: (user) async {
        if (!mounted) return;
        setState(() => _loading = true);
        await _onAuthenticated(user);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _error = message;
        });
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null || _codeController.text.trim().length < 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _authService.confirmSmsCode(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await _onAuthenticated(user);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "That code didn't match — check it and try again.";
      });
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _authService.signInWithEmail(
        email: email,
        password: _passwordController.text,
      );
      await _onAuthenticated(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.code == 'user-not-found'
            ? 'No account found for this email — please Sign Up first.'
            : 'Could not sign in — check your email and password.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not sign in — check your email and password.';
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.login_rounded, size: 56, color: AppColors.indigoMist),
              const SizedBox(height: 16),
              Text(
                'Welcome back — sign in the same way you signed up.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MethodTab(
                        label: 'Phone',
                        selected: _method == _AuthMethod.phone,
                        onTap: () => setState(() {
                          _method = _AuthMethod.phone;
                          _error = null;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _MethodTab(
                        label: 'Email',
                        selected: _method == _AuthMethod.email,
                        onTap: () => setState(() {
                          _method = _AuthMethod.email;
                          _error = null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_method == _AuthMethod.phone) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('+91'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        enabled: !_codeSent,
                        decoration: const InputDecoration(hintText: '10-digit mobile number', counterText: ''),
                      ),
                    ),
                  ],
                ),
                if (!_codeSent) ...[
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Send code',
                    icon: Icons.sms_rounded,
                    loading: _sendingCode,
                    onPressed: _sendingCode ? null : _sendCode,
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(hintText: '6-digit code', counterText: ''),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Verify & sign in',
                    icon: Icons.check_circle_rounded,
                    loading: _loading,
                    onPressed: _loading ? null : _verifyCode,
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email address'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Password'),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Sign in',
                  icon: Icons.login_rounded,
                  loading: _loading,
                  onPressed: _loading ? null : _signInWithEmail,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
