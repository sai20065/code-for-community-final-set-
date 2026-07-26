/// Client mirror of `solutionCards/{clusterId}/agentTranscripts/{runId}` —
/// the auditable record of one run of the four-agent chain.
///
/// Officials only. Unlike the Solution Card itself, a transcript carries
/// each agent's raw prompt and unfiltered reply, which quote ticket text the
/// public card deliberately doesn't publish.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class AgentTurn {
  /// `rootCause` | `solution` | `routing` | `reportCompiler`.
  final String agent;

  /// The agent's persona and hard rules, as sent to the model.
  final String systemRole;
  final String promptText;
  final String rawResponse;

  final bool ok;

  /// True when this agent's output is the deterministic fallback rather than
  /// anything the model produced. The single most important field here:
  /// without it a reader can't tell reasoning from a placeholder.
  final bool usedFallback;

  final String? errorMessage;
  final int attempts;
  final int latencyMs;
  final String modelId;

  const AgentTurn({
    required this.agent,
    this.systemRole = '',
    this.promptText = '',
    this.rawResponse = '',
    this.ok = false,
    this.usedFallback = false,
    this.errorMessage,
    this.attempts = 0,
    this.latencyMs = 0,
    this.modelId = '',
  });

  factory AgentTurn.fromMap(Map<String, dynamic> map) => AgentTurn(
        agent: map['agent'] as String? ?? 'unknown',
        systemRole: map['systemRole'] as String? ?? '',
        promptText: map['promptText'] as String? ?? '',
        rawResponse: map['rawResponse'] as String? ?? '',
        ok: map['ok'] as bool? ?? false,
        usedFallback: map['usedFallback'] as bool? ?? false,
        errorMessage: map['errorMessage'] as String?,
        attempts: (map['attempts'] as num?)?.toInt() ?? 0,
        latencyMs: (map['latencyMs'] as num?)?.toInt() ?? 0,
        modelId: map['modelId'] as String? ?? '',
      );
}

class AgentRunTranscript {
  final String agentRunId;
  final String clusterId;

  /// `threshold` | `priority` | `manual`.
  final String trigger;
  final String modelId;
  final DateTime? createdAt;
  final bool degraded;
  final List<String> failedAgents;

  /// In execution order — each agent received the previous ones' outputs as
  /// conversation history, so reading them in sequence is reading the
  /// actual exchange.
  final List<AgentTurn> turns;

  const AgentRunTranscript({
    required this.agentRunId,
    required this.clusterId,
    this.trigger = 'threshold',
    this.modelId = '',
    this.createdAt,
    this.degraded = false,
    this.failedAgents = const [],
    this.turns = const [],
  });

  factory AgentRunTranscript.fromMap(Map<String, dynamic> map) {
    return AgentRunTranscript(
      agentRunId: map['agentRunId'] as String? ?? '',
      clusterId: map['clusterId'] as String? ?? '',
      trigger: map['trigger'] as String? ?? 'threshold',
      modelId: map['modelId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      degraded: map['degraded'] as bool? ?? false,
      failedAgents:
          (map['failedAgents'] as List?)?.cast<String>() ?? const [],
      turns: ((map['turns'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AgentTurn.fromMap)
          .toList(),
    );
  }

  int get totalLatencyMs =>
      turns.fold(0, (total, turn) => total + turn.latencyMs);
}
