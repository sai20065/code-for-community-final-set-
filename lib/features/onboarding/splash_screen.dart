import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/auth_state_provider.dart';
import '../../app/providers/current_user_profile_provider.dart';
import '../../app/providers/onboarding_progress_provider.dart';
import '../../app/providers/selected_language_provider.dart';
import '../../app/theme.dart';
import '../../core/models/user_model.dart';

/// Routes to: Welcome (not signed in), the MP Dashboard (signed in as an
/// official — checked first, since an official's Firebase session must
/// never fall through to the citizen onboarding-step machinery below), the
/// correct resume point in citizen signup, or Home (onboarding already
/// completed) — decided from `shared_preferences` + auth state + the
/// signed-in user's own role, so a killed-and-reopened app never restarts
/// from Welcome/Language Select.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.6)),
    );
    _logoController.forward();
    _route();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    final minSplash = Future.delayed(const Duration(milliseconds: 1500));
    final languageNotifier = ref.read(selectedLanguageProvider.notifier);
    final progressNotifier = ref.read(onboardingProgressProvider.notifier);

    final user = await ref.read(authStateProvider.future);
    await Future.wait([languageNotifier.ready, progressNotifier.ready, minSplash]);
    if (!mounted) return;

    if (user != null) {
      final profile = await ref.read(firestoreServiceProvider).getUser(user.uid);
      if (profile?.role == UserRole.official) {
        context.go('/official/dashboard');
        return;
      }
      // `signupCompletedAt` on the Firestore profile is the authoritative
      // "this citizen has a real, saved profile" signal — it survives a
      // reinstall/new device, unlike `onboardingProgressProvider`, which is
      // only local `shared_preferences` and would otherwise wrongly restart
      // onboarding for a citizen who signs back in on a fresh install.
      if (profile?.signupCompletedAt != null) {
        context.go('/home');
        return;
      }
      switch (ref.read(onboardingProgressProvider)) {
        case OnboardingStep.identity:
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

    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.indigo,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icon/logo.png', width: 120, height: 120),
                    const SizedBox(height: 16),
                    const Text(
                      'Prajadhwani',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Voice of the People',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
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
