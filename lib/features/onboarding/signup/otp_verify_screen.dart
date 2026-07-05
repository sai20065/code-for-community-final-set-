import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/providers/selected_language_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/onboarding_progress_stepper.dart';

/// Step 1 of 4 (OTP is part of phone verification, not a separate
/// user-facing step). Auto-submits the instant the 6th digit is entered —
/// a complete 6-digit code is an unambiguous action, so no extra "Verify"
/// tap is needed (Phase 2, Section 5).
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.verificationId,
    required this.phone,
  });

  final String verificationId;
  final String phone;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  bool _verifying = false;
  String? _error;
  Timer? _resendTimer;
  int _resendSeconds = 30;
  late String _verificationId;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    await _authService.sendOtp(
      phoneNumber: widget.phone,
      onCodeSent: (verificationId) {
        _verificationId = verificationId;
        _startResendTimer();
      },
      onFailed: (e) {
        setState(() => _error = e.message ?? 'Could not resend OTP.');
      },
      onAutoVerified: (_) {},
    );
  }

  Future<void> _onDigitChanged(int index, String value) async {
    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    if (_code.length == 6) {
      await _verify();
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final credential = await _authService.verifyOtp(
        verificationId: _verificationId,
        smsCode: _code,
      );
      final uid = credential.user!.uid;
      await _firestoreService.getOrCreateUser(
        uid: uid,
        phone: widget.phone,
        preferredLanguage: ref.read(selectedLanguageProvider) ?? 'en',
      );
      await ref
          .read(onboardingProgressProvider.notifier)
          .advanceTo(OnboardingStep.basicInfo);
      if (mounted) context.go('/signup/basic-info');
    } catch (e) {
      _shakeController.forward(from: 0);
      for (final c in _controllers) {
        c.clear();
      }
      _nodes[0].requestFocus();
      setState(() {
        _verifying = false;
        _error = 'Incorrect code. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _shakeController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const OnboardingProgressStepper(currentStep: 1),
              const SizedBox(height: 32),
              Text(
                'Enter the code sent to ${widget.phone}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/signup/phone'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Edit number'),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final shake =
                      (1 - _shakeController.value) * 8 *
                      ((_shakeController.value * 10).floor().isEven ? 1 : -1);
                  return Transform.translate(
                    offset: Offset(_shakeController.isAnimating ? shake : 0, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 44,
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _nodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 22),
                        decoration: InputDecoration(
                          counterText: '',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _error != null
                                  ? Colors.red
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(i, value),
                      ),
                    );
                  }),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_verifying) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const Spacer(),
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend in 0:${_resendSeconds.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Resend OTP'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
