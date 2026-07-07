import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/submission_model.dart';
import '../../l10n/app_localizations.dart';
import 'theme_icon_chip.dart';

/// "Looks like: X" — the AI-suggested category, always shown as a
/// confirmable chip rather than auto-assigned silently. Shared across the
/// text/voice/photo compose screens.
class ThemeConfirmChip extends StatelessWidget {
  const ThemeConfirmChip({
    super.key,
    required this.themeId,
    required this.onConfirm,
    required this.onDismiss,
  });

  final String themeId;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(themeId);
    return InkWell(
      onTap: onConfirm,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kThemeIcons[themeId], size: 16, color: color),
            const SizedBox(width: 6),
            Text(AppLocalizations.of(context).looksLike(kThemeLabels[themeId] ?? ''),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: color)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 15, color: color.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The clustering feature made visible — rather than a black-box
/// classifier, the citizen sees the AI cluster count directly. Wording
/// differs by category: a report joins an existing open problem, a
/// suggestion gains "others have asked for this too" social proof.
class SimilarCountChip extends StatelessWidget {
  const SimilarCountChip({super.key, required this.count, required this.category});

  final int count;
  final SubmissionCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isProblem = category == SubmissionCategory.problem;
    final label = isProblem
        ? l10n.similarOpenProblems(count)
        : l10n.othersAskedToo(count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.tealMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, size: 16, color: AppColors.tealDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.tealDeep, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
