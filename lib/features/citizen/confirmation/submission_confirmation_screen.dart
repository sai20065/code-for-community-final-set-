import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import '../../../shared/widgets/ticket_receipt_card.dart';

/// Section 4, screen 8: receipt-card UI with checkmark + ticket ID.
/// Never let a user submit into a void (Section 3.4). Also surfaces what's
/// already known at save time (category, theme if picked/guessed, home
/// constituency) plus an explicit "AI enrichment continues in the
/// background" note, so the citizen understands the ticket isn't fully
/// processed yet — the classification/clustering pipeline
/// (`onSubmissionCreated`) runs asynchronously after this screen shows.
class SubmissionConfirmationScreen extends StatelessWidget {
  const SubmissionConfirmationScreen({super.key, required this.submission});

  final SubmissionModel submission;

  Future<void> _copyReceipt(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: submission.tokenId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).receiptCopied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSuggestion = submission.category == SubmissionCategory.feedback;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TicketReceiptCard(
                tokenId: submission.tokenId,
                createdAt: submission.createdAt,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSuggestion ? AppColors.indigoMist : AppColors.vermilionMist,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSuggestion ? l10n.badgeSuggestion : l10n.badgeReport,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSuggestion ? AppColors.indigoDeep : AppColors.vermilionDeep,
                      ),
                    ),
                  ),
                  if (submission.theme != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: categoryColor(submission.theme!).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(kThemeIcons[submission.theme], size: 13, color: categoryColor(submission.theme!)),
                          const SizedBox(width: 5),
                          Text(
                            l10n.looksLike(kThemeLabels[submission.theme] ?? submission.theme ?? ''),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: categoryColor(submission.theme!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (submission.location.constituencyId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flag_rounded, size: 13, color: AppColors.inkSoft),
                          const SizedBox(width: 5),
                          Text(
                            l10n.routedTo(submission.location.constituencyId ?? ''),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.savedInstantlyNote,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkFaint, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: l10n.trackThisTicket,
                icon: Icons.timeline_rounded,
                onPressed: () =>
                    context.go('/reports/${submission.id}', extra: submission),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copyReceipt(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.copyReceipt),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(l10n.backToHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
