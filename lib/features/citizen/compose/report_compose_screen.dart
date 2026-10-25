import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/transcription_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ai_suggestion_chips.dart';
import '../../../shared/widgets/location_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/recording_waveform.dart';
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

/// The single compose screen for both Report (problem) and Suggest
/// (feedback): text, voice and photo all live on one page so a citizen can
/// snap the pothole, say what's wrong and correct the words in one go —
/// replacing the old separate voice/text/photo screens, where switching
/// modes lost whatever had been entered.
///
/// Voice is speech-to-text: the transcript is appended to the description
/// box (still editable) and the audio is kept as an optional voice note
/// (`audioUrl`). The photo goes to `mediaUrl`. Location/language stay the
/// citizen's own (from their profile) — never freely chosen.
class ReportComposeScreen extends StatefulWidget {
  const ReportComposeScreen({
    super.key,
    this.initialCategory,
    this.initialFocus,
    this.authService,
    this.firestoreService,
    this.storageService,
    this.transcriptionService,
    this.locationService,
  });

  final SubmissionCategory? initialCategory;

  /// Injectable for widget tests; the app uses the Firebase-backed defaults.
  final AuthService? authService;
  final FirestoreService? firestoreService;
  final StorageService? storageService;
  final TranscriptionService? transcriptionService;
  final LocationService? locationService;

  /// 'voice' starts recording and 'photo' opens the camera on arrival —
  /// keeps the old `/compose/voice` and `/compose/photo` links meaningful.
  final String? initialFocus;

  @override
  State<ReportComposeScreen> createState() => _ReportComposeScreenState();
}

