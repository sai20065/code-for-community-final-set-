import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/providers/selected_language_provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/aadhaar_ocr_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/onboarding_progress_stepper.dart';
import '../../../shared/widgets/primary_button.dart';

/// Step 1 of 4 — replaces phone/OTP entirely. Identity is Firebase
/// Anonymous Auth (invisible, no phone number); this screen's only job is a
/// one-time convenience extraction of name/address/pincode from a
/// self-uploaded Aadhaar photo so the citizen doesn't have to type them.
///
/// Consent and limits are stated up front, not buried in a comment:
/// - The photo and any 12-digit Aadhaar number are never stored anywhere,
///   on-device or server-side — only name/address/pincode are kept.
/// - This is NOT verified UIDAI eKYC. Nothing here proves the document
///   belongs to the person uploading it.
/// - OCR can fail or misread; manual entry is always available and never
///   blocks onboarding.
class AadhaarUploadScreen extends ConsumerStatefulWidget {
  const AadhaarUploadScreen({super.key});

  @override
  ConsumerState<AadhaarUploadScreen> createState() => _AadhaarUploadScreenState();
}

class _AadhaarUploadScreenState extends ConsumerState<AadhaarUploadScreen> {
  final _picker = ImagePicker();
  final _ocrService = AadhaarOcrService();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  final _nameController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();

  File? _image;
  bool _extracting = false;
  bool _continuing = false;
  bool _manualEntry = false;
  String? _error;

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

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() => _continuing = true);
    final user = await _authService.ensureSignedIn();
    await _firestoreService.getOrCreateUser(
      uid: user.uid,
      preferredLanguage: ref.read(selectedLanguageProvider) ?? 'en',
      name: _nameController.text.trim(),
      pincodeHome: _pincodeController.text.trim(),
      addressHome: _addressController.text.trim(),
    );
    await ref
        .read(onboardingProgressProvider.notifier)
        .advanceTo(OnboardingStep.basicInfo);
    if (mounted) context.go('/signup/basic-info');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const OnboardingProgressStepper(currentStep: 1),
              const SizedBox(height: 24),
              const Icon(Icons.badge_rounded, size: 56, color: AppColors.trustBlue),
              const SizedBox(height: 12),
              Text(
                'Confirm your identity',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.trustBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Upload a photo of your Aadhaar so we can read your name and '
                  'address. We keep only your name, address and pincode — the '
                  'photo and your Aadhaar number are never saved. This is not '
                  'ID verification; you can also just type your details below.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(_image!, height: 160, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.badge_outlined, size: 44, color: Colors.grey),
                ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Extract details',
                icon: Icons.auto_awesome_rounded,
                loading: _extracting,
                onPressed: _image == null ? null : _extract,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _manualEntry = !_manualEntry),
                  child: Text(_manualEntry ? 'Hide manual entry' : "Skip — I'll enter manually"),
                ),
              ),
              if (_manualEntry || _nameController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Full name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                loading: _continuing,
                onPressed: _canContinue ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
