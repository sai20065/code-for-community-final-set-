class ClusterModel {
  final String id;
  final String constituencyId;
  final String? boothId;
  final String theme;
  final List<double> centroidVector;
  final int submissionCount;
  final List<String> sampleSubmissionIds;
  final String summaryText;
  final double? priorityScore;

  const ClusterModel({
    required this.id,
    required this.constituencyId,
    required this.theme,
    required this.submissionCount,
    required this.summaryText,
    this.boothId,
    this.centroidVector = const [],
    this.sampleSubmissionIds = const [],
    this.priorityScore,
  });

  factory ClusterModel.fromMap(String id, Map<String, dynamic> map) {
    return ClusterModel(
      id: id,
      constituencyId: map['constituencyId'] as String? ?? '',
      boothId: map['boothId'] as String?,
      theme: map['theme'] as String? ?? '',
      centroidVector:
          (map['centroidVector'] as List?)?.cast<double>() ?? const [],
      submissionCount: map['submissionCount'] as int? ?? 0,
      sampleSubmissionIds:
          (map['sampleSubmissionIds'] as List?)?.cast<String>() ?? const [],
      summaryText: map['summaryText'] as String? ?? '',
      priorityScore: (map['priorityScore'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'constituencyId': constituencyId,
      'boothId': boothId,
      'theme': theme,
      'centroidVector': centroidVector,
      'submissionCount': submissionCount,
      'sampleSubmissionIds': sampleSubmissionIds,
      'summaryText': summaryText,
      'priorityScore': priorityScore,
    };
  }
}
