/// Client mirror of `solutionCards/{clusterId}` — the output of the
/// four-agent civic intelligence chain (`functions/src/agents/`).
///
/// One document, two audiences: [citizenSummary] for a resident on their
/// phone, [departmentBrief] for the officer who has to act on it.
library;

import 'cluster_model.dart' show LatLngLite;

class SdgMapping {
  final int goal;
  final String goalName;

  /// Specific UN targets, e.g. `["6.1", "6.b"]`. A bare goal number is
  /// close to decorative; the target is what a reporting framework can use.
  final List<String> targets;
  final String rationale;

  const SdgMapping({
    required this.goal,
    required this.goalName,
    this.targets = const [],
    this.rationale = '',
  });

  factory SdgMapping.fromMap(Map<String, dynamic> map) => SdgMapping(
        goal: (map['goal'] as num?)?.toInt() ?? 0,
        goalName: map['goalName'] as String? ?? '',
        targets: (map['targets'] as List?)?.cast<String>() ?? const [],
        rationale: map['rationale'] as String? ?? '',
      );
}

class CostBand {
  final double min;
  final double max;

  /// Always a range, e.g. "₹8–12 lakh" — an estimate presented as a precise
  /// figure would imply a costing exercise that never happened.
  final String label;

  const CostBand({required this.min, required this.max, required this.label});

  factory CostBand.fromMap(Map<String, dynamic>? map) => CostBand(
        min: (map?['min'] as num?)?.toDouble() ?? 0,
        max: (map?['max'] as num?)?.toDouble() ?? 0,
        label: map?['label'] as String? ?? '',
      );

  bool get isEstimated => max > 0;
}

class Intervention {
  final String title;
  final String description;
  final String interventionType;
  final CostBand costBand;
  final int timelineMinWeeks;
  final int timelineMaxWeeks;

  /// Null when the affected population is genuinely unknown. The Solution
  /// agent is instructed to say so rather than invent a figure, and the UI
  /// must show "not estimated" rather than a zero.
  final int? householdsAddressed;
  final int? peopleAddressed;
  final String impactRationale;
  final List<String> prerequisites;

  const Intervention({
    required this.title,
    required this.description,
    required this.interventionType,
    required this.costBand,
    this.timelineMinWeeks = 0,
    this.timelineMaxWeeks = 0,
    this.householdsAddressed,
    this.peopleAddressed,
    this.impactRationale = '',
    this.prerequisites = const [],
  });

  factory Intervention.fromMap(Map<String, dynamic> map) {
    final impact = map['impact'] as Map<String, dynamic>?;
    final timeline = map['timelineWeeks'] as Map<String, dynamic>?;
    return Intervention(
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      interventionType: map['interventionType'] as String? ?? 'maintenance',
      costBand: CostBand.fromMap(map['costBandInr'] as Map<String, dynamic>?),
      timelineMinWeeks: (timeline?['min'] as num?)?.toInt() ?? 0,
      timelineMaxWeeks: (timeline?['max'] as num?)?.toInt() ?? 0,
      householdsAddressed: (impact?['householdsAddressed'] as num?)?.toInt(),
      peopleAddressed: (impact?['peopleAddressed'] as num?)?.toInt(),
      impactRationale: impact?['rationale'] as String? ?? '',
      prerequisites:
          (map['prerequisites'] as List?)?.cast<String>() ?? const [],
    );
  }
}

class DepartmentRef {
  final String departmentId;
  final String name;
  final String? shortName;
  final String jurisdictionLevel;
  final String? email;
  final String? phone;
  final String? grievancePortalUrl;

  const DepartmentRef({
    required this.departmentId,
    required this.name,
    this.shortName,
    this.jurisdictionLevel = 'municipal',
    this.email,
    this.phone,
    this.grievancePortalUrl,
  });

