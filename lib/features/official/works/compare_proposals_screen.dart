import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/cluster_model.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// "Weigh competing proposals against real demand" — pick any two ranked
/// works and compare their underlying stats side by side, with an AI-style
/// recommendation line that cites the specific numbers rather than a bare
/// "we recommend X." The recommendation is generated client-side from the
/// same demand/demographic/infra-gap fields shown in the ranked list — no
/// separate black-box call.
class CompareProposalsScreen extends ConsumerStatefulWidget {
  const CompareProposalsScreen({super.key});

  @override
  ConsumerState<CompareProposalsScreen> createState() => _CompareProposalsScreenState();
}

class _CompareProposalsScreenState extends ConsumerState<CompareProposalsScreen> {
  String? _leftId;
  String? _rightId;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Proposals')),
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
          final clustersAsync = ref.watch(_clustersProvider(constituencyId));
          return clustersAsync.when(
            data: (clusters) {
              if (clusters.length < 2) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Need at least two ranked works to compare.',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              final left = clusters.firstWhere((c) => c.id == _leftId, orElse: () => clusters[0]);
              final right = clusters.firstWhere((c) => c.id == _rightId, orElse: () => clusters[1]);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _ProposalPicker(
                          label: 'Proposal A',
                          clusters: clusters,
                          selectedId: left.id,
                          onChanged: (id) => setState(() => _leftId = id),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _ProposalPicker(
                          label: 'Proposal B',
                          clusters: clusters,
                          selectedId: right.id,
                          onChanged: (id) => setState(() => _rightId = id),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _ProposalCard(cluster: left)),
                                const SizedBox(width: 12),
                                Expanded(child: _ProposalCard(cluster: right)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _TradeOffBrief(left: left, right: right),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Could not load proposals.')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your profile.')),
      ),
    );
  }
}

final _clustersProvider =
    StreamProvider.family<List<ClusterModel>, String>((ref, constituencyId) {
  return ref.watch(firestoreServiceProvider).watchClustersForConstituency(constituencyId);
});

class _ProposalPicker extends StatelessWidget {
  const _ProposalPicker({
    required this.label,
    required this.clusters,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final List<ClusterModel> clusters;
  final String selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: clusters
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(
                  c.title ?? '${kThemeLabels[c.theme] ?? c.theme} recurring demand',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.cluster});

  final ClusterModel cluster;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(cluster.theme);
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
          Row(
            children: [
              Icon(kThemeIcons[cluster.theme], size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cluster.title ?? kThemeLabels[cluster.theme] ?? cluster.theme,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatRow(label: 'Citizen demand', value: cluster.demandScore),
          _StatRow(label: 'Demographic weight', value: cluster.demographicScore),
          _StatRow(label: 'Infra-gap weight', value: cluster.infraGapScore),
          const Divider(height: 20),
          _StatRow(label: 'Tickets', value: cluster.submissionCount.toDouble(), isCount: true),
          if (cluster.affectedBoothRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(cluster.affectedBoothRange!,
                  style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
            ),
          if (cluster.localContext != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(cluster.localContext!,
                  style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.isCount = false});

  final String label;
  final double? value;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
          Text(
            value == null ? '—' : (isCount ? value!.toStringAsFixed(0) : value!.toStringAsFixed(0)),
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Structured AI trade-off brief, generated from the two clusters' own
/// numbers — three cited lines (who benefits / what the data says / what
/// each defers) plus a final recommendation, rather than one flat sentence.
/// Every number here comes straight from the cluster fields shown in the
/// cards above — no separate black-box call.
class _TradeOffBrief extends StatelessWidget {
  const _TradeOffBrief({required this.left, required this.right});

  final ClusterModel left;
  final ClusterModel right;

  double _total(ClusterModel c) =>
      c.priorityScore ?? ((c.demandScore ?? 0) + (c.demographicScore ?? 0) + (c.infraGapScore ?? 0));

  String _name(ClusterModel c) => c.title ?? kThemeLabels[c.theme] ?? c.theme;

  @override
  Widget build(BuildContext context) {
    final winner = _total(left) >= _total(right) ? left : right;
    final loser = _total(left) >= _total(right) ? right : left;
    final winnerName = _name(winner);
    final loserName = _name(loser);

    final reasons = <String>[];
    if ((winner.demandScore ?? 0) > (loser.demandScore ?? 0)) {
      reasons.add('${winner.submissionCount} citizen tickets vs. ${loser.submissionCount}');
    }
    if ((winner.demographicScore ?? 0) > (loser.demographicScore ?? 0)) {
      reasons.add('a higher demographic-reach weight (${winner.demographicScore?.toStringAsFixed(0) ?? "—"} vs. ${loser.demographicScore?.toStringAsFixed(0) ?? "—"})');
    }
    if ((winner.infraGapScore ?? 0) > (loser.infraGapScore ?? 0)) {
      reasons.add('a larger existing infrastructure gap (${winner.infraGapScore?.toStringAsFixed(0) ?? "—"} vs. ${loser.infraGapScore?.toStringAsFixed(0) ?? "—"})');
    }
    final dataLine = reasons.isEmpty
        ? '$winnerName has a higher overall composite score than $loserName.'
        : '$winnerName leads $loserName on ${reasons.join(' and ')}.';

    final benefitsLine = winner.affectedBoothRange != null
        ? '$winnerName reaches ${winner.affectedBoothRange} (${winner.submissionCount} tickets recorded).'
        : '$winnerName has ${winner.submissionCount} citizen tickets behind it constituency-wide.';

    final defersLine = '${loser.submissionCount} tickets for $loserName'
        '${loser.affectedBoothRange != null ? " (${loser.affectedBoothRange})" : ""} '
        'wait for a later cycle if $winnerName is prioritised now.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.indigoMist,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.indigoDeep, size: 18),
              const SizedBox(width: 8),
              const Text('AI trade-off brief',
                  style: TextStyle(color: AppColors.indigoDeep, fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('grounded in evidence',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.indigoDeep)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BriefBullet(label: 'Who benefits', text: benefitsLine),
          const SizedBox(height: 8),
          _BriefBullet(label: 'What the data says', text: dataLine),
          const SizedBox(height: 8),
          _BriefBullet(label: 'What each defers', text: defersLine),
          const SizedBox(height: 12),
          Text(
            'Recommendation: prioritise $winnerName this cycle.',
            style: const TextStyle(color: AppColors.saffronDeep, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BriefBullet extends StatelessWidget {
  const _BriefBullet({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: AppColors.indigoDeep, fontWeight: FontWeight.w800)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.indigoDeep, fontSize: 12.5, height: 1.4),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
