import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/primary_button.dart';

/// First screen after Splash for anyone not yet signed in: "Citizen" vs
/// "MP office" tabs (per the brand brief's two-tab login). Citizen tab is a
/// chooser between `SignUpScreen` (new citizens) and `SignInScreen`
/// (returning citizens) — deliberately separate flows, see
/// `lib/core/services/auth_service.dart`. MP office tab is a real
/// constituency-ID + password login, since officials are provisioned
/// out-of-band rather than self-registering.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _mpTab = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const _WaveformLogo(),
              const SizedBox(height: 10),
              Text(
                'Prajadhwani',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.indigoDeep),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.appTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkFaint, fontSize: 13),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(child: _TabButton(label: l10n.tabCitizen, selected: !_mpTab, onTap: () => setState(() => _mpTab = false))),
                    Expanded(child: _TabButton(label: l10n.tabMpOffice, selected: _mpTab, onTap: () => setState(() => _mpTab = true))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _mpTab ? const _MpLoginForm() : const _CitizenEntry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformLogo extends StatelessWidget {
  const _WaveformLogo();

  @override
  Widget build(BuildContext context) {
    const heights = [16.0, 30.0, 22.0, 34.0];
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in heights)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 8,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.saffron,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// Citizen tab body — a simple chooser between the two deliberately-separate
/// flows (`SignUpScreen` for new citizens, `SignInScreen` for returning
/// ones). See `lib/core/services/auth_service.dart` for why these aren't
/// combined into one "continue" action.
class _CitizenEntry extends StatelessWidget {
  const _CitizenEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Spacer(),
        const Icon(Icons.record_voice_over_rounded, size: 72, color: AppColors.indigoMist),
        const SizedBox(height: 16),
        Text(
          l10n.citizenIntro,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.welcomeAnonymityNote,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkFaint, fontSize: 11.5, height: 1.4),
        ),
        const Spacer(),
        PrimaryButton(
          label: l10n.newHereSignUp,
          icon: Icons.arrow_forward_rounded,
          onPressed: () => context.go('/signup'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/signin'),
          child: Text(l10n.alreadyHaveAccountSignIn),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MpLoginForm extends StatefulWidget {
  const _MpLoginForm();

  @override
  State<_MpLoginForm> createState() => _MpLoginFormState();
}

class _MpLoginFormState extends State<_MpLoginForm> {
  final _constituencyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (_constituencyController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signInOfficial(
        constituencyId: _constituencyController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/official/dashboard');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).couldNotSignInOfficial;
      });
    }
  }

  @override
  void dispose() {
    _constituencyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _constituencyController,
          decoration: InputDecoration(hintText: l10n.constituencyId),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(hintText: l10n.password),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
        ],
        const Spacer(),
        PrimaryButton(
          label: l10n.signIn,
          icon: Icons.login_rounded,
          loading: _loading,
          onPressed: _login,
        ),
      ],
    );
  }
}
