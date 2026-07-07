import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';

/// Step 6 (final): a clear, calm "you're set up" moment before the citizen
/// ever sees the main app — closes the onboarding flow with an explicit
/// success state instead of silently dropping onto Home once Location Setup
/// saves.
class OnboardingDoneScreen extends StatelessWidget {
  const OnboardingDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.tealMist,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.teal,
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.youAreSetUp,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.tealDeep),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.setUpBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.tealDeep, fontSize: 13.5, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: l10n.enterApp,
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
