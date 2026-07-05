class BoothModel {
  final String id;
  final String constituencyId;
  final String name;
  final double lat;
  final double lng;
  final List<String> pincodesCovered;
  final int openIssueCount;

  const BoothModel({
    required this.id,
    required this.constituencyId,
    required this.name,
    required this.lat,
    required this.lng,
    this.pincodesCovered = const [],
    this.openIssueCount = 0,
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
    };
  }

  /// green/amber/red density marker color driver (Section 5.2).
  String get densityLevel {
    if (openIssueCount >= 15) return 'red';
    if (openIssueCount >= 5) return 'amber';
    return 'green';
  }
}
