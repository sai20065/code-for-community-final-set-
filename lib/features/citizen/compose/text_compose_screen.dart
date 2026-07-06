import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/cluster_model.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/category_toggle_widget.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
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

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? SubmissionCategory.problem;
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
    final tokenId = _firestoreService.generateTokenId();
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
        lat: profile?.lat,
        lng: profile?.lng,
        constituencyId: profile?.constituencyId,
      ),
      status: SubmissionStatus.newSubmission,
      tokenId: tokenId,
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
    final isSuggestion = _category == SubmissionCategory.feedback;
    return Scaffold(
      appBar: AppBar(
        title: Text(isSuggestion ? 'Share Your Suggestion' : 'Describe the Problem'),
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
                  hintText: isSuggestion
                      ? 'What development work would help your area? (e.g. A skilling centre near the bus stand)'
                      : "What's the problem? (e.g. Streetlight not working)",
                ),
              ),
              if (_suggestedTheme != null && _theme != _suggestedTheme) ...[
                const SizedBox(height: 14),
                _ConfirmChip(
                  themeId: _suggestedTheme!,
                  onConfirm: _confirmSuggested,
                  onDismiss: () => setState(() => _suggestedTheme = null),
                ),
              ],
              if (_similarCount != null && _similarCount! > 0) ...[
                const SizedBox(height: 12),
                _InsightChip(count: _similarCount!),
              ],
              const SizedBox(height: 24),
              Text('Pick a category (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              ThemePickerWidget(
                selected: _theme,
                onSelected: _selectTheme,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: isSuggestion ? 'Submit Suggestion' : 'Submit Report',
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

/// "Looks like: X" — the AI-suggested category, always shown as a
/// confirmable chip rather than auto-assigned silently.
class _ConfirmChip extends StatelessWidget {
  const _ConfirmChip({required this.themeId, required this.onConfirm, required this.onDismiss});

  final String themeId;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(themeId);
    return InkWell(
      onTap: onConfirm,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kThemeIcons[themeId], size: 16, color: color),
            const SizedBox(width: 6),
            Text('Looks like: ${kThemeLabels[themeId]}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: color)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 15, color: color.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The clustering feature made visible — "N others in your booth have
/// asked for this too" — rather than a black-box classifier.
class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.tealMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, size: 16, color: AppColors.tealDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count others nearby have asked for this too',
              style: const TextStyle(color: AppColors.tealDeep, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
