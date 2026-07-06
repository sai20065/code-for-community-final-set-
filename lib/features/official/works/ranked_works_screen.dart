import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/cluster_model.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Ranked development-works panel: each recurring theme (`ClusterModel`)
/// doubles as a candidate development work, ranked by composite
/// `priorityScore`, shown as a numbered badge + segmented score bar
/// breaking that composite into citizen demand / demographic weight /
/// infrastructure-gap weight — the "weigh competing proposals against real
/// demand" capability made visible rather than a single opaque number.
class RankedWorksScreen extends ConsumerWidget {
  const RankedWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ranked Development Works')),
      body: profileAsync.when(
        data: (profile) {
          final constituencyId = profile?.constituencyId;
          if (constituencyId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Your account isn\'t linked to a constituency yet.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return _RankedList(constituencyId: constituencyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your profile.')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/official/compare'),
        icon: const Icon(Icons.compare_arrows_rounded),
        label: const Text('Compare'),
      ),
    );
  }
}

class _RankedList extends ConsumerWidget {
  const _RankedList({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clustersAsync = ref.watch(_clustersProvider(constituencyId));
    return clustersAsync.when(
      data: (clusters) {
        if (clusters.isEmpty) {
          return const Center(child: Text('No ranked works yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clusters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _WorkCard(rank: index + 1, cluster: clusters[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Could not load ranked works.')),
    );
  }
}

final _clustersProvider =
    StreamProvider.family<List<ClusterModel>, String>((ref, constituencyId) {
  return ref.watch(firestoreServiceProvider).watchClustersForConstituency(constituencyId);
});

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.rank, required this.cluster});

  final int rank;
  final ClusterModel cluster;

  @override
  Widget build(BuildContext context) {
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
                  cluster.title ?? '${kThemeLabels[cluster.theme] ?? cluster.theme} — recurring demand',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              if (cluster.priorityScore != null)
                Text(cluster.priorityScore!.toStringAsFixed(0),
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(cluster.summaryText, style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          const SizedBox(height: 10),
          if (total > 0) _ScoreBar(cluster: cluster, total: total),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.groups_rounded, size: 14, color: AppColors.inkFaint),
              const SizedBox(width: 4),
              Text('${cluster.submissionCount} tickets', style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
              if (cluster.affectedBoothRange != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.place_rounded, size: 14, color: AppColors.inkFaint),
                const SizedBox(width: 4),
                Text(cluster.affectedBoothRange!, style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Segmented score bar: proportioned color segments for demand /
/// demographic / infra-gap weight, so the composite rank number is never a
/// black box.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.cluster, required this.total});

  final ClusterModel cluster;
  final double total;

  @override
  Widget build(BuildContext context) {
    final demand = (cluster.demandScore ?? 0) / total;
    final demo = (cluster.demographicScore ?? 0) / total;
    final infra = (cluster.infraGapScore ?? 0) / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
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
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _LegendDot(color: AppColors.indigo, label: 'Demand'),
            const SizedBox(width: 10),
            _LegendDot(color: AppColors.saffron, label: 'Demographic'),
            const SizedBox(width: 10),
            _LegendDot(color: AppColors.teal, label: 'Infra gap'),
          ],
        ),
      ],
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
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.inkFaint)),
      ],
    );
  }
}