  factory DepartmentRef.fromMap(Map<String, dynamic> map) => DepartmentRef(
        departmentId: map['departmentId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        shortName: map['shortName'] as String?,
        jurisdictionLevel: map['jurisdictionLevel'] as String? ?? 'municipal',
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        grievancePortalUrl: map['grievancePortalUrl'] as String?,
      );

  bool get hasContact =>
      (email?.isNotEmpty ?? false) ||
      (phone?.isNotEmpty ?? false) ||
      (grievancePortalUrl?.isNotEmpty ?? false);
}

class RoutingInfo {
  final String jurisdictionLevel;
  final String jurisdictionRationale;
  final DepartmentRef primary;
  final DepartmentRef? escalation;
  final String? mpName;
  final String constituencyName;

  /// `exact`, `state-fallback` or `national-fallback`. Surfaced in the UI:
  /// being pointed at the actual local water board is a materially stronger
  /// answer than a catch-all central portal, and hiding that difference
  /// would overstate what the routing knows.
  final String matchQuality;

  const RoutingInfo({
    required this.primary,
    required this.constituencyName,
    this.jurisdictionLevel = 'municipal',
    this.jurisdictionRationale = '',
    this.escalation,
    this.mpName,
    this.matchQuality = 'national-fallback',
  });

  factory RoutingInfo.fromMap(Map<String, dynamic>? map) {
    final mp = map?['mp'] as Map<String, dynamic>?;
    final escalation = map?['escalation'] as Map<String, dynamic>?;
    return RoutingInfo(
      jurisdictionLevel: map?['jurisdictionLevel'] as String? ?? 'municipal',
      jurisdictionRationale: map?['jurisdictionRationale'] as String? ?? '',
      primary: DepartmentRef.fromMap(
          (map?['primary'] as Map<String, dynamic>?) ?? const {}),
      escalation:
          escalation == null ? null : DepartmentRef.fromMap(escalation),
      mpName: mp?['mpName'] as String?,
      constituencyName: mp?['constituencyName'] as String? ?? '',
      matchQuality: map?['matchQuality'] as String? ?? 'national-fallback',
    );
  }

  bool get isPreciseMatch => matchQuality == 'exact';
}

class RootCauseInfo {
  final String summary;
  final List<String> causalChain;
  final List<RootCauseClaim> claims;
  final String seasonality;
  final List<String> dataGaps;
  final double confidence;

  const RootCauseInfo({
    this.summary = '',
    this.causalChain = const [],
    this.claims = const [],
    this.seasonality = 'unclear',
    this.dataGaps = const [],
    this.confidence = 0,
  });

