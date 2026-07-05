import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/auth_state_provider.dart';
import '../../app/providers/onboarding_progress_provider.dart';
import '../../app/providers/selected_language_provider.dart';
import '../../app/theme.dart';

/// Routes to Language Select (no language chosen yet), the correct resume
/// point in signup (language chosen, mid-onboarding), or Home (onboarding
/// already completed) — decided from `shared_preferences` + auth state so a
/// killed-and-reopened app never restarts from Splash/Language Select
/// (Phase 2, Sections 3 and 9).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final minSplash = Future.delayed(const Duration(milliseconds: 1500));
    final languageNotifier = ref.read(selectedLanguageProvider.notifier);
    final progressNotifier = ref.read(onboardingProgressProvider.notifier);

    final user = await ref.read(authStateProvider.future);
    await Future.wait([languageNotifier.ready, progressNotifier.ready, minSplash]);
    if (!mounted) return;

    if (user != null) {
      switch (ref.read(onboardingProgressProvider)) {
        case OnboardingStep.phone:
        case OnboardingStep.basicInfo:
          context.go('/signup/basic-info');
          break;
        case OnboardingStep.location:
          context.go('/signup/location');
          break;
        case OnboardingStep.done:
          context.go('/home');
          break;
      }
      return;
    }

    if (ref.read(selectedLanguageProvider) == null) {
      context.go('/language');
      return;
    }
    context.go('/signup/phone');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trustBlue,
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.record_voice_over_rounded,
                      size: 84, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Praja Dhvani',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Voice of the People',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) {
              return Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: AppColors.tricolorStrip),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