class _ReportComposeScreenState extends State<ReportComposeScreen> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  late final _firestoreService = widget.firestoreService ?? FirestoreService();
  late final _authService = widget.authService ?? AuthService();
  late final _storageService = widget.storageService ?? StorageService();
  late final _transcriptionService =
      widget.transcriptionService ?? TranscriptionService();
  // Created on first use, so merely opening the screen never touches the
  // microphone plugin.
  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  late SubmissionCategory _category =
      widget.initialCategory ?? SubmissionCategory.problem;
  UserModel? _profile;

  // Text / theme
  String? _theme;
  String? _suggestedTheme;
  int? _similarCount;

  // Voice
  bool _isRecording = false;
  bool _transcribing = false;
  String? _audioPath;
  String? _lastTranscript;
  String? _translatedText;
  String? _voiceError;
  Duration _elapsed = Duration.zero;
  Duration _voiceNoteLength = Duration.zero;

  // Photo
  File? _photo;

  /// Consent to show a blurred copy of the photo in the public feed. Off by
  /// default, and reset whenever the photo is removed.
  bool _photoPublic = false;

  // Location / submit
  LatLng? _pin;
  bool _submitting = false;
  String? _submitError;

  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _hasVoice => _audioPath != null;
  bool get _hasPhoto => _photo != null;
  bool get _canSubmit =>
      (_hasText || _hasPhoto) && !_isRecording && !_transcribing && !_submitting;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFocus == 'voice') _toggleRecording();
      if (widget.initialFocus == 'photo') _pickPhoto(ImageSource.camera);
    });
  }

  Future<UserModel?> _ensureProfile() async {
    if (_profile != null) return _profile;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return null;
    final profile = await _firestoreService.getUser(uid);
    if (mounted) setState(() => _profile = profile);
    return profile;
  }

  Future<void> _loadProfile() => _ensureProfile();

  // ---- Text / theme ------------------------------------------------------

  void _onTextChanged(String value) {
    final guess = _guessCategory(value);
    setState(() {
      if (_theme == null) _suggestedTheme = guess;
    });
  }

  Future<void> _selectTheme(String? themeId) async {
    setState(() {
      _theme = themeId;
      _similarCount = null;
      if (themeId != null) _suggestedTheme = null;
    });
    if (themeId == null) return;
    final constituencyId = (await _ensureProfile())?.constituencyId;
    if (constituencyId == null) return;
    final clusters = await _firestoreService
        .watchClustersForConstituency(constituencyId)
        .first;
    final count = clusters
        .where((c) => c.theme == themeId)
        .fold<int>(0, (sum, c) => sum + c.submissionCount);
    if (mounted && _theme == themeId) setState(() => _similarCount = count);
  }

  // ---- Voice -------------------------------------------------------------

  Future<void> _toggleRecording() async {
    final l10n = AppLocalizations.of(context);
    if (_isRecording) {
      try {
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
          if (path != null) {
            _audioPath = path;
            _voiceNoteLength = _elapsed;
          }
        });
        if (path != null) _transcribe();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _voiceError = l10n.couldNotConvertVoice;
        });
      }
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _voiceError = l10n.couldNotConvertVoice);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _isRecording = true;
        _elapsed = Duration.zero;
        _voiceError = null;
      });
      _tickTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _voiceError = l10n.couldNotConvertVoice;
      });
    }
  }

  void _tickTimer() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isRecording) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    }
  }

  /// Converts the recording to text and appends it to the description so
  /// the citizen can read and correct it. Failure is non-fatal — they can
  /// still type, or re-record.
  Future<void> _transcribe() async {
    if (_audioPath == null) return;
    setState(() {
      _transcribing = true;
      _voiceError = null;
    });
    try {
      final profile = await _ensureProfile();
      final result = await _transcriptionService.transcribe(
        audio: File(_audioPath!),
        sourceLanguage: profile?.preferredLanguage ?? 'en',
      );
      if (!mounted) return;
      final existing = _textController.text.trim();
      final transcript = result.transcript.trim();
      setState(() {
        _transcribing = false;
        _lastTranscript = transcript;
        _translatedText = result.translatedText;
        _textController.text =
            existing.isEmpty ? transcript : '$existing\n$transcript';
      });
      _onTextChanged(_textController.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _voiceError = AppLocalizations.of(context).couldNotConvertVoice;
      });
    }
  }

  void _removeVoiceNote() {
    setState(() {
      _audioPath = null;
      _voiceNoteLength = Duration.zero;
      _translatedText = null;
      _lastTranscript = null;
      _voiceError = null;
    });
  }

  // ---- Photo -------------------------------------------------------------

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      // Capped at 1600px: full-resolution camera photos are 2-4 MB each,
      // which would use up the Storage free tier within months; 1600px is
      // ~0.3-0.5 MB and still plenty for officials and the photo caption.
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null && mounted) setState(() => _photo = File(picked.path));
    } catch (_) {
      // Camera unavailable / permission denied — the tiles stay usable.
    }
  }

  // ---- Submit ------------------------------------------------------------

  Future<String?> _tryUpload(String uid, File file, String extension) async {
    try {
      return await _storageService.uploadSubmissionMedia(
        userId: uid,
        file: file,
        extension: extension,
      );
    } catch (_) {
      // The ticket must still be created if an upload fails — the citizen
      // never loses their receipt. Server-side vision/transcription simply
      // won't run for the missing file.
      return null;
    }
  }

  Future<void> _submit() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || !_canSubmit) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final profile = await _ensureProfile();
    final mediaUrl = _photo == null ? null : await _tryUpload(uid, _photo!, 'jpg');
    final audioUrl =
        _audioPath == null ? null : await _tryUpload(uid, File(_audioPath!), 'm4a');

    final text = _textController.text.trim();
    // A photo keeps the ticket a "photo" ticket so server captioning and the
    // photo-reporter badge still apply; voice next; plain text otherwise.
    final type = _hasPhoto
        ? SubmissionType.photo
        : _hasVoice
            ? SubmissionType.voice
            : SubmissionType.text;
    final inputMode = [
      if (_hasText) 'text',
      if (_hasVoice) 'voice',
      if (_hasPhoto) 'photo',
    ].join('+');

    final draft = SubmissionModel(
      id: '',
      userId: uid,
      type: type,
      category: _category,
      inputMode: inputMode.isEmpty ? 'text' : inputMode,
      rawText: text.isEmpty ? null : text,
      // Only valid while the text is exactly what was transcribed — once the
      // citizen edits or adds to it, let the server translate afresh.
      translatedText: text == _lastTranscript ? _translatedText : null,
      mediaUrl: mediaUrl,
      audioUrl: audioUrl,
      photoPublic: _photoPublic && mediaUrl != null,
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
    _textController.dispose();
    _recorderInstance?.dispose();
    super.dispose();
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSuggestion = _category == SubmissionCategory.feedback;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ComposeHeader(
              category: _category,
              onCategoryChanged: (v) => setState(() => _category = v),
              onBack: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(
              children: [
                _SectionCard(
                  step: 1,
                  icon: Icons.edit_note_rounded,
                  color: AppColors.indigo,
                  title: isSuggestion ? l10n.stepYourIdea : l10n.stepWhatsTheIssue,
                  done: _hasText,
                  child: _buildDescribe(l10n, isSuggestion),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  step: 2,
                  icon: Icons.photo_camera_rounded,
                  color: AppColors.teal,
                  title: l10n.stepAddPhoto,
                  done: _hasPhoto,
                  child: _buildPhoto(l10n),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  step: 3,
                  icon: Icons.category_rounded,
                  color: AppColors.saffronDeep,
                  title: l10n.stepCategory,
                  done: _theme != null,
                  child: _buildCategory(l10n),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  step: 4,
                  icon: Icons.place_rounded,
                  color: AppColors.vermilion,
                  title: l10n.stepWhere,
                  done: true,
                  child: LocationPicker(
                    homeLat: _profile?.lat,
                    homeLng: _profile?.lng,
                    onChanged: (point) => _pin = point,
                    locationService: widget.locationService,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SubmitBar(
        hasText: _hasText,
        hasVoice: _hasVoice,
        hasPhoto: _hasPhoto,
        submitting: _submitting,
        error: _submitError,
        label: isSuggestion ? l10n.submitSuggestion : l10n.submitReport,
        onSubmit: _canSubmit ? _submit : null,
      ),
    );
  }

  Widget _buildDescribe(AppLocalizations l10n, bool isSuggestion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.indigoMist.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: _isRecording ? AppColors.vermilion : AppColors.indigoMist,
              width: _isRecording ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: _textController,
                minLines: 4,
                maxLines: 8,
                enabled: !_isRecording,
                style: const TextStyle(fontSize: 17, height: 1.4),
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: isSuggestion ? l10n.suggestionHint : l10n.problemHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isRecording
                      ? _RecordingStrip(
                          key: const ValueKey('rec'),
                          elapsed: _elapsed,
                          label: l10n.listeningTapToStop,
                          onStop: _toggleRecording,
                        )
                      : Row(
                          key: const ValueKey('idle'),
                          children: [
                            Expanded(
                              child: Text(
                                _transcribing
                                    ? l10n.convertingVoiceToText
                                    : l10n.tapMicToSpeak,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.inkSoft),
                              ),
                            ),
                            if (_transcribing)
                              const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              )
                            else
                              _MicButton(onTap: _toggleRecording),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasVoice && !_isRecording) ...[
                const SizedBox(height: 10),
                _VoiceNotePill(
                  label: '${l10n.voiceNoteAdded} · ${_fmt(_voiceNoteLength)}',
                  reRecordLabel: l10n.reRecord,
                  onReRecord: _transcribing ? null : _toggleRecording,
                  onRemove: _transcribing ? null : _removeVoiceNote,
                ),
              ],
              if (_voiceError != null) ...[
                const SizedBox(height: 8),
                Text(_voiceError!,
                    style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
                if (_hasVoice)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _transcribe,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.tryConvertingAgain),
                    ),
                  ),
              ],
              if (_suggestedTheme != null && _theme != _suggestedTheme) ...[
                const SizedBox(height: 10),
                ThemeConfirmChip(
                  themeId: _suggestedTheme!,
                  onConfirm: () => _selectTheme(_suggestedTheme),
                  onDismiss: () => setState(() => _suggestedTheme = null),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoto(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhotoPreview(l10n),
        if (_photo != null)
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: _photoPublic,
            onChanged: (v) => setState(() => _photoPublic = v),
            title: Text(l10n.showPhotoInFeed,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(l10n.showPhotoInFeedNote, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildPhotoPreview(AppLocalizations l10n) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _photo != null
          ? ClipRRect(
              key: const ValueKey('photo'),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Stack(
                children: [
                  Image.file(_photo!,
                      height: 200, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _RoundIconButton(
                      icon: Icons.close_rounded,
                      tooltip: l10n.removePhoto,
                      onTap: () => setState(() {
                        _photo = null;
                        _photoPublic = false;
                      }),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.camera_alt_rounded,
                          tooltip: l10n.camera,
                          onTap: () => _pickPhoto(ImageSource.camera),
                        ),
                        const SizedBox(width: 8),
                        _RoundIconButton(
                          icon: Icons.photo_library_rounded,
                          tooltip: l10n.gallery,
                          onTap: () => _pickPhoto(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              key: const ValueKey('empty'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PhotoSourceTile(
                        icon: Icons.camera_alt_rounded,
                        label: l10n.camera,
                        color: AppColors.teal,
                        mist: AppColors.tealMist,
                        onTap: () => _pickPhoto(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PhotoSourceTile(
                        icon: Icons.photo_library_rounded,
                        label: l10n.gallery,
                        color: AppColors.indigo,
                        mist: AppColors.indigoMist,
                        onTap: () => _pickPhoto(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l10n.photoHelpsOfficials,
                    style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
              ],
            ),
    );
  }

  Widget _buildCategory(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.pickCategoryOptional,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        const SizedBox(height: 10),
        ThemePickerWidget(selected: _theme, onSelected: _selectTheme),
        if (_similarCount != null && _similarCount! > 0) ...[
          const SizedBox(height: 12),
          SimilarCountChip(count: _similarCount!, category: _category),
        ],
      ],
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Gradient hero header: back button, title, subtitle and the
/// Problem / Suggestion switch.
class _ComposeHeader extends StatelessWidget {
  const _ComposeHeader({
    required this.category,
    required this.onCategoryChanged,
    required this.onBack,
  });

  final SubmissionCategory category;
  final ValueChanged<SubmissionCategory> onCategoryChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSuggestion = category == SubmissionCategory.feedback;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.indigo, AppColors.indigoDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadii.lg)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        isSuggestion ? l10n.shareYourSuggestion : l10n.reportAProblem,
                        key: ValueKey(isSuggestion),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 0, 14),
                child: Text(
                  isSuggestion ? l10n.composeSubtitleSuggestion : l10n.composeSubtitleProblem,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _HeaderSegment(
                        icon: Icons.warning_amber_rounded,
                        label: l10n.badgeReport,
                        selected: !isSuggestion,
                        activeColor: AppColors.vermilion,
                        onTap: () => onCategoryChanged(SubmissionCategory.problem),
                      ),
                      _HeaderSegment(
                        icon: Icons.lightbulb_rounded,
                        label: l10n.badgeSuggestion,
                        selected: isSuggestion,
                        activeColor: AppColors.saffronDeep,
                        onTap: () => onCategoryChanged(SubmissionCategory.feedback),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Row(
                    children: [
                      for (final c in AppColors.tricolorStrip)
                        Expanded(child: Container(height: 3, color: c)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSegment extends StatelessWidget {
  const _HeaderSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? activeColor : Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? AppColors.ink : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A numbered card; the number badge turns into a check once the step
/// has something in it.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.done,
    required this.child,
  });

  final int step;
  final IconData icon;
  final Color color;
  final String title;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.teal : AppColors.paper,
                ),
                child: done
                    ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                    : Text('$step',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkFaint)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.saffron, AppColors.saffronDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.saffronDeep.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _RecordingStrip extends StatelessWidget {
  const _RecordingStrip({
    super.key,
    required this.elapsed,
    required this.label,
    required this.onStop,
  });

  final Duration elapsed;
  final String label;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final time =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        const SizedBox(
          width: 110,
          height: 56,
          child: FittedBox(child: RecordingWaveform(isRecording: true)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.vermilion,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
        ),
        Material(
          color: AppColors.vermilion,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onStop,
            child: const SizedBox(
              width: 50,
              height: 50,
              child: Icon(Icons.stop_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceNotePill extends StatelessWidget {
  const _VoiceNotePill({
    required this.label,
    required this.reRecordLabel,
    required this.onReRecord,
    required this.onRemove,
  });

  final String label;
  final String reRecordLabel;
  final VoidCallback? onReRecord;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.saffronMist,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.saffronDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
          IconButton(
            tooltip: reRecordLabel,
            onPressed: onReRecord,
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.saffronDeep),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.mist,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color mist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: mist.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom bar: a "what's included" row that lights up per input,
/// then the submit button.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.hasText,
    required this.hasVoice,
    required this.hasPhoto,
    required this.submitting,
    required this.error,
    required this.label,
    required this.onSubmit,
  });

  final bool hasText;
  final bool hasVoice;
  final bool hasPhoto;
  final bool submitting;
  final String? error;
  final String label;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nothingYet = !hasText && !hasPhoto;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IncludedChip(icon: Icons.notes_rounded, label: l10n.includedText, on: hasText, color: AppColors.indigo),
              const SizedBox(width: 6),
              _IncludedChip(icon: Icons.mic_rounded, label: l10n.includedVoice, on: hasVoice, color: AppColors.saffronDeep),
              const SizedBox(width: 6),
              _IncludedChip(icon: Icons.photo_camera_rounded, label: l10n.includedPhoto, on: hasPhoto, color: AppColors.teal),
            ],
          ),
          if (error != null || nothingYet) ...[
            const SizedBox(height: 6),
            Text(
              error ?? l10n.addTextOrPhotoToSubmit,
              style: TextStyle(
                fontSize: 12,
                color: error != null ? AppColors.vermilion : AppColors.inkFaint,
              ),
            ),
          ],
          const SizedBox(height: 8),
          PrimaryButton(
            label: label,
            icon: Icons.send_rounded,
            loading: submitting,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _IncludedChip extends StatelessWidget {
  const _IncludedChip({
    required this.icon,
    required this.label,
    required this.on,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.12) : AppColors.paper,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(on ? Icons.check_circle_rounded : icon,
                size: 15, color: on ? color : AppColors.inkFaint),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: on ? color : AppColors.inkFaint,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
