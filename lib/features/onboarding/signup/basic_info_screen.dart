import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/onboarding_progress_stepper.dart';
import '../../../shared/widgets/primary_button.dart';

/// Step 2 of 4: name + age on one screen, "Next" disabled until both fields
/// are valid (Phase 2, Section 6).
class BasicInfoScreen extends ConsumerStatefulWidget {
  const BasicInfoScreen({super.key});

  @override
  ConsumerState<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends ConsumerState<BasicInfoScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillName();
  }

  Future<void> _prefillName() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final existing = await _firestoreService.getUser(uid);
    if (mounted && existing?.name != null) {
      setState(() => _nameController.text = existing!.name!);
    }
  }

  bool get _isValid {
    final age = int.tryParse(_ageController.text.trim());
    return _nameController.text.trim().isNotEmpty &&
        age != null &&
        age > 0 &&
        age < 120;
  }

  Future<void> _next() async {
    if (!_isValid) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    final existing = await _firestoreService.getUser(uid);
    final updated = (existing ??
            (throw StateError('User document missing after sign-in')))
        .copyWith(
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
    );
    await _firestoreService.upsertUser(updated);
    await ref
        .read(onboardingProgressProvider.notifier)
        .advanceTo(OnboardingStep.location);
    if (mounted) context.go('/signup/location');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const OnboardingProgressStepper(currentStep: 2),
              const SizedBox(height: 32),
              const Icon(Icons.person_rounded, size: 56),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(hintText: l10n.yourName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(hintText: l10n.age),
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              PrimaryButton(
                label: l10n.next,
                icon: Icons.arrow_forward_rounded,
                loading: _saving,
                onPressed: _isValid ? _next : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
