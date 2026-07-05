import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/primary_button.dart';
import 'theme_picker_widget.dart';

/// Section 4, screen 7 (text mode): large text field, optional theme tag,
/// ends at the shared Submission Confirmation receipt screen.
class TextComposeScreen extends StatefulWidget {
  const TextComposeScreen({super.key});

  @override
  State<TextComposeScreen> createState() => _TextComposeScreenState();
}

class _TextComposeScreenState extends State<TextComposeScreen> {
  final _controller = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  String? _theme;
  bool _submitting = false;

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    final tokenId = _firestoreService.generateTokenId();
    final now = DateTime.now();
    final draft = SubmissionModel(
      id: '',
      userId: uid,
      type: SubmissionType.text,
      inputMode: 'text',
      rawText: text,
      language: 'en',
      theme: _theme,
      location: const SubmissionLocation(pincode: ''),
      status: SubmissionStatus.newSubmission,
      tokenId: tokenId,
      createdAt: now,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Describe the Problem')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                maxLines: 6,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: "What's the problem? (e.g. Streetlight not working)",
                ),
              ),
              const SizedBox(height: 24),
              Text('Pick a category (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              ThemePickerWidget(
                selected: _theme,
                onSelected: (v) => setState(() => _theme = v),
              ),
              const SizedBox(height: 32),
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
