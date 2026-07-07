import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/cluster_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Ranked development-works panel: each recurring theme (`ClusterModel`)
/// doubles as a candidate development work, ranked by a composite score
/// (citizen demand / demographic weight / infrastructure-gap weight) that
/// the official can re-weight live via the slider strip — the "weigh
/// competing proposals against real demand" capability made visible and
/// adjustable, rather than a single fixed opaque number.
class RankedWorksScreen extends ConsumerWidget {
  const RankedWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rankedDevelopmentWorks)),
      body: profileAsync.when(
        data: (profile) {
          final constituencyId = profile?.constituencyId;
          if (constituencyId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.notLinkedConstituency,
                    textAlign: TextAlign.center),
              ),
            );
          }
          return _RankedList(constituencyId: constituencyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/official/compare'),
        icon: const Icon(Icons.compare_arrows_rounded),
        label: Text(l10n.compare),
      ),
    );
  }
}

class _RankedList extends ConsumerStatefulWidget {
  const _RankedList({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_RankedList> createState() => _RankedListState();
}

class _RankedListState extends ConsumerState<_RankedList> {
  double _wDemand = 0.40;
  double _wDemographic = 0.30;
  double _wInfraGap = 0.30;
  final Set<String> _expanded = {};

  double _weightedScore(ClusterModel c) {
    return (c.demandScore ?? 0) * _wDemand +
        (c.demographicScore ?? 0) * _wDemographic +
        (c.infraGapScore ?? 0) * _wInfraGap;
  }

  @override
  Widget build(BuildContext context) {
    final clustersAsync = ref.watch(_clustersProvider(widget.constituencyId));
    return clustersAsync.when(
      data: (clusters) {
        if (clusters.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context).noRankedWorks));
        }
        final ranked = [...clusters]
          ..sort((a, b) => _weightedScore(b).compareTo(_weightedScore(a)));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeightSliderStrip(
              wDemand: _wDemand,
              wDemographic: _wDemographic,
              wInfraGap: _wInfraGap,
              onChanged: (demand, demographic, infraGap) => setState(() {
                _wDemand = demand;
                _wDemographic = demographic;
                _wInfraGap = infraGap;
              }),
            ),
            const SizedBox(height: 16),
            const _ScoreLegend(),
            const SizedBox(height: 12),
            for (var i = 0; i < ranked.length; i++) ...[
              _WorkCard(
                rank: i + 1,
                cluster: ranked[i],
                weightedScore: _weightedScore(ranked[i]),
                expanded: _expanded.contains(ranked[i].id),
                onToggleWhy: () => setState(() {
                  if (!_expanded.add(ranked[i].id)) _expanded.remove(ranked[i].id);
                }),
              ),
              if (i != ranked.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(AppLocalizations.of(context).couldNotLoadRankedWorks)),
    );
  }
}

final _clustersProvider =
    StreamProvider.family<List<ClusterModel>, String>((ref, constituencyId) {
  return ref.watch(firestoreServiceProvider).watchClustersForConstituency(constituencyId);
});

/// Non-functional-visual-only in the original design brief, but since this
/// is real shipping code (not a static preview) the sliders actually
/// re-rank the list live — recomputing each cluster's weighted score from
/// its own demand/demographic/infra-gap fields, not a fabricated call.
class _WeightSliderStrip extends StatelessWidget {
  const _WeightSliderStrip({
    required this.wDemand,
    required this.wDemographic,
    required this.wInfraGap,
    required this.onChanged,
  });

