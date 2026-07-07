import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:latlong2/latlong.dart';

import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ai_suggestion_chips.dart';
import '../../../shared/widgets/category_toggle_widget.dart';
import '../../../shared/widgets/location_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import 'input_mode_switcher.dart';
import 'theme_picker_widget.dart';

/// Lightweight on-device keyword heuristic for the "Looks like: X" confirm
/// chip — a cheap placeholder for the real Gemini classification that runs
/// server-side once a ticket is created (`onSubmissionCreated`). Never
/// auto-assigns: the citizen must tap to confirm.
String? _guessCategory(String text) {
  final lower = text.toLowerCase();
  const keywords = {
    'education': ['school', 'teacher', 'classroom', 'student', 'exam'],
    'skilling': ['training', 'skill', 'job', 'employment', 'livelihood', 'course'],
    'roads': ['road', 'pothole', 'street', 'footpath', 'traffic'],
    'water': ['water', 'pipe', 'tap', 'supply', 'borewell'],
    'health': ['hospital', 'clinic', 'doctor', 'health', 'medicine'],
    'electricity': ['power', 'electricity', 'transformer', 'streetlight'],
    'sanitation': ['garbage', 'waste', 'sewage', 'drain', 'toilet'],
  };
  for (final entry in keywords.entries) {
    if (entry.value.any(lower.contains)) return entry.key;
  }
  return null;
}

/// Text-mode ticket compose: Suggest (feedback) is the primary product
/// surface, Report (problem) the simpler secondary flow — both share this
/// screen, defaulted by which Home FAB launched it. Location/language are
/// always the citizen's own (from their profile) — never freely chosen.
class TextComposeScreen extends StatefulWidget {
  const TextComposeScreen({super.key, this.initialCategory});

  final SubmissionCategory? initialCategory;

  @override
  State<TextComposeScreen> createState() => _TextComposeScreenState();
}

class _TextComposeScreenState extends State<TextComposeScreen> {
  final _controller = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  String? _theme;
  String? _suggestedTheme;
  int? _similarCount;
  late SubmissionCategory _category;
  bool _submitting = false;
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

  void _onTextChanged(String value) {
    final guess = _guessCategory(value);
    if (guess != _suggestedTheme) {
      setState(() => _suggestedTheme = _theme == null ? guess : _suggestedTheme);
    }
  }

  Future<void> _confirmSuggested() async {
    if (_suggestedTheme == null) return;
    setState(() {
      _theme = _suggestedTheme;
      _similarCount = null;
    });
    await _loadSimilarCount();
  }

  Future<void> _selectTheme(String? themeId) async {
    setState(() {
      _theme = themeId;
      _similarCount = null;
    });
    if (themeId != null) await _loadSimilarCount();
  }

  Future<void> _loadSimilarCount() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _theme == null) return;
    final profile = await _firestoreService.getUser(uid);
    final constituencyId = profile?.constituencyId;
    if (constituencyId == null) return;
    final clusters = await _firestoreService
        .watchClustersForConstituency(constituencyId)
        .first;
    final match = clusters.where((c) => c.theme == _theme);
    final count = match.fold<int>(0, (sum, c) => sum + c.submissionCount);
    if (mounted) setState(() => _similarCount = count);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    final profile = await _firestoreService.getUser(uid);
    final draft = SubmissionModel(
      id: '',
      userId: uid,
      type: SubmissionType.text,
      category: _category,
      inputMode: 'text',
      rawText: text,
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
    final saved = await _firestoreService.createSubmission(draft);
    if (mounted) {
      context.go('/confirmation', extra: saved);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSuggestion = _category == SubmissionCategory.feedback;
    return Scaffold(
      appBar: AppBar(
        title: Text(isSuggestion ? l10n.shareYourSuggestion : l10n.describeTheProblem),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputModeSwitcher(current: 'text', category: _category),
              const SizedBox(height: 16),
              CategoryToggleWidget(
                selected: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                maxLines: 6,
                style: const TextStyle(fontSize: 18),
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: isSuggestion ? l10n.suggestionHint : l10n.problemHint,
                ),
              ),
              const SizedBox(height: 16),
              LocationPicker(
                homeLat: _homeLat,
                homeLng: _homeLng,
                onChanged: (point) => _pin = point,
              ),
              if (_suggestedTheme != null && _theme != _suggestedTheme) ...[
                const SizedBox(height: 14),
                ThemeConfirmChip(
                  themeId: _suggestedTheme!,
                  onConfirm: _confirmSuggested,
                  onDismiss: () => setState(() => _suggestedTheme = null),
                ),
              ],
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
              const SizedBox(height: 32),
              PrimaryButton(
                label: isSuggestion ? l10n.submitSuggestion : l10n.submitReport,
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

