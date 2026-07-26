import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/primary_button.dart';

/// First screen after Splash for anyone not yet signed in.
///
/// Citizens get the whole screen — Sign Up (new) vs Sign In (returning),
/// deliberately separate flows, see `lib/core/services/auth_service.dart`.
/// Government access lives behind one button into its own screen
/// (`GovLoginScreen`), since officials are provisioned out-of-band rather
/// than self-registering and are a tiny fraction of visitors.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              const SizedBox(height: 20),
              const Expanded(child: _CitizenEntry()),
              const Divider(height: 28),
              OutlinedButton.icon(
                onPressed: () => context.go('/gov/login'),
                icon: const Icon(Icons.account_balance_rounded, size: 18),
                label: Text(l10n.tabMpOffice),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.indigoDeep,
                  side: const BorderSide(color: AppColors.indigoMist),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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

/// Citizen body — a chooser between the two deliberately-separate flows
/// (`SignUpScreen` for new citizens, `SignInScreen` for returning ones). See
/// `lib/core/services/auth_service.dart` for why these aren't combined into
/// one "continue" action.
class _CitizenEntry extends StatelessWidget {
  const _CitizenEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Spacer(),
        const Icon(Icons.record_voice_over_rounded,
            size: 72, color: AppColors.indigoMist),
        const SizedBox(height: 16),
        Text(
          l10n.citizenIntro,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.welcomeAnonymityNote,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.inkFaint, fontSize: 11.5, height: 1.4),
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
