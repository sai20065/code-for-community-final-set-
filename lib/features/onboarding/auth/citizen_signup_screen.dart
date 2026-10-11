import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/auth_state_provider.dart';
import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_common.dart';

enum _Availability { unknown, checking, available, taken }

/// New-citizen Sign Up: name, username, password, and a security question
/// for password recovery. Nothing else — no email, phone, OTP or ID upload.
///
/// On success the account and `users/{uid}` profile (with
/// `signupCompletedAt`) exist immediately, so a citizen who quits halfway
/// through the remaining onboarding (language → age → home location) can
/// still sign back in. The security question is saved through a Cloud
/// Function because its answer must only ever exist as a server-side hash.
class CitizenSignUpScreen extends ConsumerStatefulWidget {
  const CitizenSignUpScreen({super.key});

  @override
  ConsumerState<CitizenSignUpScreen> createState() =>
      _CitizenSignUpScreenState();
}

class _CitizenSignUpScreenState extends ConsumerState<CitizenSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _answerController = TextEditingController();
  final _recovery = AccountRecoveryService();

  String _questionId = kSecurityQuestionIds.first;
  _Availability _availability = _Availability.unknown;
  Timer? _debounce;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  /// Debounced so typing "ravikumar" doesn't fire nine reads.
  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    if (AuthService.validateUsername(value) != null) {
      setState(() => _availability = _Availability.unknown);
      return;
    }
    setState(() => _availability = _Availability.checking);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final username = AuthService.normalizeUsername(value);
      bool taken;
      try {
        taken = await ref.read(firestoreServiceProvider).isUsernameTaken(username);
      } catch (_) {
        // Can't tell — let account creation be the judge.
        if (mounted) setState(() => _availability = _Availability.unknown);
        return;
      }
      if (!mounted ||
          AuthService.normalizeUsername(_usernameController.text) != username) {
        return;
      }
      setState(() => _availability =
          taken ? _Availability.taken : _Availability.available);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_availability == _Availability.taken) {
      setState(() => _error = l10n.usernameTaken);
      return;
    }

    setState(() => _submitting = true);
    final username = AuthService.normalizeUsername(_usernameController.text);
    final auth = ref.read(authServiceProvider);
    final firestore = ref.read(firestoreServiceProvider);
    try {
      final user = await auth.signUpCitizen(
        username: username,
        password: _passwordController.text,
      );
      // The account already exists at this point, so a failed reservation
      // must not strand the citizen on an error screen: the name is still
      // unique in Firebase Auth, this doc only powers the early warning.
      try {
        await firestore.reserveUsername(username: username, uid: user.uid);
      } catch (e) {
        debugPrint('reserveUsername failed: $e');
      }
      final profile = await firestore.getOrCreateUser(
        uid: user.uid,
        preferredLanguage: 'en',
        name: _nameController.text.trim(),
      );
      await firestore.upsertUser(profile.copyWith(
        name: _nameController.text.trim(),
        username: username,
        signInMethod: SignInMethod.password,
        signupCompletedAt: DateTime.now(),
      ));
      // Best effort: the account is already usable without it, and the
      // citizen can set it again later from Profile.
      try {
        await _recovery.setSecurityQuestion(
          questionId: _questionId,
          answer: _answerController.text,
        );
      } catch (e) {
        debugPrint('setSecurityQuestion failed: $e');
      }
      await ref
          .read(onboardingProgressProvider.notifier)
          .advanceTo(OnboardingStep.basicInfo);
      if (mounted) context.go('/language');
    } on CitizenAuthException catch (e) {
      debugPrint('Sign up failed: $e');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = citizenAuthErrorText(e.failure, l10n);
        if (e.failure == CitizenAuthFailure.usernameTaken) {
          _availability = _Availability.taken;
        }
      });
    } catch (e) {
      debugPrint('Sign up failed: $e');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.couldNotContinue;
      });
    }
  }

  Widget? _availabilityIcon() {
    return switch (_availability) {
      _Availability.checking => const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      _Availability.available =>
        const Icon(Icons.check_circle_rounded, color: AppColors.teal),
      _Availability.taken =>
        const Icon(Icons.cancel_rounded, color: AppColors.vermilion),
      _Availability.unknown => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      title: l10n.createAccountTitle,
      subtitle: l10n.createAccountSubtitle,
      footer: Center(
        child: TextButton(
          onPressed: () => context.go('/signin'),
          child: Text(l10n.alreadyHaveAccountSignInShort),
        ),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.nameRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.newUsername],
                onChanged: _onUsernameChanged,
                decoration: InputDecoration(
                  labelText: l10n.usernameLabel,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  suffixIcon: _availabilityIcon(),
                  helperText: switch (_availability) {
                    _Availability.available => l10n.usernameAvailable,
                    _Availability.taken => l10n.usernameTaken,
                    _ => l10n.usernameHelper,
                  },
                  helperStyle: TextStyle(
                    color: switch (_availability) {
                      _Availability.available => AppColors.teal,
                      _Availability.taken => AppColors.vermilion,
                      _ => AppColors.inkFaint,
                    },
                  ),
                ),
                validator: (v) => validateUsernameField(v, l10n),
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _passwordController,
                label: l10n.password,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => validateNewPasswordField(v, l10n),
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _confirmController,
                label: l10n.confirmPasswordLabel,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => v != _passwordController.text
                    ? l10n.passwordsDontMatch
                    : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 18, color: AppColors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.securityQuestionIntro,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SecurityQuestionFields(
                questionId: _questionId,
                onQuestionChanged: (id) => setState(() => _questionId = id),
                answerController: _answerController,
              ),
              const SizedBox(height: 20),
              if (_error != null) AuthErrorBanner(_error!),
              PrimaryButton(
                label: l10n.createAccountButton,
                icon: Icons.person_add_alt_1_rounded,
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
