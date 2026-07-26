/// Client-side mirrors of the anonymised projections written by
/// `functions/src/public/projection.ts`.
///
/// These are the ONLY collections the public dashboard reads. There is
/// deliberately no field here for a reporter's identity, their words, their
/// pincode or their exact location — not because the UI chooses not to show
/// them, but because they are never written to these collections at all.
library;

import 'cluster_model.dart' show LatLngLite;

/// A single civic report, as the public may see it. `tokenId` is the only
/// identifier — the same receipt code the citizen already holds, designed to
/// carry no personal information.
class PublicTicketModel {
  final String id;
  final String tokenId;
  final String? theme;
  final String submissionCategory;
  final String status;

  /// AI-generated under an explicit no-PII instruction and scrubbed
  /// afterwards. Never the citizen's own words.
  final String publicSummary;

  final String constituencyId;
  final String? constituencyName;
  final String? wardId;
  final String? talukId;
  final String? boothId;
  final String? clusterId;
  final int supporterCount;

  /// Day granularity, never a timestamp — a precise filing time next to
  /// even a blurred location would be a re-identification vector.
  final String createdDate;
  final String createdWeek;
  final String? resolvedDate;

  final LatLngLite? geo;

  /// `approx-300m`, `ward`, or `none`. Rendered honestly rather than
  /// implying a precision the point doesn't have.
  final String geoPrecision;

  const PublicTicketModel({
    required this.id,
    required this.tokenId,
    required this.submissionCategory,
    required this.status,
    required this.publicSummary,
    required this.constituencyId,
    required this.createdDate,
    required this.createdWeek,
    this.theme,
    this.constituencyName,
    this.wardId,
    this.talukId,
    this.boothId,
    this.clusterId,
    this.supporterCount = 0,
    this.resolvedDate,
    this.geo,
    this.geoPrecision = 'none',
  });

  factory PublicTicketModel.fromMap(String id, Map<String, dynamic> map) {
    return PublicTicketModel(
      id: id,
      tokenId: map['tokenId'] as String? ?? '',
      theme: map['theme'] as String?,
      submissionCategory: map['submissionCategory'] as String? ?? 'problem',
      status: map['status'] as String? ?? 'new',
      publicSummary: map['publicSummary'] as String? ?? '',
      constituencyId: map['constituencyId'] as String? ?? '',
      constituencyName: map['constituencyName'] as String?,
      wardId: map['wardId'] as String?,
      talukId: map['talukId'] as String?,
      boothId: map['boothId'] as String?,
      clusterId: map['clusterId'] as String?,
      supporterCount: (map['supporterCount'] as num?)?.toInt() ?? 0,
      createdDate: map['createdDate'] as String? ?? '',
      createdWeek: map['createdWeek'] as String? ?? '',
      resolvedDate: map['resolvedDate'] as String?,
      geo: LatLngLite.fromMap(map['geo']),
      geoPrecision: map['geoPrecision'] as String? ?? 'none',
    );
  }

  bool get isApproximateLocation => geoPrecision != 'none';
}

/// An aggregated issue group — the unit the map, the hotspot leaderboard
/// and the Solution Cards are all keyed on.
class PublicClusterModel {
  final String id;
  final String constituencyId;
  final String? constituencyName;
  final String theme;
  final String? boothId;
  final String? wardId;
  final String? talukId;

  final int submissionCount;
  final int uniqueReporterCount;
  final double priorityScore;
  final double? demandScore;
  final double? demographicScore;
  final double? infraGapScore;

  final String summaryText;
  final String? title;
  final String? affectedBoothRange;
  final String? localContext;
  final LatLngLite? centroid;
  final String? firstReportedDate;
  final String? lastReportedDate;

  /// ISO-week key → count. Drives the sparkline.
  final Map<String, int> weeklyCounts;
  final Map<String, int> statusCounts;

  final bool hasSolutionCard;
  final int solutionCardVersion;

  const PublicClusterModel({
    required this.id,
    required this.constituencyId,
    required this.theme,
    required this.submissionCount,
    required this.priorityScore,
    required this.summaryText,
    this.constituencyName,
    this.boothId,
    this.wardId,
    this.talukId,
    this.uniqueReporterCount = 0,
    this.demandScore,
    this.demographicScore,
    this.infraGapScore,
    this.title,
    this.affectedBoothRange,
    this.localContext,
    this.centroid,
    this.firstReportedDate,
    this.lastReportedDate,
    this.weeklyCounts = const {},
    this.statusCounts = const {},
    this.hasSolutionCard = false,
    this.solutionCardVersion = 0,
  });

  factory PublicClusterModel.fromMap(String id, Map<String, dynamic> map) {
    return PublicClusterModel(
      id: id,
      constituencyId: map['constituencyId'] as String? ?? '',
      constituencyName: map['constituencyName'] as String?,
      theme: map['theme'] as String? ?? 'unknown',
      boothId: map['boothId'] as String?,
      wardId: map['wardId'] as String?,
      talukId: map['talukId'] as String?,
      submissionCount: (map['submissionCount'] as num?)?.toInt() ?? 0,
      uniqueReporterCount: (map['uniqueReporterCount'] as num?)?.toInt() ?? 0,
      priorityScore: (map['priorityScore'] as num?)?.toDouble() ?? 0,
      demandScore: (map['demandScore'] as num?)?.toDouble(),
      demographicScore: (map['demographicScore'] as num?)?.toDouble(),
      infraGapScore: (map['infraGapScore'] as num?)?.toDouble(),
      summaryText: map['summaryText'] as String? ?? '',
      title: map['title'] as String?,
      affectedBoothRange: map['affectedBoothRange'] as String?,
      localContext: map['localContext'] as String?,
      centroid: LatLngLite.fromMap(map['centroid']),
      firstReportedDate: map['firstReportedDate'] as String?,
      lastReportedDate: map['lastReportedDate'] as String?,
      weeklyCounts: _intMap(map['weeklyCounts']),
      statusCounts: _intMap(map['statusCounts']),
      hasSolutionCard: map['hasSolutionCard'] as bool? ?? false,
      solutionCardVersion: (map['solutionCardVersion'] as num?)?.toInt() ?? 0,
    );
  }

  int get resolvedCount => statusCounts['resolved'] ?? 0;

  /// The last 12 weeks of activity in chronological order, zero-filled so
  /// the sparkline shows quiet weeks as gaps rather than closing over them
  /// — a flat line at zero is information.
  List<int> get recentWeeklySeries {
    final keys = weeklyCounts.keys.toList()..sort();
    final recent = keys.length <= 12 ? keys : keys.sublist(keys.length - 12);
    return [for (final k in recent) weeklyCounts[k] ?? 0];
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
    };
  }
}
