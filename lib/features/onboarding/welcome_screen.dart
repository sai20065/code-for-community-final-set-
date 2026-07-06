import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers/onboarding_progress_provider.dart';
import '../../app/theme.dart';
import '../../core/services/aadhaar_ocr_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/primary_button.dart';

/// First screen after Splash for anyone not yet signed in: "Citizen" vs
/// "MP office" tabs (per the brand brief's two-tab login). Citizen tab is
/// just an entry point into the existing Language → Aadhaar flow; MP office
/// tab is a real constituency-ID + password login, since officials are
/// provisioned out-of-band rather than self-registering.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _mpTab = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const _WaveformLogo(),
              const SizedBox(height: 10),
              Text(
                'Prajadhwani',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.indigoDeep),
              ),
              const SizedBox(height: 4),
              Text(
                'Voice of the constituency',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkFaint, fontSize: 13),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(child: _TabButton(label: 'Citizen', selected: !_mpTab, onTap: () => setState(() => _mpTab = false))),
                    Expanded(child: _TabButton(label: 'MP office', selected: _mpTab, onTap: () => setState(() => _mpTab = true))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _mpTab ? const _MpLoginForm() : const _CitizenEntry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformLogo extends StatelessWidget {
  const _WaveformLogo();

  @override
  Widget build(BuildContext context) {
    const heights = [16.0, 30.0, 22.0, 34.0];
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in heights)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 8,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.saffron,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

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

/// Which sign-in method the citizen has expanded on the Welcome screen.
/// `null` means the picker itself ("Phone" / "Email" / "Skip") is showing,
/// with neither sub-form open yet.
enum _AuthMethod { phone, email }

/// Citizen entry point — folds identity capture (one-time Aadhaar-photo OCR
/// convenience, same extraction this app has always used) and account
/// creation into a single screen: upload → (optionally) fix up the
/// extracted name/pincode/address → pick how to sign in. Phone and email are
/// real Firebase accounts (portable across a reinstall); "stay anonymous"
/// remains available for anyone who'd rather not attach either, unchanged
/// from the original design.
class _CitizenEntry extends ConsumerStatefulWidget {
  const _CitizenEntry();

  @override
  ConsumerState<_CitizenEntry> createState() => _CitizenEntryState();
}

class _CitizenEntryState extends ConsumerState<_CitizenEntry> {
  final _picker = ImagePicker();
  final _ocrService = AadhaarOcrService();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  final _nameController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  File? _image;
  bool _extracting = false;
  bool _manualEntry = false;
  String? _error;

  bool _showAuthOptions = false;
  _AuthMethod? _authMethod;
  String? _verificationId;
  bool _codeSent = false;
  bool _sendingCode = false;
  bool _finishing = false;
  String? _authError;

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      RegExp(r'^[1-9][0-9]{5}$').hasMatch(_pincodeController.text.trim());

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _error = null;
      });
    }
  }

  Future<void> _extract() async {
    if (_image == null) return;
    setState(() {
      _extracting = true;
      _error = null;
    });
    try {
      final result = await _ocrService.extractDetails(_image!);
      if (!mounted) return;
      setState(() {
        _extracting = false;
        if (result.name != null) _nameController.text = result.name!;
        if (result.pincode != null) _pincodeController.text = result.pincode!;
        if (result.address != null) _addressController.text = result.address!;
        if (!result.looksUsable) {
          _error = "Couldn't read that clearly — check the details below or enter them manually.";
          _manualEntry = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _manualEntry = true;
        _error = "Couldn't process that image right now — enter your details manually below.";
      });
    }
  }

  /// Common tail of every sign-in path: writes the (possibly Aadhaar-OCR'd)
  /// name/pincode/address onto the just-created/linked `users/{uid}` doc,
  /// advances onboarding past Aadhaar identity, and moves on to language
  /// selection — mirrors what the old standalone Aadhaar screen did.
  Future<void> _finishSignup(User user) async {
    await _firestoreService.getOrCreateUser(
      uid: user.uid,
      preferredLanguage: 'en',
      name: _nameController.text.trim(),
      pincodeHome: _pincodeController.text.trim(),
      addressHome: _addressController.text.trim(),
    );
    await ref
        .read(onboardingProgressProvider.notifier)
        .advanceTo(OnboardingStep.basicInfo);
    if (mounted) context.go('/language');
  }

  Future<void> _continueAnonymously() async {
    setState(() {
      _finishing = true;
      _authError = null;
    });
    try {
      final user = await _authService.ensureSignedIn();
      await _finishSignup(user);
    } catch (e) {
      setState(() {
        _finishing = false;
        _authError = 'Could not continue — check your connection and try again.';
      });
    }
  }

  Future<void> _sendCode() async {
    final digits = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      setState(() => _authError = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _sendingCode = true;
      _authError = null;
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
        setState(() => _finishing = true);
        await _finishSignup(user);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _authError = message;
        });
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null || _codeController.text.trim().length < 6) return;
    setState(() {
      _finishing = true;
      _authError = null;
    });
    try {
      final user = await _authService.confirmSmsCode(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await _finishSignup(user);
    } catch (e) {
      setState(() {
        _finishing = false;
        _authError = "That code didn't match — check it and try again.";
      });
    }
  }

  Future<void> _continueWithEmail() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _authError = 'Enter a valid email address.');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _authError = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _finishing = true;
      _authError = null;
    });
    try {
      final user = await _authService.continueWithEmail(
        email: email,
        password: _passwordController.text,
      );
      await _finishSignup(user);
    } catch (e) {
      setState(() {
        _finishing = false;
        _authError = 'Could not sign in with that email — check your password and try again.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.record_voice_over_rounded, size: 56, color: AppColors.indigoMist),
          const SizedBox(height: 12),
          Text(
            'Share a development suggestion or report a civic problem — in your own language, by voice, text or photo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Upload a photo of your Aadhaar so we can read your name and '
              'address. We keep only your name, address and pincode — the '
              'photo and your Aadhaar number are never saved. This is not ID '
              'verification; you can also just type your details below.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_image!, height: 140, fit: BoxFit.cover),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.badge_outlined, size: 40, color: Colors.grey),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Extract details',
            icon: Icons.auto_awesome_rounded,
            loading: _extracting,
            onPressed: _image == null ? null : _extract,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _manualEntry = !_manualEntry),
              child: Text(_manualEntry ? 'Hide manual entry' : "Skip — I'll enter manually"),
            ),
          ),
          if (_manualEntry || _nameController.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Full name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(hintText: 'Pincode'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(hintText: 'Address (street, area)'),
            ),
          ],
          const SizedBox(height: 8),
          if (!_showAuthOptions)
            PrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _canContinue ? () => setState(() => _showAuthOptions = true) : null,
            )
          else ...[
            const SizedBox(height: 4),
            Text(
              'How would you like to sign in?',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            _AuthMethodTile(
              icon: Icons.phone_android_rounded,
              label: 'Continue with phone number',
              selected: _authMethod == _AuthMethod.phone,
              onTap: () => setState(() {
                _authMethod = _AuthMethod.phone;
                _authError = null;
              }),
            ),
            if (_authMethod == _AuthMethod.phone) ...[
              const SizedBox(height: 10),
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
                  label: 'Verify & continue',
                  icon: Icons.check_circle_rounded,
                  loading: _finishing,
                  onPressed: _finishing ? null : _verifyCode,
                ),
              ],
            ],
            const SizedBox(height: 8),
            _AuthMethodTile(
              icon: Icons.email_rounded,
              label: 'Continue with email',
              selected: _authMethod == _AuthMethod.email,
              onTap: () => setState(() {
                _authMethod = _AuthMethod.email;
                _authError = null;
              }),
            ),
            if (_authMethod == _AuthMethod.email) ...[
              const SizedBox(height: 10),
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
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                loading: _finishing,
                onPressed: _finishing ? null : _continueWithEmail,
              ),
            ],
            if (_authError != null) ...[
              const SizedBox(height: 10),
              Text(_authError!, style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
            ],
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _finishing ? null : _continueAnonymously,
                child: const Text('Skip — stay anonymous'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            "Whichever way you sign in, your MP's office only ever sees "
            "aggregated demand, never your identity.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkFaint, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AuthMethodTile extends StatelessWidget {
  const _AuthMethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigoMist : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? AppColors.indigo : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.indigo : AppColors.inkSoft),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.indigo : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MpLoginForm extends StatefulWidget {
  const _MpLoginForm();

  @override
  State<_MpLoginForm> createState() => _MpLoginFormState();
}

class _MpLoginFormState extends State<_MpLoginForm> {
  final _constituencyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (_constituencyController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signInOfficial(
        constituencyId: _constituencyController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/official/dashboard');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not sign in. Check your constituency ID and password.';
      });
    }
  }

  @override
  void dispose() {
    _constituencyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _constituencyController,
          decoration: const InputDecoration(hintText: 'Constituency ID'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
        ],
        const Spacer(),
        PrimaryButton(
          label: 'Sign in',
          icon: Icons.login_rounded,
          loading: _loading,
          onPressed: _login,
        ),
      ],
    );
  }
}
