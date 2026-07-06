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

/// Returning-citizen entry point — phone-OTP sign-in only, no account
/// creation. Distinct from `SignUpScreen`: a phone number with no matching
/// `users/{uid}` profile (`signupCompletedAt` set) is treated as an error
/// here ("no account found"), not silently turned into a new signup, so the
/// two flows never blur together. (Citizen email/password was dropped —
/// Firebase has no native email-OTP and magic-links are unreliable on a
/// sideloaded APK; officials still sign in with a constituency ID +
/// password on the Welcome screen's MP tab.)
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  bool _codeSent = false;
  bool _sendingCode = false;
  bool _loading = false;
  String? _error;

  /// After successful phone auth, a real account must already have a
  /// completed profile — otherwise this number never went through Sign Up,
  /// so we sign back out and point the citizen there instead.
  Future<void> _onAuthenticated(User user) async {
    final profile = await ref.read(firestoreServiceProvider).getUser(user.uid);
    if (profile == null || profile.signupCompletedAt == null) {
      await _authService.signOut();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No account found for this number — please Sign Up first.';
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

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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
                'Welcome back — sign in with the phone number you signed up with.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 24),
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
