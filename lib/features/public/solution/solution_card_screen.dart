import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/solution_card_model.dart';
import '../../../core/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/sdg_badge.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// The Solution Card — the end product of the four-agent civic intelligence
/// chain (`functions/src/agents/`).
///
/// One document, two audiences, behind a segmented toggle: a resident wants
/// to know what's wrong and what's being asked for, in plain language; an
/// officer wants the cited evidence, the cost band and the routing. Showing
/// both at once serves neither.
class SolutionCardScreen extends ConsumerStatefulWidget {
  const SolutionCardScreen({super.key, required this.clusterId});

  final String clusterId;

  @override
  ConsumerState<SolutionCardScreen> createState() => _SolutionCardScreenState();
}

class _SolutionCardScreenState extends ConsumerState<SolutionCardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cardAsync = ref.watch(solutionCardProvider(widget.clusterId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/public/dashboard'),
        ),
        title: Text(l10n.solutionCardTitle),
      ),
      body: cardAsync.when(
        data: (card) {
          if (card == null) return _AnalysisPending(l10n: l10n);
          return _CardBody(
            card: card,
            tab: _tab,
            onTabChanged: (t) => setState(() => _tab = t),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
      ),
    );
  }
}

/// Shown when the agent chain hasn't run for this issue yet. Honest about
/// *why* there's nothing here — an issue only earns an analysis once enough
/// people have reported it — rather than an empty screen.
class _AnalysisPending extends StatelessWidget {
  const _AnalysisPending({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty_rounded,
                size: 40, color: AppColors.inkFaint),
            const SizedBox(height: 12),
            Text(l10n.analysisPending,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({
    required this.card,
    required this.tab,
    required this.onTabChanged,
  });

  final SolutionCardModel card;
  final int tab;
  final ValueChanged<int> onTabChanged;

  /// Plain-text export for sharing. Clipboard rather than a share sheet:
  /// `share_plus` isn't a dependency and a copy + SnackBar works on every
  /// platform including web.
  String _shareText(AppLocalizations l10n) {
    final buffer = StringBuffer()
      ..writeln(card.headline)
      ..writeln(card.constituencyName)
      ..writeln()
      // Citizen-facing text only — no token ids, which are noise outside the
      // department brief.
      ..writeln(card.citizenSummary)
      ..writeln();
    if (card.costBandLabel.isNotEmpty) {
      buffer.writeln('${l10n.estimatedCost}: ${card.costBandLabel}');
    }
    buffer.writeln('${l10n.routedToDepartment}: ${card.routing.primary.name}');
    buffer.writeln(
        '${card.submissionCount} reports · ${card.uniqueReporterCount} residents');
    if (card.sdgGoals.isNotEmpty) {
      buffer.writeln('${l10n.sdgAlignment}: SDG ${card.sdgGoals.join(", ")}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final isOfficial = profile?.role == UserRole.official;
    final color = categoryColor(card.theme);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(kThemeIcons[card.theme], size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              (kThemeLabels[card.theme] ?? card.theme).toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text('v${card.version}',
                style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.inkFaint)),
          ],
        ),
        const SizedBox(height: 8),
        Text(card.headline,
            style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 6),
        Text(
          '${card.constituencyName} · ${l10n.reportsFromResidents(card.submissionCount, card.uniqueReporterCount)}',
          style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
        ),

        // A card built partly from fallbacks must not read with the same
        // authority as one where every agent succeeded. Say so, up top.
        if (card.degraded) ...[
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.info_outline_rounded,
            color: AppColors.saffronDeep,
            background: AppColors.saffronMist,
            text: l10n.analysisDegradedNote,
          ),
        ],

        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.forCitizens)),
            ButtonSegment(value: 1, label: Text(l10n.forDepartment)),
          ],
          selected: {tab},
          onSelectionChanged: (s) => onTabChanged(s.first),
        ),
        const SizedBox(height: 16),

        if (tab == 0) ..._citizenView(context, l10n) else ..._departmentView(context, l10n),

        const SizedBox(height: 20),
        _RoutingCard(routing: card.routing, l10n: l10n),

        if (card.sdg.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.sdgAlignment,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final mapping in card.sdg)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SdgBadge(
                    goal: mapping.goal,
                    label: mapping.targets.isEmpty
                        ? mapping.goalName
                        : '${mapping.goalName} · ${mapping.targets.join(", ")}',
                  ),
                  if (mapping.rationale.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 38, top: 3),
                      child: Text(mapping.rationale,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkFaint,
                              height: 1.4)),
                    ),
                ],
              ),
            ),
        ],

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: _shareText(l10n)));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.copiedToClipboard)),
                  );
                },
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(l10n.shareSolution),
              ),
            ),
            if (isOfficial) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/official/transcript/${card.clusterId}'),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: Text(l10n.viewAgentTranscript),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),
        // Non-negotiable given this page carries rupee figures and causal
        // claims produced by a language model.
        _Notice(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.inkSoft,
          background: AppColors.indigoMist,
          text: l10n.aiGeneratedDisclaimer,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _citizenView(BuildContext context, AppLocalizations l10n) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: appCardShadow,
        ),
        child: Text(card.citizenSummary,
            style: const TextStyle(fontSize: 15, height: 1.55)),
      ),
      if (card.rootCause.summary.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Section(title: l10n.whyItRecurs, child: Text(card.rootCause.summary,
            style: const TextStyle(fontSize: 13.5, height: 1.5))),
      ],
      if (card.interventions.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(l10n.whatWeAreAskingFor,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final intervention in card.interventions)
          _InterventionTile(intervention: intervention, l10n: l10n),
      ],
      if (card.quickWin != null) ...[
        const SizedBox(height: 12),
        _Notice(
          icon: Icons.bolt_rounded,
          color: AppColors.teal,
          background: AppColors.tealMist,
          text: '${l10n.quickWin}: ${card.quickWin}',
        ),
      ],
    ];
  }

  List<Widget> _departmentView(BuildContext context, AppLocalizations l10n) {
    return [
      if (card.problemStatement.isNotEmpty)
        _Section(
          title: l10n.problemStatement,
          child: Text(card.problemStatement,
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ),
      if (card.rootCauseText.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Section(
          title: l10n.whyItRecurs,
          child: Text(card.rootCauseText,
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ),
      ],
      if (card.recommendedActions.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Section(
          title: l10n.recommendedActions,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < card.recommendedActions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}.  ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.indigo)),
                      Expanded(
                        child: Text(card.recommendedActions[i],
                            style: const TextStyle(fontSize: 13, height: 1.45)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      if (card.evidence.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Section(
          title: l10n.evidenceFrom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in card.evidence)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('•  $line',
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.45, color: AppColors.inkSoft)),
                ),
            ],
          ),
        ),
      ],
      if (card.interventions.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(l10n.proposedInterventions,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final intervention in card.interventions)
          _InterventionTile(
              intervention: intervention, l10n: l10n, detailed: true),
      ],
      if (card.expectedImpact.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Section(
          title: l10n.expectedImpact,
          child: Text(card.expectedImpact,
              style: const TextStyle(fontSize: 13, height: 1.45)),
        ),
      ],
      if (card.rootCause.dataGaps.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Section(
          title: l10n.dataGaps,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final gap in card.rootCause.dataGaps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('•  $gap',
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.inkFaint)),
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.inkFaint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _InterventionTile extends StatelessWidget {
  const _InterventionTile({
    required this.intervention,
    required this.l10n,
    this.detailed = false,
  });

  final Intervention intervention;
  final AppLocalizations l10n;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(intervention.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, height: 1.3)),
          const SizedBox(height: 6),
          Text(intervention.description,
              style: const TextStyle(fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (intervention.costBand.isEstimated)
                _Chip(
                  icon: Icons.currency_rupee_rounded,
                  label: intervention.costBand.label,
                  color: AppColors.saffronDeep,
                )
              else
                _Chip(
                  icon: Icons.help_outline_rounded,
                  label: l10n.costNotEstimated,
                  color: AppColors.inkFaint,
                ),
              if (intervention.timelineMaxWeeks > 0)
                _Chip(
                  icon: Icons.schedule_rounded,
                  label: l10n.weeksRange(
                      intervention.timelineMinWeeks, intervention.timelineMaxWeeks),
                  color: AppColors.indigo,
                ),
              // "Not estimated" rather than a fabricated number: the
              // Solution agent returns null when the affected population is
              // genuinely unknown, and showing a zero would read as a real
              // finding of zero.
              _Chip(
                icon: Icons.home_outlined,
                label: intervention.householdsAddressed == null
                    ? l10n.householdsNotEstimated
                    : l10n.householdsAddressed(intervention.householdsAddressed!),
                color: intervention.householdsAddressed == null
                    ? AppColors.inkFaint
                    : AppColors.teal,
              ),
            ],
          ),
          if (detailed && intervention.prerequisites.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.prerequisites.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkFaint,
                    letterSpacing: 0.4)),
            const SizedBox(height: 3),
            for (final p in intervention.prerequisites)
              Text('•  $p',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft, height: 1.4)),
          ],
          if (detailed && intervention.impactRationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(intervention.impactRationale,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkFaint,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _RoutingCard extends StatelessWidget {
  const _RoutingCard({required this.routing, required this.l10n});

  final RoutingInfo routing;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.indigoMist,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  size: 16, color: AppColors.indigoDeep),
              const SizedBox(width: 6),
              Text(l10n.routedToDepartment,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigoDeep,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 8),
          Text(routing.primary.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, height: 1.3)),
          if (routing.jurisdictionRationale.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(routing.jurisdictionRationale,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.inkSoft, height: 1.4)),
          ],
          if (routing.primary.grievancePortalUrl != null) ...[
            const SizedBox(height: 6),
            SelectableText(
              routing.primary.grievancePortalUrl!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.indigo),
            ),
          ],
          // A national fallback portal is a materially weaker answer than
          // naming the actual local body. Say which one this is rather than
          // letting both look equally authoritative.
          if (!routing.isPreciseMatch) ...[
            const SizedBox(height: 6),
            Text(l10n.routingApproximate,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.inkFaint, height: 1.4)),
          ],
          if (routing.escalation != null) ...[
            const Divider(height: 18),
            Text('${l10n.escalatesTo}: ${routing.escalation!.name}',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
          if (routing.mpName != null) ...[
            const SizedBox(height: 6),
            Text('${l10n.yourMp}: ${routing.mpName}',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 11.5, color: color, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
