import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Slim progress dots at the top of signup screens (Phone → Basic Info →
/// Location), 1-indexed against [totalSteps] — reduces abandonment by
/// showing users how many steps remain (Phase 2, Section 2).
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
      children: List.generate(totalSteps, (i) {
        final stepNumber = i + 1;
        final isDone = stepNumber < currentStep;
        final isCurrent = stepNumber == currentStep;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isCurrent ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: (isDone || isCurrent)
                  ? AppColors.trustBlue
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
