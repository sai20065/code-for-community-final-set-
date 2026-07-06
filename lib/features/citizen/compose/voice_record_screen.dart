import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:record/record.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/ai_suggestion_chips.dart';
import '../../../shared/widgets/category_toggle_widget.dart';
import '../../../shared/widgets/location_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/recording_waveform.dart';
import 'input_mode_switcher.dart';
import 'theme_picker_widget.dart';

/// Section 3.6: big obvious record button, pulsing ring while recording,
/// live waveform, playback-before-submit with re-record option. Voice
/// tickets are transcribed/translated server-side via Bhashini once
/// uploaded (see `functions/src/submissions/onSubmissionCreated.ts`).
class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({super.key, this.initialCategory});

  final SubmissionCategory? initialCategory;

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> {
  final _recorder = AudioRecorder();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _storageService = StorageService();

  bool _isRecording = false;
  bool _hasRecording = false;
  bool _submitting = false;
  String? _filePath;
  String? _theme;
  int? _similarCount;
  late SubmissionCategory _category = widget.initialCategory ?? SubmissionCategory.problem;
  Duration _elapsed = Duration.zero;
  LatLng? _pin;
  double? _homeLat;
  double? _homeLng;

  @override
  void initState() {
    super.initState();
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _hasRecording = path != null;
        _filePath = path;
      });
      return;
    }
    if (await _recorder.hasPermission()) {
      final dir = await _tempPath();
      await _recorder.start(const RecordConfig(), path: dir);
      setState(() {
        _isRecording = true;
        _hasRecording = false;
        _elapsed = Duration.zero;
      });
      _tickTimer();
    }
  }

  Future<String> _tempPath() async {
    return '${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  void _tickTimer() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isRecording) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    }
  }

  void _reRecord() {
    setState(() {
      _hasRecording = false;
      _filePath = null;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _submit() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _filePath == null) return;
    setState(() => _submitting = true);

    final profile = await _firestoreService.getUser(uid);
    String? mediaUrl;
    try {
      mediaUrl = await _storageService.uploadSubmissionMedia(
        userId: uid,
        file: File(_filePath!),
        extension: 'm4a',
      );
    } catch (_) {
      // Ticket must still be created even if the upload fails — the citizen
      // never loses their receipt (Section 6). Transcription simply won't
      // run server-side without a mediaUrl.
    }

    final draft = SubmissionModel(
      id: '',
      userId: uid,
      type: SubmissionType.voice,
      category: _category,
      inputMode: 'voice',
      mediaUrl: mediaUrl,
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
    if (mounted) context.go('/confirmation', extra: saved);
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReport = _category == SubmissionCategory.problem;
    return Scaffold(
      appBar: AppBar(title: Text(isReport ? 'Report by Voice' : 'Suggest by Voice')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              InputModeSwitcher(current: 'voice', category: _category),
              const SizedBox(height: 16),
              CategoryToggleWidget(
                selected: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 20),
              RecordingWaveform(isRecording: _isRecording),
              const SizedBox(height: 12),
              Text(
                '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 20, fontFeatures: [
                  FontFeature.tabularFigures(),
                ]),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _toggleRecording,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor:
                      _isRecording ? AppColors.coralRed : AppColors.marigoldOrange,
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              if (_hasRecording) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _reRecord,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Re-record'),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
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
              Text('Pick a category (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              ThemePickerWidget(
                selected: _theme,
                onSelected: _selectTheme,
              ),
              const SizedBox(height: 24),
              if (_hasRecording)
                PrimaryButton(
                  label: isReport ? 'Submit Report' : 'Submit Suggestion',
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
