import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/auth_state_provider.dart';
import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_common.dart';

/// Returning-citizen Sign In: username + password, with "Forgot password?"
/// one tap away. Never creates an account — a correct password for an
/// account whose profile was never finished resumes onboarding instead of
/// dropping the citizen on an empty Home.
class CitizenSignInScreen extends ConsumerStatefulWidget {
  const CitizenSignInScreen({super.key});

  @override
  ConsumerState<CitizenSignInScreen> createState() =>
      _CitizenSignInScreenState();
}

class _CitizenSignInScreenState extends ConsumerState<CitizenSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authServiceProvider).signInCitizen(
            username: _usernameController.text,
            password: _passwordController.text,
          );
      final profile =
          await ref.read(firestoreServiceProvider).getUser(user.uid);
      if (!mounted) return;
      if (profile?.role == UserRole.official) {
        context.go('/gov/dashboard');
        return;
      }
      if (profile == null || !profile.isProfileComplete) {
        final resume = profile?.resumeOnboardingRoute ?? '/signup/basic-info';
        await ref.read(onboardingProgressProvider.notifier).advanceTo(
            resume == '/signup/location'
                ? OnboardingStep.location
                : OnboardingStep.basicInfo);
        if (mounted) context.go(resume);
        return;
      }
      await ref
          .read(onboardingProgressProvider.notifier)
          .advanceTo(OnboardingStep.done);
      if (mounted) context.go('/home');
    } on CitizenAuthException catch (e) {
      debugPrint('Sign in failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = citizenAuthErrorText(e.failure, l10n);
      });
    } catch (e) {
      debugPrint('Sign in failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = l10n.couldNotContinue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      title: l10n.welcomeBackTitle,
      subtitle: l10n.signInSubtitle,
      footer: Center(
        child: TextButton(
          onPressed: () => context.go('/signup'),
          child: Text(l10n.dontHaveAccountSignUp),
        ),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(
                  labelText: l10n.usernameLabel,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.usernameTooShort : null,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _passwordController,
                label: l10n.password,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) =>
                    (v ?? '').isEmpty ? l10n.passwordTooShort : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password',
                      extra: _usernameController.text.trim()),
                  child: Text(l10n.forgotPasswordLink),
                ),
              ),
              const SizedBox(height: 4),
              if (_error != null) AuthErrorBanner(_error!),
              PrimaryButton(
                label: l10n.signIn,
                icon: Icons.login_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
