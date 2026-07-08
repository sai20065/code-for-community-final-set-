import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services/mp_credentials_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/primary_button.dart';

/// Shared by both MP credential-recovery flows — first-time setup and
/// forgot-credentials share the exact same "unique ID + email" form and
/// success/error handling, differing only in copy and which Cloud
/// Function they call (see `functions/src/officials/`).
class MpCredentialsRequestScreen extends StatefulWidget {
  const MpCredentialsRequestScreen({super.key, required this.isFirstTime});

  final bool isFirstTime;

  @override
  State<MpCredentialsRequestScreen> createState() => _MpCredentialsRequestScreenState();
}

class _MpCredentialsRequestScreenState extends State<MpCredentialsRequestScreen> {
  final _uniqueIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _service = MpCredentialsService();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    final uniqueId = _uniqueIdController.text.trim();
    final email = _emailController.text.trim();
    if (uniqueId.isEmpty || email.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isFirstTime) {
        await _service.firstTimeSetup(uniqueId: uniqueId, email: email);
      } else {
        await _service.forgotCredentials(uniqueId: uniqueId, email: email);
      }
      if (mounted) setState(() => _sent = true);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? AppLocalizations.of(context).somethingWentWrong);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).somethingWentWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _uniqueIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
        ),
        title: Text(widget.isFirstTime ? l10n.mpFirstTimeSetupTitle : l10n.mpForgotCredentialsTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent
              ? _SuccessMessage(email: _emailController.text.trim())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      widget.isFirstTime ? Icons.badge_outlined : Icons.lock_reset_rounded,
                      size: 56,
                      color: AppColors.indigoMist,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isFirstTime ? l10n.mpFirstTimeSetupHint : l10n.mpForgotCredentialsHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _uniqueIdController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(hintText: l10n.mpUniqueId),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(hintText: l10n.emailAddress),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: l10n.sendMyCredentials,
                      icon: Icons.email_outlined,
                      loading: _loading,
                      onPressed: _loading ? null : _submit,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_rounded, size: 64, color: AppColors.leafGreen),
        const SizedBox(height: 16),
        Text(
          l10n.credentialsSentTo(email),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.checkYourInbox,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkFaint, fontSize: 12.5),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: l10n.backToSignIn,
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.go('/welcome'),
        ),
      ],
    );
  }
}
