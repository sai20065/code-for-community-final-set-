import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ai_suggestion_chips.dart';
import '../../../shared/widgets/category_toggle_widget.dart';
import '../../../shared/widgets/location_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import 'input_mode_switcher.dart';
import 'theme_picker_widget.dart';

/// Photo-mode ticket compose. Report (problem) tickets additionally get a
/// geolocation pin — defaulted to the citizen's home location, manually
/// adjustable — since a civic problem's exact spot often isn't the
/// citizen's home address. Photos are identified server-side via Gemini
/// vision once uploaded (see `functions/src/submissions/onSubmissionCreated.ts`).
class PhotoVideoScreen extends StatefulWidget {
  const PhotoVideoScreen({super.key, this.initialCategory});

  final SubmissionCategory? initialCategory;

  @override
  State<PhotoVideoScreen> createState() => _PhotoVideoScreenState();
}

class _PhotoVideoScreenState extends State<PhotoVideoScreen> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _storageService = StorageService();

  File? _media;
  String? _theme;
  int? _similarCount;
  late SubmissionCategory _category;
  bool _submitting = false;
  String? _submitError;
  LatLng? _pin;
  double? _homeLat;
  double? _homeLng;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? SubmissionCategory.problem;
    _loadHomeLocation();
  }

  Future<void> _loadHomeLocation() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final profile = await _firestoreService.getUser(uid);
    if (mounted) {
      setState(() {
        _homeLat = profile?.lat;
        _homeLng = profile?.lng;
      });
    }
  }

  Future<void> _selectTheme(String? themeId) async {
    setState(() {
      _theme = themeId;
      _similarCount = null;
    });
    if (themeId == null) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final profile = await _firestoreService.getUser(uid);
    final constituencyId = profile?.constituencyId;
    if (constituencyId == null) return;
    final clusters = await _firestoreService
        .watchClustersForConstituency(constituencyId)
        .first;
    final count = clusters
        .where((c) => c.theme == themeId)
        .fold<int>(0, (sum, c) => sum + c.submissionCount);
    if (mounted) setState(() => _similarCount = count);
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _media = File(picked.path));
    }
  }

  Future<void> _submit() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _media == null) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final profile = await _firestoreService.getUser(uid);
    String? mediaUrl;
    try {
      mediaUrl = await _storageService.uploadSubmissionMedia(
        userId: uid,
        file: _media!,
        extension: 'jpg',
      );
    } catch (_) {
      // Ticket must still be created even if the upload fails — the citizen
      // never loses their receipt. Vision identification simply won't run
      // server-side without a mediaUrl.
    }

    final draft = SubmissionModel(
      id: '',
      userId: uid,
      type: SubmissionType.photo,
      category: _category,
      inputMode: 'photo',
      mediaUrl: mediaUrl,
      rawText: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      language: profile?.preferredLanguage ?? 'en',
      theme: _theme,
      location: SubmissionLocation(
        pincode: profile?.pincodeHome ?? '',
        lat: _pin?.latitude ?? profile?.lat,
        lng: _pin?.longitude ?? profile?.lng,
        constituencyId: profile?.constituencyId,
      ),
      status: SubmissionStatus.newSubmission,
      tokenId: '',
      createdAt: DateTime.now(),
    );
    try {
      final saved = await _firestoreService.createSubmission(draft);
      if (mounted) context.go('/confirmation', extra: saved);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = AppLocalizations.of(context).couldNotSubmitTryAgain;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isReport = _category == SubmissionCategory.problem;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/compose'),
        ),
        title: Text(isReport ? l10n.reportAProblem : l10n.addAPhoto),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputModeSwitcher(current: 'photo', category: _category),
              const SizedBox(height: 16),
              CategoryToggleWidget(
                selected: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 20),
              if (_media != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Image.file(_media!, height: 220, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_rounded,
                      size: 48, color: Colors.grey),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(l10n.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(l10n.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _captionController,
                decoration: InputDecoration(hintText: l10n.captionOptional),
              ),
              const SizedBox(height: 20),
              LocationPicker(
                homeLat: _homeLat,
                homeLng: _homeLng,
                onChanged: (point) => _pin = point,
              ),
              if (_similarCount != null && _similarCount! > 0) ...[
                const SizedBox(height: 12),
                SimilarCountChip(count: _similarCount!, category: _category),
              ],
              const SizedBox(height: 24),
              Text(l10n.pickCategoryOptional,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              ThemePickerWidget(
                selected: _theme,
                onSelected: _selectTheme,
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(_submitError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
              const SizedBox(height: 32),
              PrimaryButton(
                label: isReport ? l10n.submitReport : l10n.submitSuggestion,
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _media == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
