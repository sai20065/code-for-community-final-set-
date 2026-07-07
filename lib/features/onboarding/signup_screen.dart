import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers/onboarding_progress_provider.dart';
import '../../app/theme.dart';
import '../../core/models/user_model.dart';
import '../../core/services/aadhaar_ocr_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/primary_button.dart';

/// New-citizen entry point — folds one-time Aadhaar-photo OCR (front AND
/// back; the back side often carries the full address the front truncates,
/// so capturing it improves extraction accuracy, though it is never
/// required — manual entry always works) and account creation into a
/// single screen: upload → (optionally) fix up the extracted
/// name/pincode/ward number → capture your location → sign in with a phone
/// number, or stay anonymous. Phone is a real Firebase account (portable
/// across a reinstall); "stay anonymous" remains available for anyone who'd
/// rather not attach a number.
///
/// Distinct from `SignInScreen`: this screen only ever creates a brand-new
/// account and always writes a fresh `users/{uid}.signupCompletedAt` —
/// existing citizens should use Sign In instead.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _picker = ImagePicker();
  final _ocrService = AadhaarOcrService();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();

  final _nameController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _wardController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  File? _frontImage;
  File? _backImage;
  bool _extracting = false;
  bool _manualEntry = false;
  String? _error;
  double? _extractionConfidence;

  // Captured home location (from the "Use my location" button / map pin).
  // `_addressLabel` is a best-effort reverse-geocoded string stored as the
  // human-readable addressHome; the raw lat/lng is the source of truth.
  LatLng? _homePin;
  bool _locating = false;
  String? _addressLabel;

  bool _showAuthOptions = false;
  String? _verificationId;
  bool _codeSent = false;
  bool _sendingCode = false;
  bool _finishing = false;
  String? _authError;

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      RegExp(r'^[1-9][0-9]{5}$').hasMatch(_pincodeController.text.trim());

  Future<void> _pick(bool front, ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() {
        if (front) {
          _frontImage = File(picked.path);
        } else {
          _backImage = File(picked.path);
        }
        _error = null;
      });
    }
  }

  Future<void> _extract() async {
    if (_frontImage == null) return;
    setState(() {
      _extracting = true;
      _error = null;
    });
    try {
      // The Aadhaar OCR Cloud Function is `onCall` and requires an
      // authenticated caller — but on this screen the citizen hasn't picked
      // a sign-in method yet. Establish an (anonymous) Firebase session
      // first so the callable has a valid auth token; it persists and either
      // becomes their account ("stay anonymous") or is superseded when they
      // verify a phone number.
      await _authService.ensureSignedIn();
      final result = await _ocrService.extractDetails(
        front: _frontImage!,
        back: _backImage,
      );
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _extractionConfidence = result.confidence;
        if (result.name != null) _nameController.text = result.name!;
        if (result.pincode != null) _pincodeController.text = result.pincode!;
        if (result.address != null) _addressLabel = result.address!;
        if (result.wardNumber != null) _wardController.text = result.wardNumber!;
        if (!result.looksUsable) {
          _error = AppLocalizations.of(context).couldNotReadClearly;
          _manualEntry = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _manualEntry = true;
        _error = AppLocalizations.of(context).couldNotProcessImage;
      });
    }
  }

  /// "Use my location" — capture the citizen's home coordinates via GPS and
  /// best-effort reverse-geocode them into a readable address label. Reuses
  /// `LocationService.getCurrentLatLng()` (same GPS path the compose flow's
  /// location picker uses). On failure, leaves the pin unset so they can drop
  /// one manually on the map preview.
  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _authError = null;
    });
    final fix = await _locationService.getCurrentLatLng();
    if (!mounted) return;
    if (fix == null) {
      setState(() {
        _locating = false;
        _homePin ??= const LatLng(28.6139, 77.2090);
        _addressLabel = null;
      });
      return;
    }
    final point = LatLng(fix.$1, fix.$2);
    final label = await _locationService.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _homePin = point;
      if (label != null) _addressLabel = label;
    });
  }

  Future<void> _movePin(LatLng point) async {
    setState(() => _homePin = point);
    final label = await _locationService.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    if (label != null) setState(() => _addressLabel = label);
  }

  /// Common tail of every Sign Up path: writes the (possibly Aadhaar-OCR'd)
  /// name/pincode/address/ward onto the just-created `users/{uid}` doc,
  /// stamps `signupCompletedAt` as the authoritative "profile is real and
  /// saved" marker, records which method was used, advances onboarding past
  /// Aadhaar identity, and moves on to language selection.
  Future<void> _finishSignup(User user, SignInMethod method) async {
    final existing = await _firestoreService.getOrCreateUser(
      uid: user.uid,
      preferredLanguage: 'en',
      name: _nameController.text.trim(),
      pincodeHome: _pincodeController.text.trim(),
      addressHome: _addressLabel,
    );
    await _firestoreService.upsertUser(existing.copyWith(
      name: _nameController.text.trim(),
      pincodeHome: _pincodeController.text.trim(),
      addressHome: _addressLabel,
      wardNumber: _wardController.text.trim().isEmpty
          ? null
          : _wardController.text.trim(),
      lat: _homePin?.latitude,
      lng: _homePin?.longitude,
      signInMethod: method,
      aadhaarExtractionConfidence: _extractionConfidence,
      signupCompletedAt: DateTime.now(),
    ));
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
      await _finishSignup(user, SignInMethod.anonymous);
    } catch (e) {
      setState(() {
        _finishing = false;
        _authError = AppLocalizations.of(context).couldNotContinue;
      });
    }
  }

  Future<void> _sendCode() async {
    final digits = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      setState(() => _authError = AppLocalizations.of(context).enterValidMobile);
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
        await _finishSignup(user, SignInMethod.phone);
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
      await _finishSignup(user, SignInMethod.phone);
    } catch (e) {
      setState(() {
        _finishing = false;
        _authError = AppLocalizations.of(context).codeDidntMatch;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pincodeController.dispose();
    _wardController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(l10n.signUp),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.record_voice_over_rounded, size: 56, color: AppColors.indigoMist),
              const SizedBox(height: 12),
              Text(
                l10n.citizenIntro,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.aadhaarUploadNote,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _AadhaarImageSlot(
                      label: l10n.slotFront,
                      image: _frontImage,
                      onCamera: () => _pick(true, ImageSource.camera),
                      onGallery: () => _pick(true, ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AadhaarImageSlot(
                      label: 'Back',
                      image: _backImage,
                      onCamera: () => _pick(false, ImageSource.camera),
                      onGallery: () => _pick(false, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: l10n.extractDetails,
                icon: Icons.auto_awesome_rounded,
                loading: _extracting,
                onPressed: _frontImage == null ? null : _extract,
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
                  child: Text(_manualEntry ? l10n.hideManualEntry : l10n.skipEnterManually),
                ),
              ),
              if (_manualEntry || _nameController.text.isNotEmpty) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(hintText: l10n.fullName),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(hintText: l10n.pincode),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                // Location capture replaces a free-text address field: one
                // tap grabs GPS coordinates (reverse-geocoded to a readable
                // label for the DB), and the citizen can fine-tune by tapping
                // the map. Both the raw lat/lng and the label are saved.
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded),
                  label: Text(_homePin == null ? l10n.useMyLocation : l10n.updateMyLocation),
                ),
                if (_addressLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(_addressLabel!,
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                ],
                if (_homePin != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: _homePin!,
                          initialZoom: 15,
                          onTap: (_, point) => _movePin(point),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.prajadhvani.app',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: _homePin!,
                              width: 34,
                              height: 34,
                              child: const Icon(Icons.location_on_rounded,
                                  color: AppColors.vermilion, size: 34),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  Text(l10n.tapMapToAdjust,
                      style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _wardController,
                  decoration: InputDecoration(hintText: l10n.wardNumberOptional),
                ),
              ],
              const SizedBox(height: 8),
              if (!_showAuthOptions)
                PrimaryButton(
                  label: l10n.continueLabel,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _canContinue ? () => setState(() => _showAuthOptions = true) : null,
                )
              else ...[
                const SizedBox(height: 4),
                Text(
                  l10n.verifyWithPhone,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13.5),
                ),
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
                        decoration: InputDecoration(hintText: l10n.mobileNumberHint, counterText: ''),
                      ),
                    ),
                  ],
                ),
                if (!_codeSent) ...[
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: l10n.sendCode,
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
                    decoration: InputDecoration(hintText: l10n.sixDigitCode, counterText: ''),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: l10n.verifyAndContinue,
                    icon: Icons.check_circle_rounded,
                    loading: _finishing,
                    onPressed: _finishing ? null : _verifyCode,
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
                    child: Text(l10n.skipStayAnonymous),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.aggregatedDemandNote,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkFaint, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/signin'),
                  child: Text(l10n.alreadyHaveAccountSignInShort),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AadhaarImageSlot extends StatelessWidget {
  const _AadhaarImageSlot({
    required this.label,
    required this.image,
    required this.onCamera,
    required this.onGallery,
  });

  final String label;
  final File? image;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
        const SizedBox(height: 6),
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(image!, height: 90, fit: BoxFit.cover),
          )
        else
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.badge_outlined, size: 32, color: Colors.grey),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: IconButton(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                tooltip: l10n.camera,
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                tooltip: l10n.gallery,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