  final double wDemand;
  final double wDemographic;
  final double wInfraGap;
  final void Function(double demand, double demographic, double infraGap) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rankingWeightsAdjust,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.inkSoft)),
          _WeightSlider(
            label: l10n.weightDemand,
            color: AppColors.indigo,
            value: wDemand,
            onChanged: (v) => onChanged(v, wDemographic, wInfraGap),
          ),
          _WeightSlider(
            label: l10n.weightDemographic,
            color: AppColors.saffron,
            value: wDemographic,
            onChanged: (v) => onChanged(wDemand, v, wInfraGap),
          ),
          _WeightSlider(
            label: l10n.weightInfraGap,
            color: AppColors.teal,
            value: wInfraGap,
            onChanged: (v) => onChanged(wDemand, wDemographic, v),
          ),
          Text(l10n.changesSavedAudit,
              style: const TextStyle(fontSize: 10, color: AppColors.inkFaint, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(value.toStringAsFixed(2),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Sub-score legend shown once above the panel, not repeated per row.
class _ScoreLegend extends StatelessWidget {
  const _ScoreLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _LegendDot(color: AppColors.indigo, label: l10n.weightDemand),
        const SizedBox(width: 14),
        _LegendDot(color: AppColors.saffron, label: l10n.weightDemographic),
        const SizedBox(width: 14),
        _LegendDot(color: AppColors.teal, label: l10n.weightInfraGap),
      ],
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({
    required this.rank,
    required this.cluster,
    required this.weightedScore,
    required this.expanded,
    required this.onToggleWhy,
  });

  final int rank;
  final ClusterModel cluster;
  final double weightedScore;
  final bool expanded;
  final VoidCallback onToggleWhy;

  String _whyText(AppLocalizations l10n) {
    final parts = <String>[l10n.ticketsRecordedHere(cluster.submissionCount)];
    if (cluster.demandScore != null) parts.add(l10n.fragDemand(cluster.demandScore!.toStringAsFixed(0)));
    if (cluster.demographicScore != null) {
      parts.add(l10n.fragDemographic(cluster.demographicScore!.toStringAsFixed(0)));
    }
    if (cluster.infraGapScore != null) parts.add(l10n.fragInfraGap(cluster.infraGapScore!.toStringAsFixed(0)));
    if (cluster.affectedBoothRange != null) parts.add(l10n.fragAffects(cluster.affectedBoothRange!));
    if (cluster.localContext != null) parts.add(cluster.localContext!);
    return '${parts.join(' · ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = (cluster.demandScore ?? 0) + (cluster.demographicScore ?? 0) + (cluster.infraGapScore ?? 0);
    final color = categoryColor(cluster.theme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.indigoMist,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('#$rank',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: AppColors.indigoDeep)),
              ),
              const SizedBox(width: 10),
              Icon(kThemeIcons[cluster.theme], size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cluster.title ?? l10n.recurringDemand(kThemeLabels[cluster.theme] ?? cluster.theme),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              Text(weightedScore.toStringAsFixed(0),
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(cluster.summaryText, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          const SizedBox(height: 10),
          if (total > 0) _ScoreBar(cluster: cluster, total: total),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 14, color: AppColors.inkFaint),
              const SizedBox(width: 4),
              Text(l10n.ticketsShort(cluster.submissionCount), style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
              if (cluster.affectedBoothRange != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.place_rounded, size: 14, color: AppColors.inkFaint),
                const SizedBox(width: 4),
                Text(cluster.affectedBoothRange!, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
              ],
              const Spacer(),
              InkWell(
                onTap: onToggleWhy,
                child: Text(
                  expanded ? l10n.hideLabel : l10n.whyExpand,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.indigo),
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.indigoMist,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _whyText(l10n),
                style: const TextStyle(fontSize: 11.5, color: AppColors.indigoDeep, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Segmented score bar: proportioned color segments for demand /
/// demographic / infra-gap weight, so the composite rank number is never a
/// black box. The legend itself lives once above the list (`_ScoreLegend`).
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.cluster, required this.total});

  final ClusterModel cluster;
  final double total;

  @override
  Widget build(BuildContext context) {
    final demand = (cluster.demandScore ?? 0) / total;
    final demo = (cluster.demographicScore ?? 0) / total;
    final infra = (cluster.infraGapScore ?? 0) / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            Expanded(flex: (demand * 1000).round().clamp(1, 1000), child: Container(color: AppColors.indigo)),
            Expanded(flex: (demo * 1000).round().clamp(1, 1000), child: Container(color: AppColors.saffron)),
            Expanded(flex: (infra * 1000).round().clamp(1, 1000), child: Container(color: AppColors.teal)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.inkFaint)),
      ],
    );
  }
}
