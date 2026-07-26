import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/animated_stat_tile.dart';
import '../../../shared/widgets/hotspot_leaderboard.dart';
import '../../../shared/widgets/solution_card_tile.dart';

/// The public civic dashboard — readable by anyone, signed in or not.
///
/// This screen used to be `/official/dashboard`, gated behind an official
/// login, even though nothing rendered here needs an account: every number
/// and marker comes from `publicClusters`/`publicTickets`
/// (`PublicDataService`), which expose only anonymous `tokenId`s and
/// AI-written summaries — never a name, an address, or an exact location.
/// Officials keep exactly two extra abilities beyond what anyone sees here:
/// updating ticket status and generating the full AI briefing PDF, both
/// gated by role in the "Official actions" card below, not by hiding the
/// dashboard itself.
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final constituencyId = ref.watch(effectivePublicConstituencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.publicDashboardTitle),
        bottom: const TricolorTrustStrip(),
      ),
      body: SafeArea(
        child: constituencyId == null
            ? _NoConstituencyChosen(l10n: l10n)
            : _DashboardBody(constituencyId: constituencyId),
      ),
    );
  }
}

class _NoConstituencyChosen extends StatelessWidget {
  const _NoConstituencyChosen({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_searching_rounded,
                size: 40, color: AppColors.inkFaint),
            const SizedBox(height: 12),
            Text(l10n.chooseConstituency, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/public/constituency'),
              child: Text(l10n.chooseConstituency),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(publicConstituencyStatsProvider(constituencyId));
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final isOfficial =
        profile?.role == UserRole.official && profile?.constituencyId == constituencyId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Every dashboard build states this up front, not buried in a
        // settings page — the trust argument for a public civic tool has to
        // be visible at the point someone is deciding whether to use it.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.tealMist,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.publicPrivacyNote,
                    style: const TextStyle(fontSize: 11.5, height: 1.4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NearYouBanner(constituencyId: constituencyId),
        const SizedBox(height: 16),
        statsAsync.when(
          data: (stats) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedStatTile(
                      label: l10n.trackedIssues,
                      value: stats.trackedIssues,
                      color: AppColors.indigo,
                      icon: Icons.rule_folder_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedStatTile(
                      label: l10n.resolvedRate,
                      value: stats.totalReports == 0
                          ? 0
                          : ((stats.resolvedReports / stats.totalReports) * 100).round(),
                      suffix: '%',
                      color: AppColors.teal,
                      icon: Icons.task_alt_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedStatTile(
                label: l10n.totalReports,
                value: stats.totalReports,
                color: AppColors.saffronDeep,
                icon: Icons.forum_outlined,
                fullWidth: true,
              ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Text(l10n.somethingWentWrong),
        ),
        const SizedBox(height: 24),
        Text(l10n.topHotspots, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        HotspotLeaderboard(constituencyId: constituencyId),
        const SizedBox(height: 8),
        Consumer(
          builder: (context, ref, _) {
            final cardsAsync =
                ref.watch(publicSolutionCardsProvider(constituencyId));
            return cardsAsync.maybeWhen(
              data: (cards) {
                if (cards.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(l10n.latestSolutions,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 172,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: cards.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) =>
                            SolutionCardTile(card: cards[i]),
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(l10n.constituencyMap, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: Material(
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/public/map'),
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_rounded, size: 44, color: AppColors.indigo),
                    const SizedBox(height: 8),
                    Text(l10n.openConstituencyMap),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/public/works'),
              icon: const Icon(Icons.leaderboard_rounded),
              label: Text(l10n.rankedWorks),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/public/themes'),
              icon: const Icon(Icons.bar_chart_rounded),
              label: Text(l10n.themesOverview),
            ),
          ],
        ),
        if (isOfficial) ...[
          const SizedBox(height: 24),
          Text(l10n.officialActions, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.officialActionsHint,
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/official/tickets'),
                icon: const Icon(Icons.list_alt_rounded),
                label: Text(l10n.updateTicketStatuses),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/official/report'),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(l10n.generateReport),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
