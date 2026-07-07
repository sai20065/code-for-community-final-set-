import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/status_stepper.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

Future<void> _copyReceipt(BuildContext context, String tokenId) async {
  await Clipboard.setData(ClipboardData(text: tokenId));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).receiptCopied)),
    );
  }
}

/// "Mine": every ticket the citizen has filed. Suggestions show their rank
/// within category + supporter count + an outcome badge once resolved;
/// problem reports show the Filed→Acknowledged→In Progress→Resolved
/// stepper — the two ticket types track fundamentally different things
/// (community backing vs. municipal workflow), so they read differently.
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.myTicketsTitle),
      ),
      body: uid == null
          ? Center(child: Text(l10n.pleaseSignIn))
          : StreamBuilder<List<SubmissionModel>>(
              stream: firestoreService.watchUserSubmissions(uid),
              builder: (context, snapshot) {
                final submissions = snapshot.data ?? const [];
                if (submissions.isEmpty) {
                  return Center(child: Text(l10n.noTicketsYet));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: submissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = submissions[index];
                    return _TicketCard(
                      submission: s,
                      onTap: () => context.go('/reports/${s.id}', extra: s),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.submission, required this.onTap});

  final SubmissionModel submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSuggestion = submission.category == SubmissionCategory.feedback;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: categoryColor(submission.theme ?? 'more'),
                    child: Icon(
                      kThemeIcons[submission.theme] ?? Icons.help_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _copyReceipt(context, submission.tokenId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.receiptLabel(submission.tokenId),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 13, color: AppColors.inkFaint),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSuggestion ? AppColors.indigoMist : AppColors.vermilionMist,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSuggestion ? l10n.badgeSuggestion : l10n.badgeReport,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSuggestion ? AppColors.indigoDeep : AppColors.vermilionDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                submission.rawText ?? submission.transcript ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              if (isSuggestion)
                _SuggestionOutcome(submission: submission)
              else
                StatusStepper(status: submission.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionOutcome extends StatelessWidget {
  const _SuggestionOutcome({required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolved = submission.status == SubmissionStatus.resolved;
    return Row(
      children: [
        const Icon(Icons.groups_rounded, size: 16, color: AppColors.inkFaint),
        const SizedBox(width: 6),
        Text(
          l10n.supportersCount(submission.supporterCount),
          style: const TextStyle(color: AppColors.inkFaint, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (resolved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tealMist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.inDevelopmentPlan,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.tealDeep),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.saffronMist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.underReview,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.saffronDeep),
            ),
          ),
      ],
    );
  }
}