  factory RootCauseInfo.fromMap(Map<String, dynamic>? map) => RootCauseInfo(
        summary: map?['rootCauseSummary'] as String? ?? '',
        causalChain: (map?['causalChain'] as List?)?.cast<String>() ?? const [],
        claims: ((map?['claims'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RootCauseClaim.fromMap)
            .toList(),
        seasonality: map?['seasonality'] as String? ?? 'unclear',
        dataGaps: (map?['dataGaps'] as List?)?.cast<String>() ?? const [],
        confidence: (map?['confidence'] as num?)?.toDouble() ?? 0,
      );

  /// True when the analysis produced nothing usable. The UI says so plainly
  /// rather than rendering an empty section that looks like a real finding.
  bool get isEmpty => confidence == 0 && claims.isEmpty;
}

class RootCauseClaim {
  final String claim;

  /// Token ids and named statistics backing this claim. Guaranteed
  /// non-empty server-side — an uncited claim fails validation.
  final List<String> citations;

  const RootCauseClaim({required this.claim, this.citations = const []});

  factory RootCauseClaim.fromMap(Map<String, dynamic> map) {
    final raw = (map['citations'] as List?) ?? const [];
    return RootCauseClaim(
      claim: map['claim'] as String? ?? '',
      citations: [
        for (final c in raw.whereType<Map>())
          (c['tokenId'] ?? c['stat'] ?? '').toString(),
      ]..removeWhere((s) => s.isEmpty),
    );
  }
}

class SolutionCardModel {
  final String clusterId;
  final String constituencyId;
  final String constituencyName;
  final String theme;
  final LatLngLite? centroid;

  final String headline;
  final String citizenSummary;

  final String problemStatement;
  final String rootCauseText;
  final List<String> recommendedActions;

  /// Each line ends with a `(PD-…)` token reference. Lines citing a token
  /// the agents weren't shown are rejected server-side.
  final List<String> evidence;
  final String costBandLabel;
  final String expectedImpact;

  final List<SdgMapping> sdg;
  final RoutingInfo routing;
  final RootCauseInfo rootCause;
  final List<Intervention> interventions;
  final String? quickWin;

  final int priorityScore;
  final int submissionCount;
  final int uniqueReporterCount;
  final List<String> tokenIdsCited;

  final int version;

  /// True when one or more agents fell back. A card assembled from
  /// fallbacks must not present with the same authority as one where every
  /// agent succeeded, so the UI labels it.
  final bool degraded;
  final List<String> failedAgents;

  const SolutionCardModel({
    required this.clusterId,
    required this.constituencyId,
    required this.constituencyName,
    required this.theme,
    required this.headline,
    required this.citizenSummary,
    this.centroid,
    this.problemStatement = '',
    this.rootCauseText = '',
    this.recommendedActions = const [],
    this.evidence = const [],
    this.costBandLabel = '',
    this.expectedImpact = '',
    this.sdg = const [],
    required this.routing,
    this.rootCause = const RootCauseInfo(),
    this.interventions = const [],
    this.quickWin,
    this.priorityScore = 0,
    this.submissionCount = 0,
    this.uniqueReporterCount = 0,
    this.tokenIdsCited = const [],
    this.version = 1,
    this.degraded = false,
    this.failedAgents = const [],
  });

  factory SolutionCardModel.fromMap(String id, Map<String, dynamic> map) {
    final brief = map['departmentBrief'] as Map<String, dynamic>?;
    final solutions = map['solutions'] as Map<String, dynamic>?;
    return SolutionCardModel(
      clusterId: map['clusterId'] as String? ?? id,
      constituencyId: map['constituencyId'] as String? ?? '',
      constituencyName: map['constituencyName'] as String? ?? '',
      theme: map['theme'] as String? ?? 'unknown',
      centroid: LatLngLite.fromMap(map['centroid']),
      headline: map['headline'] as String? ?? '',
      citizenSummary: map['citizenSummary'] as String? ?? '',
      problemStatement: brief?['problemStatement'] as String? ?? '',
      rootCauseText: brief?['rootCause'] as String? ?? '',
      recommendedActions:
          (brief?['recommendedActions'] as List?)?.cast<String>() ?? const [],
      evidence: (brief?['evidence'] as List?)?.cast<String>() ?? const [],
      costBandLabel: brief?['costBandLabel'] as String? ?? '',
      expectedImpact: brief?['expectedImpact'] as String? ?? '',
      sdg: ((map['sdg'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SdgMapping.fromMap)
          .toList(),
      routing: RoutingInfo.fromMap(map['routing'] as Map<String, dynamic>?),
      rootCause:
          RootCauseInfo.fromMap(map['rootCause'] as Map<String, dynamic>?),
      interventions: ((solutions?['interventions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Intervention.fromMap)
          .toList(),
      quickWin: solutions?['quickWin'] as String?,
      priorityScore: (map['priorityScore'] as num?)?.toInt() ?? 0,
      submissionCount: (map['submissionCount'] as num?)?.toInt() ?? 0,
      uniqueReporterCount: (map['uniqueReporterCount'] as num?)?.toInt() ?? 0,
      tokenIdsCited:
          (map['tokenIdsCited'] as List?)?.cast<String>() ?? const [],
      version: (map['version'] as num?)?.toInt() ?? 1,
      degraded: map['degraded'] as bool? ?? false,
      failedAgents:
          (map['failedAgents'] as List?)?.cast<String>() ?? const [],
    );
  }

  Intervention? get primaryIntervention =>
      interventions.isEmpty ? null : interventions.first;

  List<int> get sdgGoals => sdg.map((s) => s.goal).toList();
}
