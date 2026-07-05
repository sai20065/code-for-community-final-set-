import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/category_toggle_widget.dart';
import '../../../shared/widgets/primary_button.dart';
import 'theme_picker_widget.dart';

/// Text-mode ticket compose: large text field, problem/feedback toggle,
/// optional theme tag, ends at the shared Ticket Confirmation receipt
/// screen. Location/language are always the citizen's own (from their
/// profile) — never freely chosen — since citizens may only report on
/// their own area.
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
  SubmissionCategory _category = SubmissionCategory.problem;
  bool _submitting = false;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Describe the Ticket')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CategoryToggleWidget(
                selected: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 20),
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
                label: 'Submit Ticket',
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
