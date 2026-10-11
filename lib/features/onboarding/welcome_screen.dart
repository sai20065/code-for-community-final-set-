import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// First screen after Splash for anyone not yet signed in — three ways in:
///
/// 1. **Citizens**: Sign Up (new) or Sign In (returning), deliberately
///    separate flows, see `lib/core/services/auth_service.dart`.
/// 2. **Government**: MPs, MLAs and local officers (BBMP ward officers,
///    Tahsildars, District officers) → `GovLoginScreen`.
/// 3. **Prajadhwani Admin**: platform administration (approving officials)
///    → `AdminLoginScreen`.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: appCardShadow,
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/icon/logo.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _WaveformLogo(),
                  const SizedBox(height: 6),
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
                    style:
                        const TextStyle(color: AppColors.inkFaint, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  _EntryCard(
                    color: AppColors.saffron,
                    deep: AppColors.saffronDeep,
                    icon: Icons.record_voice_over_rounded,
                    title: l10n.welcomeCitizenTitle,
                    body: l10n.welcomeCitizenBody,
                    primaryLabel: l10n.newHereSignUp,
                    onPrimary: () => context.go('/signup'),
                    secondaryLabel: l10n.alreadyHaveAccountSignInShort,
                    onSecondary: () => context.go('/signin'),
                    footnote: l10n.welcomeAnonymityNote,
                  ),
                  const SizedBox(height: 14),
                  _EntryCard(
                    color: AppColors.indigo,
                    deep: AppColors.indigoDeep,
                    icon: Icons.account_balance_rounded,
                    title: l10n.welcomeGovTitle,
                    body: l10n.welcomeGovBody,
                    primaryLabel: l10n.signIn,
                    onPrimary: () => context.go('/gov/login'),
                    secondaryLabel: l10n.welcomeGovRegister,
                    onSecondary: () => context.go('/gov/register'),
                  ),
                  const SizedBox(height: 14),
                  _AdminEntry(
                    title: l10n.welcomeAdminTitle,
                    body: l10n.welcomeAdminBody,
                    onTap: () => context.go('/admin/login'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => context.go('/public/area'),
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: Text(l10n.welcomeJustBrowsing),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One large, colour-coded way in (Citizen / Government).
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.color,
    required this.deep,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.footnote,
  });

  final Color color;
  final Color deep;
  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: appCardShadow,
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: deep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  color: AppColors.inkSoft, fontSize: 13, height: 1.45)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor:
                  color == AppColors.saffron ? AppColors.ink : Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(primaryLabel,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: onSecondary,
            style: OutlinedButton.styleFrom(
              foregroundColor: deep,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(secondaryLabel),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(footnote!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.inkFaint, fontSize: 11, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _AdminEntry extends StatelessWidget {
  const _AdminEntry({
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tealMist,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.teal,
                child: Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.tealDeep)),
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.tealDeep)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.tealDeep),
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
    // The brand's 4-bar voice waveform, kept as a small accent under the
    // logo.
    const heights = [8.0, 15.0, 11.0, 17.0];
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in heights)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 5,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.saffron,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
