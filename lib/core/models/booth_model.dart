class BoothModel {
  final String id;
  final String constituencyId;
  final String name;
  final double lat;
  final double lng;
  final List<String> pincodesCovered;
  final int openIssueCount;
  final int submissionVolume;
  final String? dominantTheme;
  final String? localContext;

  /// Population/household estimates for the booth's catchment, used to
  /// scale a cluster's impact when no ward population is available.
  /// Nullable on purpose — the agents are instructed to say "unknown"
  /// rather than invent a figure, which only works if we never hand them
  /// a fabricated one.
  final int? estimatedPopulation;
  final int? estimatedHouseholds;

  /// The ward/taluk this booth sits in, when known. Lets a cluster inherit
  /// an administrative unit even when its tickets carried no GPS fix.
  final String? wardId;
  final String? talukId;

  const BoothModel({
    required this.id,
    required this.constituencyId,
    required this.name,
    required this.lat,
    required this.lng,
    this.pincodesCovered = const [],
    this.openIssueCount = 0,
    this.submissionVolume = 0,
    this.dominantTheme,
    this.localContext,
    this.estimatedPopulation,
    this.estimatedHouseholds,
    this.wardId,
    this.talukId,
  });

  factory BoothModel.fromMap(String id, Map<String, dynamic> map) {
    return BoothModel(
      id: id,
      constituencyId: map['constituencyId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      pincodesCovered:
          (map['pincodesCovered'] as List?)?.cast<String>() ?? const [],
      openIssueCount: map['openIssueCount'] as int? ?? 0,
      submissionVolume: map['submissionVolume'] as int? ?? 0,
      dominantTheme: map['dominantTheme'] as String?,
      localContext: map['localContext'] as String?,
      estimatedPopulation: (map['estimatedPopulation'] as num?)?.toInt(),
      estimatedHouseholds: (map['estimatedHouseholds'] as num?)?.toInt(),
      wardId: map['wardId'] as String?,
      talukId: map['talukId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'constituencyId': constituencyId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'pincodesCovered': pincodesCovered,
      'openIssueCount': openIssueCount,
      'submissionVolume': submissionVolume,
      'dominantTheme': dominantTheme,
      'localContext': localContext,
      'estimatedPopulation': estimatedPopulation,
      'estimatedHouseholds': estimatedHouseholds,
      'wardId': wardId,
      'talukId': talukId,
    };
  }

  /// green/amber/red density marker color driver.
  String get densityLevel {
    if (openIssueCount >= 15) return 'red';
    if (openIssueCount >= 5) return 'amber';
    return 'green';
  }
}
