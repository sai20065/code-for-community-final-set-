import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/agent_transcript_model.dart';
import '../../../l10n/app_localizations.dart';

/// The audit view for one run of the four-agent civic intelligence chain.
///
/// Officials only (enforced by the router redirect and by the Firestore
/// rules on `agentTranscripts`). This is what makes the Solution Card
/// accountable rather than oracular: every claim on that card can be traced
/// to the agent that made it, the prompt it was given, what it actually
/// replied, and whether it succeeded at all or quietly fell back.
class AgentTranscriptScreen extends ConsumerStatefulWidget {
  const AgentTranscriptScreen({super.key, required this.clusterId});

  final String clusterId;

  @override
  ConsumerState<AgentTranscriptScreen> createState() =>
      _AgentTranscriptScreenState();
}

class _AgentTranscriptScreenState extends ConsumerState<AgentTranscriptScreen> {
  late Future<AgentRunTranscript?> _future;

  @override
  void initState() {
    super.initState();
    _future =
        ref.read(publicDataServiceProvider).latestTranscript(widget.clusterId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/public/cluster/${widget.clusterId}'),
        ),
        title: Text(l10n.agentTranscriptTitle),
      ),
      body: FutureBuilder<AgentRunTranscript?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.somethingWentWrong, textAlign: TextAlign.center),
              ),
            );
          }
          final transcript = snapshot.data;
          if (transcript == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.analysisPending, textAlign: TextAlign.center),
              ),
            );
          }
          return _TranscriptBody(transcript: transcript);
        },
      ),
    );
  }
}

class _TranscriptBody extends StatelessWidget {
  const _TranscriptBody({required this.transcript});

  final AgentRunTranscript transcript;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.indigoMist,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.agentChainRun,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.indigoDeep)),
              const SizedBox(height: 6),
              _MetaRow(label: l10n.agentTrigger, value: transcript.trigger),
              _MetaRow(label: l10n.agentModel, value: transcript.modelId),
              _MetaRow(
                label: l10n.agentTotalTime,
                value: '${(transcript.totalLatencyMs / 1000).toStringAsFixed(1)}s',
              ),
              if (transcript.createdAt != null)
                _MetaRow(
                  label: l10n.agentRunAt,
                  value: transcript.createdAt!
                      .toIso8601String()
                      .replaceFirst('T', ' ')
                      .substring(0, 16),
                ),
            ],
          ),
        ),
        if (transcript.degraded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.saffronMist,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 15, color: AppColors.saffronDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.agentFellBackNote(transcript.failedAgents.join(', ')),
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.saffronDeep,
                        height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < transcript.turns.length; i++)
          _TurnCard(index: i + 1, turn: transcript.turns[i]),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.inkFaint)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: AppColors.indigoDeep)),
          ),
        ],
      ),
    );
  }
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({required this.index, required this.turn});

  final int index;
  final AgentTurn turn;

  static const _agentIcons = <String, IconData>{
    'rootCause': Icons.psychology_rounded,
    'solution': Icons.construction_rounded,
    'routing': Icons.alt_route_rounded,
    'reportCompiler': Icons.description_rounded,
  };

  String _agentLabel(AppLocalizations l10n) {
    switch (turn.agent) {
      case 'rootCause':
        return l10n.agentRootCause;
      case 'solution':
        return l10n.agentSolution;
      case 'routing':
        return l10n.agentRouting;
      case 'reportCompiler':
        return l10n.agentReportCompiler;
      default:
        return turn.agent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A fallback turn is coloured differently from a successful one, because
    // "the model reasoned about this" and "the model failed and we
    // substituted a template" must never look the same in an audit view.
    final accent = turn.usedFallback ? AppColors.saffronDeep : AppColors.teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 15,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Icon(_agentIcons[turn.agent] ?? Icons.smart_toy_rounded,
                size: 16, color: accent),
          ),
          title: Row(
            children: [
              Text('$index. ',
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkFaint,
                      fontSize: 13)),
              Flexible(
                child: Text(_agentLabel(l10n),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Tag(
                  label: turn.usedFallback ? l10n.agentUsedFallback : l10n.agentOk,
                  color: accent,
                ),
                _Tag(
                  label: '${(turn.latencyMs / 1000).toStringAsFixed(1)}s',
                  color: AppColors.inkFaint,
                ),
                if (turn.attempts > 1)
                  _Tag(
                    label: l10n.agentAttempts(turn.attempts),
                    color: AppColors.saffronDeep,
                  ),
              ],
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (turn.errorMessage != null)
              _Block(
                title: l10n.agentError,
                body: turn.errorMessage!,
                color: AppColors.vermilion,
              ),
            _Block(title: l10n.agentSystemRole, body: turn.systemRole),
            _Block(title: l10n.agentPrompt, body: turn.promptText),
            _Block(
              title: l10n.agentResponse,
              body: turn.rawResponse.isEmpty ? '—' : turn.rawResponse,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body, this.color});

  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: color ?? AppColors.inkFaint,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          // Selectable so an official can copy a claim out to check it
          // against their own records — which is the whole point of showing
          // the transcript at all.
          child: SelectableText(
            body,
            style: const TextStyle(
                fontSize: 11, fontFamily: 'monospace', height: 1.45),
          ),
        ),
      ],
    );
  }
}
