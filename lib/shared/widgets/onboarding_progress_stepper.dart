import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Signature "voice waveform" motif (ties to "Dhvani"/voice input): a row of
/// bars stands in for the plain-dot step indicator, each step a bar whose
/// height/color reflects done/current/pending — reads as an equalizer
/// rather than a generic progress dial.
class OnboardingProgressStepper extends StatelessWidget {
  const OnboardingProgressStepper({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(totalSteps, (i) {
        final stepNumber = i + 1;
        final isDone = stepNumber < currentStep;
        final isCurrent = stepNumber == currentStep;
        final active = isDone || isCurrent;
        // Varying bar heights read as a waveform rather than uniform dots.
        final baseHeight = const [10.0, 18.0, 14.0, 20.0][i % 4];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 7,
            height: isCurrent ? baseHeight + 6 : baseHeight,
            decoration: BoxDecoration(
              color: active ? AppColors.indigo : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
