import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/primary_button.dart';
import 'theme_picker_widget.dart';

/// Section 4, screen 7 (photo/video mode): camera/gallery picker, optional
/// caption field, ends at the shared Submission Confirmation screen.
class PhotoVideoScreen extends StatefulWidget {
  const PhotoVideoScreen({super.key});

  @override
  State<PhotoVideoScreen> createState() => _PhotoVideoScreenState();
}

class _PhotoVideoScreenState extends State<PhotoVideoScreen> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  File? _media;
  String? _theme;
  bool _submitting = false;

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _media = File(picked.path));
    }
  }

  Future<void> _submit() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _media == null) return;
    setState(() => _submitting = true);

    // Media upload to Cloud Storage happens via StorageService once wired
    // to a live Firebase project; the ticket is generated up front so the
    // citizen never loses their receipt (Section 6).
    final tokenId = _firestoreService.generateTokenId();
    final draft = SubmissionModel(
      id: '',
      userId: uid,
      type: SubmissionType.photo,
      inputMode: 'photo',
      rawText: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
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
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a Photo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_media != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(_media!, height: 220, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 20),
              TextField(
                controller: _captionController,
                decoration:
                    const InputDecoration(hintText: 'Add a caption (optional)'),
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
                onPressed: _media == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
