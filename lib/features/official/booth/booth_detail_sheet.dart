import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/booth_model.dart';
import '../../../core/models/cluster_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Detail panel for a tapped booth, led by an AI Hotspot Card built from the
/// booth's top-priority cluster (if any) — real fields only: the "Why it
/// recurs" side cites the cluster's own ticket count/summary (from the
/// Gemini pipeline in `functions/src/submissions/onSubmissionCreated.ts`),
/// and "Why it's happening here" cites `booth.localContext`, an actual
/// seeded/derived field — never a fabricated citation the backend doesn't
/// actually have. Other clusters at this booth are listed below, with raw
/// sample ticket ids expandable underneath.
class BoothDetailSheet extends ConsumerWidget {
  const BoothDetailSheet({super.key, required this.booth});

  final BoothModel booth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clustersAsync = ref.watch(_boothClustersProvider(booth.id));
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(booth.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.wardConstituency(booth.constituencyId),
                style: const TextStyle(color: AppColors.inkFaint, fontSize: 12)),
            const SizedBox(height: 12),
            clustersAsync.when(
              data: (clusters) {
                if (clusters.isEmpty) {
                  return _StatRowOnly(booth: booth);
                }
                final top = clusters.first;
                return _HotspotCard(booth: booth, topCluster: top);
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _StatRowOnly(booth: booth),
            ),
            const SizedBox(height: 20),
            Text(l10n.otherRecurringThemes, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            clustersAsync.when(
              data: (clusters) {
                final rest = clusters.length > 1 ? clusters.sublist(1) : const <ClusterModel>[];
                if (rest.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.noOtherThemes,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(children: rest.map((c) => _ClusterTile(cluster: c)).toList());
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => Text(l10n.couldNotLoadClusters),
            ),
            const SizedBox(height: 16),
            clustersAsync.maybeWhen(
              data: (clusters) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.sampleTickets),
                children: [
                  for (final c in clusters)
                    for (final id in c.sampleSubmissionIds)
                      ListTile(title: Text('$id — ${c.theme}')),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

/// Fallback header (submission count + dominant theme + local context) shown
/// when this booth has no clusters yet to build a full hotspot card from.
class _StatRowOnly extends StatelessWidget {
  const _StatRowOnly({required this.booth});

  final BoothModel booth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatPill(icon: Icons.forum_rounded, label: l10n.submissionsCount(booth.submissionVolume)),
            const SizedBox(width: 8),
            if (booth.dominantTheme != null)
              _StatPill(
                icon: kThemeIcons[booth.dominantTheme] ?? Icons.help_outline_rounded,
                label: kThemeLabels[booth.dominantTheme] ?? booth.dominantTheme!,
                color: categoryColor(booth.dominantTheme!),
              ),
          ],
        ),
        if (booth.localContext != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.indigoMist,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.indigoDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(booth.localContext!,
                      style: const TextStyle(fontSize: 12, color: AppColors.indigoDeep)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The AI Hotspot Card: header (booth + hotspot score pill + open count),
/// "Why it recurs" (citizen-side pattern, from the cluster) / "Why it's
/// happening here" (local context, from the booth) sections, and a footer
/// linking to the ranked-works list — clusters already double as ranked-work
/// candidates there (see `RankedWorksScreen`), so "promoting" one just means
/// jumping to where it's already ranked, not a separate fabricated action.
class _HotspotCard extends StatelessWidget {
  const _HotspotCard({required this.booth, required this.topCluster});

  final BoothModel booth;
  final ClusterModel topCluster;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hotspotScore = ((topCluster.priorityScore ?? 50) / 100).clamp(0.0, 1.0);
    final color = categoryColor(topCluster.theme);
    final themeLabel = kThemeLabels[topCluster.theme] ?? topCluster.theme;
    final recurSummary = topCluster.summaryText.isEmpty
        ? l10n.themeIssuesReportedHere(themeLabel)
        : topCluster.summaryText;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.vermilionMist,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.vermilion, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${booth.name} · $themeLabel',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.vermilion,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hotspotScore.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatPill(icon: Icons.forum_rounded, label: l10n.openCount(booth.openIssueCount)),
            ],
          ),
          const SizedBox(height: 14),
          Text(l10n.whyItRecurs,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.saffronDeep, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(
            l10n.whyRecursBody(topCluster.submissionCount, booth.name, recurSummary),
            style: const TextStyle(fontSize: 12.5, height: 1.4, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Text(l10n.whyHappeningHere,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.tealDeep, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(
            booth.localContext ?? l10n.noLocalContext,
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(kThemeIcons[topCluster.theme], size: 13, color: color),
                    const SizedBox(width: 5),
                    Text(
                      l10n.suggestedWork(topCluster.title ?? themeLabel),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/official/works');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(l10n.seeInRankedWorks),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              l10n.aiGeneratedSummary,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

final _boothClustersProvider =
    StreamProvider.family<List<ClusterModel>, String>((ref, boothId) {
  return ref.watch(firestoreServiceProvider).watchClustersForBooth(boothId);
});

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}

class _ClusterTile extends StatelessWidget {
  const _ClusterTile({required this.cluster});

  final ClusterModel cluster;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(cluster.summaryText.isEmpty
            ? l10n.ticketsInBooth(kThemeLabels[cluster.theme] ?? cluster.theme)
            : cluster.summaryText),
        subtitle: cluster.priorityScore != null
            ? Text(l10n.priorityValue(cluster.priorityScore!.toStringAsFixed(1)))
            : null,
        trailing: CircleAvatar(
          radius: 14,
          child: Text('${cluster.submissionCount}',
              style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
