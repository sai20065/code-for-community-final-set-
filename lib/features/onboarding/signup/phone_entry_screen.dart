import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/primary_button.dart';

/// One question per screen (Section 3.2 progressive disclosure).
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

  Future<void> _sendOtp() async {
    if (_controller.text.trim().length != 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final phone = '+91${_controller.text.trim()}';
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
          _error = e.message ?? 'Could not send OTP. Try again.';
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
      appBar: AppBar(title: const Text('Your Phone Number')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.phone_android_rounded, size: 56),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: const TextStyle(fontSize: 22, letterSpacing: 1.5),
                decoration: const InputDecoration(
                  prefixText: '+91  ',
                  hintText: '98765 43210',
                ),
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
                onPressed: _sendOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
