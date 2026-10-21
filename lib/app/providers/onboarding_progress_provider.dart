import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingStepKey = 'onboarding_step';

/// Which step of the signup flow (account → Basic Info → Location →
/// done) the user last reached. Persisted so a killed-and-reopened app
/// resumes at the right screen instead of restarting from Splash/Language
/// Select every time.
enum OnboardingStep { identity, basicInfo, location, done }

class OnboardingProgressNotifier extends StateNotifier<OnboardingStep> {
  OnboardingProgressNotifier() : super(OnboardingStep.identity) {
    _load();
  }

  final Completer<void> _readyCompleter = Completer<void>();

  /// Resolves once the persisted step has been read, so splash routing
  /// never acts on the default `phone` value before the disk read completes.
  Future<void> get ready => _readyCompleter.future;

  Future<void> _load() async {
    // Always release `ready`, even if the disk read fails — otherwise the
    // splash screen waits on it forever.
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.get(_kOnboardingStepKey);
      if (index is int && index >= 0 && index < OnboardingStep.values.length) {
        state = OnboardingStep.values[index];
      }
    } catch (_) {
      // Keep the default step.
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> advanceTo(OnboardingStep step) async {
    state = step;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOnboardingStepKey, step.index);
  }

  Future<void> reset() async {
    state = OnboardingStep.identity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingStepKey);
  }
}

final onboardingProgressProvider =
    StateNotifierProvider<OnboardingProgressNotifier, OnboardingStep>(
  (ref) => OnboardingProgressNotifier(),
);
