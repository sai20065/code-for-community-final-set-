import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/onboarding_progress_stepper.dart';
import '../../../shared/widgets/primary_button.dart';

/// Groups digits as `98765 43210` for readability while keeping the
/// underlying value digits-only (Phase 2, Section 5).
class _GroupedPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 5) buffer.write(' ');
      buffer.write(limited[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Step 1 of 4: phone number field, fixed +91 prefix, "Send OTP" disabled
/// until exactly 10 digits, inline error banner (never a blocking dialog).
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _controller = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  String get _digits => _controller.text.replaceAll(RegExp(r'\D'), '');
  bool get _isValid => _digits.length == 10;

  Future<void> _sendOtp() async {
    if (!_isValid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final phone = '+91$_digits';
    await _authService.sendOtp(
      phoneNumber: phone,
      onCodeSent: (verificationId) {
        setState(() => _loading = false);
        if (mounted) {
          context.go('/signup/otp',
              extra: {'verificationId': verificationId, 'phone': phone});
        }
      },
      onFailed: (e) {
        setState(() {
          _loading = false;
          _error = e.message ?? 'Could not send OTP. Please try again.';
        });
      },
      onAutoVerified: (credential) {
        setState(() => _loading = false);
        if (mounted) context.go('/signup/basic-info');
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
              const Icon(Icons.phone_android_rounded, size: 56),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_GroupedPhoneFormatter()],
                      style: const TextStyle(fontSize: 22, letterSpacing: 1.2),
                      decoration: InputDecoration(
                        hintText: '98765 43210',
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(16),
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Send OTP',
                icon: Icons.send_rounded,
                loading: _loading,
                onPressed: _isValid ? _sendOtp : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
