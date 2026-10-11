import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_common.dart';

enum _Step { findAccount, answer, done }

/// Forgot password, with no email or SMS anywhere: (1) enter username →
/// (2) answer your security question and choose a new password → (3) done.
///
/// All checking happens server-side (`resetPasswordWithSecurityQuestion`),
/// which compares against a salted hash and locks the account for 15
/// minutes after five wrong answers. An unknown username and an account
/// without a question get the *same* message, so this screen can't be used
/// to find out which usernames exist.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialUsername});

  final String? initialUsername;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _findKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  late final _usernameController =
      TextEditingController(text: widget.initialUsername ?? '');
  final _answerController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _recovery = AccountRecoveryService();

  _Step _step = _Step.findAccount;
  String? _questionId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _answerController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _recoveryErrorText(RecoveryFailure f, AppLocalizations l10n) {
    return switch (f) {
      RecoveryFailure.notMatched => l10n.recoveryNotMatched,
      RecoveryFailure.locked => l10n.recoveryLocked,
      RecoveryFailure.weakPassword => l10n.passwordTooShort,
      RecoveryFailure.network => l10n.authNetworkError,
      RecoveryFailure.unknown => l10n.couldNotContinue,
    };
  }

  Future<void> _findAccount() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_findKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final questionId =
          await _recovery.getSecurityQuestion(_usernameController.text);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (questionId == null) {
          _error = l10n.recoveryNoQuestion;
        } else {
          _questionId = questionId;
          _step = _Step.answer;
        }
      });
    } on RecoveryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _recoveryErrorText(e.failure, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = l10n.couldNotContinue;
      });
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_resetKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _recovery.resetPassword(
        username: _usernameController.text,
        answer: _answerController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _Step.done;
      });
    } on RecoveryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _recoveryErrorText(e.failure, l10n);
      });
    } catch (_) {
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
      title: l10n.forgotPasswordTitle,
      subtitle: switch (_step) {
        _Step.findAccount => l10n.forgotPasswordStep1,
        _Step.answer => l10n.forgotPasswordStep2,
        _Step.done => l10n.passwordResetDone,
      },
      backTo: '/signin',
      child: switch (_step) {
        _Step.findAccount => _buildFind(l10n),
        _Step.answer => _buildAnswer(l10n),
        _Step.done => _buildDone(l10n),
      },
    );
  }

  Widget _buildFind(AppLocalizations l10n) {
    return Form(
      key: _findKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _findAccount(),
            decoration: InputDecoration(
              labelText: l10n.usernameLabel,
              prefixIcon: const Icon(Icons.alternate_email_rounded),
            ),
            validator: (v) => validateUsernameField(v, l10n),
          ),
          const SizedBox(height: 16),
          if (_error != null) AuthErrorBanner(_error!),
          PrimaryButton(
            label: l10n.continueLabel,
            icon: Icons.arrow_forward_rounded,
            loading: _loading,
            onPressed: _findAccount,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswer(AppLocalizations l10n) {
    return Form(
      key: _resetKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.indigoMist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: AppColors.indigo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    securityQuestionText(_questionId!, l10n),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.indigo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _answerController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.securityAnswerLabel,
              prefixIcon: const Icon(Icons.key_rounded),
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? l10n.securityAnswerRequired
                : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _passwordController,
            label: l10n.newPasswordLabel,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => validateNewPasswordField(v, l10n),
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirmController,
            label: l10n.confirmPasswordLabel,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _reset(),
            validator: (v) =>
                v != _passwordController.text ? l10n.passwordsDontMatch : null,
          ),
          const SizedBox(height: 16),
          if (_error != null) AuthErrorBanner(_error!),
          PrimaryButton(
            label: l10n.resetPasswordButton,
            icon: Icons.lock_reset_rounded,
            loading: _loading,
            onPressed: _reset,
          ),
        ],
      ),
    );
  }

  Widget _buildDone(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.teal),
        const SizedBox(height: 16),
        PrimaryButton(
          label: l10n.backToSignIn,
          icon: Icons.login_rounded,
          onPressed: () => context.go('/signin'),
        ),
      ],
    );
  }
}
