import 'package:cloud_firestore/cloud_firestore.dart';

/// A plain lat/lng pair.
///
/// Deliberately not `latlong2`'s `LatLng`: the model layer is shared with
/// code that has no business depending on a mapping package, and this is
/// only ever converted at the widget boundary.
class LatLngLite {
  final double lat;
  final double lng;

  const LatLngLite(this.lat, this.lng);

  static LatLngLite? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLngLite(lat, lng);
  }

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
}

/// A recurring theme auto-grouped from citizen tickets — doubles as the
/// "development work" / ranked proposal entity shown on the MP dashboard's
/// ranked-works panel and compare tool. `priorityScore` is the composite
/// (0-100) shown as the segmented rank bar, broken down into
/// `demandScore` (citizen volume/support), `demographicScore` (population/
/// beneficiary weight), and `infraGapScore` (existing capacity shortfall) —
/// these three roughly sum to `priorityScore` and are what the compare
/// tool's AI recommendation line cites directly.
class ClusterModel {
  final String id;
  final String constituencyId;
  final String? boothId;
  final String? wardId;
  final String? talukId;
  final String theme;
  final List<double> centroidVector;
  final int submissionCount;
  final List<String> sampleSubmissionIds;
  final String summaryText;
  final double? priorityScore;
  final String? title;
  final double? demandScore;
  final double? demographicScore;
  final double? infraGapScore;
  final String? localContext;
  final String? affectedBoothRange;

  // --- Grounding data for the civic-intelligence agents -------------------
  // Written incrementally by `clusterAggregates.ts`. All nullable: legacy
  // and seeded clusters predate these, and every consumer must degrade
  // gracefully rather than assume they're present.

  /// Mean position of the cluster's member tickets. The map's primary
  /// hotspot anchor — hotspots used to be derived only from ward/taluk
  /// polygon centroids, so any cluster without ward geometry produced no
  /// marker at all.
  final LatLngLite? centroid;

  /// Where [centroid] came from: `submissions`, `booth`, `ward`, `taluk`
  /// or `seed`. Kept for debugging why a hotspot sits where it does.
  final String? centroidSource;

  final DateTime? firstReportedAt;
  final DateTime? lastReportedAt;

  /// ISO-week key → report count, e.g. `{"2026-W30": 3}`. Capped at 26
  /// weeks server-side. Drives the sparkline on cluster cards.
  final Map<String, int> weeklyCounts;

  /// Distinct reporters, derived from salted hashes server-side — the raw
  /// uids are never stored on a cluster. Distinguishes "forty households"
  /// from "one very persistent neighbour", which changes the analysis
  /// completely.
  final int? uniqueReporterCount;

  final Map<String, int> statusCounts;

  /// Estimate, not a measurement — surfaced with hedging wherever shown.
  final int? estimatedAffectedHouseholds;

  final bool hasSolutionCard;
  final DateTime? lastAgentRunAt;

  const ClusterModel({
    required this.id,
    required this.constituencyId,
    required this.theme,
    required this.submissionCount,
    required this.summaryText,
    this.boothId,
    this.wardId,
    this.talukId,
    this.centroidVector = const [],
    this.sampleSubmissionIds = const [],
    this.priorityScore,
    this.title,
    this.demandScore,
    this.demographicScore,
    this.infraGapScore,
    this.localContext,
    this.affectedBoothRange,
    this.centroid,
    this.centroidSource,
    this.firstReportedAt,
    this.lastReportedAt,
    this.weeklyCounts = const {},
    this.uniqueReporterCount,
    this.statusCounts = const {},
    this.estimatedAffectedHouseholds,
    this.hasSolutionCard = false,
    this.lastAgentRunAt,
  });

  factory ClusterModel.fromMap(String id, Map<String, dynamic> map) {
    return ClusterModel(
      id: id,
      constituencyId: map['constituencyId'] as String? ?? '',
      boothId: map['boothId'] as String?,
      wardId: map['wardId'] as String?,
      talukId: map['talukId'] as String?,
      theme: map['theme'] as String? ?? '',
      centroidVector:
          (map['centroidVector'] as List?)?.cast<double>() ?? const [],
      submissionCount: map['submissionCount'] as int? ?? 0,
      sampleSubmissionIds:
          (map['sampleSubmissionIds'] as List?)?.cast<String>() ?? const [],
      summaryText: map['summaryText'] as String? ?? '',
      priorityScore: (map['priorityScore'] as num?)?.toDouble(),
      title: map['title'] as String?,
      demandScore: (map['demandScore'] as num?)?.toDouble(),
      demographicScore: (map['demographicScore'] as num?)?.toDouble(),
      infraGapScore: (map['infraGapScore'] as num?)?.toDouble(),
      localContext: map['localContext'] as String?,
      affectedBoothRange: map['affectedBoothRange'] as String?,
      centroid: LatLngLite.fromMap(map['centroid']),
      centroidSource: map['centroidSource'] as String?,
      firstReportedAt: (map['firstReportedAt'] as Timestamp?)?.toDate(),
      lastReportedAt: (map['lastReportedAt'] as Timestamp?)?.toDate(),
      weeklyCounts: _intMap(map['weeklyCounts']),
      uniqueReporterCount: (map['uniqueReporterCount'] as num?)?.toInt(),
      statusCounts: _intMap(map['statusCounts']),
      estimatedAffectedHouseholds:
          (map['estimatedAffectedHouseholds'] as num?)?.toInt(),
      hasSolutionCard: map['hasSolutionCard'] as bool? ?? false,
      lastAgentRunAt: (map['lastAgentRunAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'constituencyId': constituencyId,
      'boothId': boothId,
      'wardId': wardId,
      'talukId': talukId,
      'theme': theme,
      'centroidVector': centroidVector,
      'submissionCount': submissionCount,
      'sampleSubmissionIds': sampleSubmissionIds,
      'summaryText': summaryText,
      'priorityScore': priorityScore,
      'title': title,
      'demandScore': demandScore,
      'demographicScore': demographicScore,
      'infraGapScore': infraGapScore,
      'localContext': localContext,
      'affectedBoothRange': affectedBoothRange,
      'centroid': centroid?.toMap(),
      'centroidSource': centroidSource,
      'weeklyCounts': weeklyCounts,
      'uniqueReporterCount': uniqueReporterCount,
      'statusCounts': statusCounts,
      'estimatedAffectedHouseholds': estimatedAffectedHouseholds,
      'hasSolutionCard': hasSolutionCard,
      // firstReportedAt/lastReportedAt/lastAgentRunAt are deliberately
      // omitted: they are server-maintained timestamps, and echoing a
      // client-side DateTime back would let a stale read overwrite them.
    };
  }
}
