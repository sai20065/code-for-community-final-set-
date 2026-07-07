import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/cluster_model.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/official/works'),
        ),
        title: Text(l10n.compareProposals),
      ),
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
          final clustersAsync = ref.watch(_clustersProvider(constituencyId));
          return clustersAsync.when(
            data: (clusters) {
              if (clusters.length < 2) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.needTwoToCompare,
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
                          label: l10n.proposalA,
                          clusters: clusters,
                          selectedId: left.id,
                          onChanged: (id) => setState(() => _leftId = id),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _ProposalPicker(
                          label: l10n.proposalB,
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
            error: (_, __) => Center(child: Text(l10n.couldNotLoadProposals)),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
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
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: clusters
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(
                  c.title ?? l10n.recurringDemandShort(kThemeLabels[c.theme] ?? c.theme),
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
    final l10n = AppLocalizations.of(context);
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
          _StatRow(label: l10n.statCitizenDemand, value: cluster.demandScore),
          _StatRow(label: l10n.statDemographicWeight, value: cluster.demographicScore),
          _StatRow(label: l10n.statInfraGapWeight, value: cluster.infraGapScore),
          const Divider(height: 20),
          _StatRow(label: l10n.statTickets, value: cluster.submissionCount.toDouble(), isCount: true),
          if (cluster.affectedBoothRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(cluster.affectedBoothRange!,
                  style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
            ),
          if (cluster.localContext != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(cluster.localContext!,
                  style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
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
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
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
    final l10n = AppLocalizations.of(context);
    final winner = _total(left) >= _total(right) ? left : right;
    final loser = _total(left) >= _total(right) ? right : left;
    final winnerName = _name(winner);
    final loserName = _name(loser);

    final reasons = <String>[];
    if ((winner.demandScore ?? 0) > (loser.demandScore ?? 0)) {
      reasons.add(l10n.reasonTickets(winner.submissionCount, loser.submissionCount));
    }
    if ((winner.demographicScore ?? 0) > (loser.demographicScore ?? 0)) {
      reasons.add(l10n.reasonDemographic(
          winner.demographicScore?.toStringAsFixed(0) ?? "—",
          loser.demographicScore?.toStringAsFixed(0) ?? "—"));
    }
    if ((winner.infraGapScore ?? 0) > (loser.infraGapScore ?? 0)) {
      reasons.add(l10n.reasonInfra(
          winner.infraGapScore?.toStringAsFixed(0) ?? "—",
          loser.infraGapScore?.toStringAsFixed(0) ?? "—"));
    }
    final dataLine = reasons.isEmpty
        ? l10n.dataHigherComposite(winnerName, loserName)
        : l10n.dataLeads(winnerName, loserName, reasons.join(' • '));

    final benefitsLine = winner.affectedBoothRange != null
        ? l10n.benefitsWithRange(winnerName, winner.affectedBoothRange!, winner.submissionCount)
        : l10n.benefitsNoRange(winnerName, winner.submissionCount);

    final defersLine = l10n.defersLine(
        loser.submissionCount,
        loserName,
        loser.affectedBoothRange != null ? " (${loser.affectedBoothRange})" : "",
        winnerName);

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
              Text(l10n.aiTradeOffBrief,
                  style: const TextStyle(color: AppColors.indigoDeep, fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(l10n.groundedInEvidence,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.indigoDeep)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BriefBullet(label: l10n.briefWhoBenefits, text: benefitsLine),
          const SizedBox(height: 8),
          _BriefBullet(label: l10n.briefWhatDataSays, text: dataLine),
          const SizedBox(height: 8),
          _BriefBullet(label: l10n.briefWhatDefers, text: defersLine),
          const SizedBox(height: 12),
          Text(
            l10n.recommendationLine(winnerName),
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
