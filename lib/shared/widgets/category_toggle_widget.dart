import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/submission_model.dart';
import '../../l10n/app_localizations.dart';

/// "Report a problem" vs "Suggest a development work" — a citizen picks
/// this before describing their ticket (usually already preset by which
/// Home FAB launched the flow). Defaults to problem so existing behavior
/// is preserved for anyone who doesn't interact with it.
class CategoryToggleWidget extends StatelessWidget {
  const CategoryToggleWidget({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SubmissionCategory selected;
  final ValueChanged<SubmissionCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _Segment(
            label: l10n.reportAProblem,
            icon: Icons.report_problem_rounded,
            isSelected: selected == SubmissionCategory.problem,
            onTap: () => onChanged(SubmissionCategory.problem),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Segment(
            label: l10n.suggestDevelopmentWork,
            icon: Icons.lightbulb_rounded,
            isSelected: selected == SubmissionCategory.feedback,
            onTap: () => onChanged(SubmissionCategory.feedback),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.trustBlue.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.trustBlue : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? AppColors.trustBlue : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.trustBlue : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
