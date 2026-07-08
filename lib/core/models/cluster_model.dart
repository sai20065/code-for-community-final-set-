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
    );
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
    };
  }
}
