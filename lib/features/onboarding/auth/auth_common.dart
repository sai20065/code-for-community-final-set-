import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';

/// Shared frame for Sign Up / Sign In / Forgot Password: the app logo, a
/// title and one-line subtitle, then the form on a raised card. Kept
/// deliberately plain — one column, big fields, one obvious button — so a
/// first-time smartphone user is never unsure what to do next.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.backTo = '/welcome',
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final String backTo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(backTo),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: appCardShadow,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: Image.asset('assets/icon/logo.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.inkSoft, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.paperRaised,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: appCardShadow,
                    ),
                    child: child,
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Password input with a show/hide eye toggle — typing blind on a phone
/// keyboard is the most common reason a new password "doesn't work".
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Inline error banner shown above the main button.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.vermilionMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.vermilionDeep, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.vermilionDeep, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

String? validateUsernameField(String? value, AppLocalizations l10n) {
  return switch (AuthService.validateUsername(value ?? '')) {
    UsernameProblem.tooShort => l10n.usernameTooShort,
    UsernameProblem.tooLong => l10n.usernameTooLong,
    UsernameProblem.badCharacters => l10n.usernameBadCharacters,
    null => null,
  };
}

String? validateNewPasswordField(String? value, AppLocalizations l10n) {
  if ((value ?? '').length < AuthService.minPasswordLength) {
    return l10n.passwordTooShort;
  }
  return null;
}

String citizenAuthErrorText(CitizenAuthFailure failure, AppLocalizations l10n) {
  return switch (failure) {
    CitizenAuthFailure.usernameTaken => l10n.usernameTaken,
    CitizenAuthFailure.wrongCredentials => l10n.authWrongCredentials,
    CitizenAuthFailure.weakPassword => l10n.passwordTooShort,
    CitizenAuthFailure.tooManyAttempts => l10n.authTooManyAttempts,
    CitizenAuthFailure.network => l10n.authNetworkError,
    CitizenAuthFailure.unknown => l10n.couldNotContinue,
  };
}

/// Localized text for a security-question id from [kSecurityQuestionIds].
String securityQuestionText(String id, AppLocalizations l10n) {
  return switch (id) {
    'firstSchool' => l10n.securityQuestionFirstSchool,
    'motherBirthplace' => l10n.securityQuestionMotherBirthplace,
    'favouriteFood' => l10n.securityQuestionFavouriteFood,
    'childhoodFriend' => l10n.securityQuestionChildhoodFriend,
    'firstVehicle' => l10n.securityQuestionFirstVehicle,
    _ => id,
  };
}

/// Question picker + answer field, used by Sign Up and by Profile's
/// "Change security question".
class SecurityQuestionFields extends StatelessWidget {
  const SecurityQuestionFields({
    super.key,
    required this.questionId,
    required this.onQuestionChanged,
    required this.answerController,
  });

  final String questionId;
  final ValueChanged<String> onQuestionChanged;
  final TextEditingController answerController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: questionId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.securityQuestionLabel,
            prefixIcon: const Icon(Icons.help_outline_rounded),
          ),
          items: [
            for (final id in kSecurityQuestionIds)
              DropdownMenuItem(
                value: id,
                child: Text(securityQuestionText(id, l10n),
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onQuestionChanged(v);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: answerController,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.securityAnswerLabel,
            prefixIcon: const Icon(Icons.key_rounded),
            helperText: l10n.securityAnswerHelper,
            helperMaxLines: 2,
          ),
          validator: (v) => (v ?? '').trim().length < 2
              ? l10n.securityAnswerRequired
              : null,
        ),
      ],
    );
  }
}
