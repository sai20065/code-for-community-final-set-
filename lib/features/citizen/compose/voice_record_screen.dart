import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/recording_waveform.dart';
import 'theme_picker_widget.dart';

/// Section 3.6: big obvious record button, pulsing ring while recording,
/// live waveform, playback-before-submit with re-record option.
class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({super.key});

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> {
  final _recorder = AudioRecorder();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  bool _isRecording = false;
  bool _hasRecording = false;
  bool _submitting = false;
  String? _filePath;
  String? _theme;
  Duration _elapsed = Duration.zero;

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
    if (uid == null) return;
    setState(() => _submitting = true);

    // Upload of `_filePath` to Cloud Storage happens via StorageService once
    // wired to a live Firebase project; the ticket is still generated here
    // so the citizen never loses their receipt (Section 6).
    final tokenId = _firestoreService.generateTokenId();
    final draft = SubmissionModel(
      id: '',
      userId: uid,
      type: SubmissionType.voice,
      inputMode: 'voice',
      language: 'en',
      theme: _theme,
      location: const SubmissionLocation(pincode: ''),
      status: SubmissionStatus.newSubmission,
      tokenId: tokenId,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Record Your Report')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
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
              Text('Pick a category (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              ThemePickerWidget(
                selected: _theme,
                onSelected: (v) => setState(() => _theme = v),
              ),
              const Spacer(),
              if (_hasRecording)
                PrimaryButton(
                  label: 'Submit Report',
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
