import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/submission_model.dart';

/// Horizontal Filed → Acknowledged → In Progress → Resolved stepper for
/// problem reports. Visible progress reduces the "complaint disappeared
/// into a bureaucracy" feeling that erodes trust in civic apps. (Internal
/// `SubmissionStatus` values are unchanged — only the citizen-facing
/// labels were relabeled for the new brand voice.)
class StatusStepper extends StatelessWidget {
  const StatusStepper({super.key, required this.status, this.compact = false});

  final SubmissionStatus status;
  final bool compact;

  static const _steps = [
    ('new', 'Filed'),
    ('reviewed', 'Acknowledged'),
    ('inProgress', 'In Progress'),
    ('resolved', 'Resolved'),
  ];

  int get _activeIndex {
    switch (status) {
      case SubmissionStatus.newSubmission:
        return 0;
      case SubmissionStatus.reviewed:
        return 1;
      case SubmissionStatus.inProgress:
        return 2;
      case SubmissionStatus.resolved:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftDone = (i ~/ 2) <= active - 1;
          return Expanded(
            child: Container(
              height: 3,
              color: leftDone ? AppColors.leafGreen : Colors.grey.shade300,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final (key, label) = _steps[stepIndex];
        final isDone = stepIndex <= active;
        final color = isDone ? statusColor(key) : Colors.grey.shade300;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: compact ? 14 : 20,
              height: compact ? 14 : 20,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        );
      }),
    );
  }
}
