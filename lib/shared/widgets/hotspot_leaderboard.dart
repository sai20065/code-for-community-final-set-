import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/public_data_providers.dart';
import '../../app/theme.dart';
import '../../core/models/public_models.dart';
import '../../l10n/app_localizations.dart';
import 'theme_icon_chip.dart';
import 'weekly_sparkline.dart';

/// The constituency's worst tracked issues, ranked.
///
/// Reads `publicClusters`, so it renders the same for a signed-out visitor
/// as for an official.
class HotspotLeaderboard extends ConsumerWidget {
  const HotspotLeaderboard({
    super.key,
    required this.constituencyId,
    this.limit = 5,
  });

  final String constituencyId;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clustersAsync = ref.watch(publicClustersProvider(constituencyId));

    return clustersAsync.when(
      data: (clusters) {
        if (clusters.isEmpty) {
          // Honest empty state. No zero-with-a-flame, no placeholder rows.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.noTrackedIssuesYet,
              style: const TextStyle(color: AppColors.inkFaint, fontSize: 12.5),
            ),
          );
        }
        final top = clusters.take(limit).toList();
        return Column(
          children: [
            for (var i = 0; i < top.length; i++)
              _HotspotRow(rank: i + 1, cluster: top[i]),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Text(l10n.couldNotLoadClusters),
    );
  }
}

class _HotspotRow extends StatelessWidget {
  const _HotspotRow({required this.rank, required this.cluster});

  final int rank;
  final PublicClusterModel cluster;

  Color _priorityColor(double score) {
    if (score >= 70) return AppColors.vermilion;
    if (score >= 40) return AppColors.saffron;
    return AppColors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeColor = categoryColor(cluster.theme);
    final priorityColor = _priorityColor(cluster.priorityScore);
    final series = cluster.recentWeeklySeries;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/public/cluster/${cluster.id}'),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: priorityColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(kThemeIcons[cluster.theme],
                            size: 14, color: themeColor),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            cluster.title ??
                                (cluster.summaryText.isEmpty
                                    ? kThemeLabels[cluster.theme] ?? cluster.theme
                                    : cluster.summaryText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.forum_rounded,
                            size: 12, color: AppColors.inkFaint),
                        const SizedBox(width: 3),
                        Text(
                          l10n.reportsCountShort(cluster.submissionCount),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.inkFaint),
                        ),
                        const SizedBox(width: 10),
                        if (cluster.hasSolutionCard) ...[
                          Icon(Icons.auto_awesome_rounded,
                              size: 12, color: AppColors.indigo),
                          const SizedBox(width: 3),
                          Text(
                            l10n.hasSolutionLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.indigo,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (series.length >= 2) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 58,
                  child: WeeklySparkline(
                      values: series, color: priorityColor, height: 34),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "N reports near you this week."
///
/// Renders an invitation rather than a zero when nothing has been reported —
/// "0 reports this week" next to a live pulse dot reads as a broken feed,
/// and inflating the number to look busier would be worse still.
class NearYouBanner extends ConsumerWidget {
  const NearYouBanner({super.key, required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final countAsync = ref.watch(reportsThisWeekProvider(constituencyId));

    return countAsync.when(
      data: (count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.indigo.withValues(alpha: 0.10),
              AppColors.saffron.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            const _LiveDot(),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                count == 0
                    ? l10n.beTheFirstThisWeek
                    : l10n.reportsNearYouThisWeek(count),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 44),
      // A failed count is not worth an error message on a dashboard — just
      // omit the banner.
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
              color: AppColors.teal, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          l10n.liveLabel.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.teal,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
