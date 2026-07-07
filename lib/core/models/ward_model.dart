/// One of Bengaluru's 369 Greater Bengaluru Authority (GBA) municipal wards
/// (final delimitation, notified 19 Nov 2025 — see `functions/src/scripts/
/// seedWards.ts`). Wards roll up to a parent Lok Sabha [constituencyId] —
/// there is no separate corporator login; ward data is a visual/reporting
/// layer on top of the existing constituency-scoped MP dashboard.
class WardModel {
  final String id;
  final String wardName;
  final String corporation;
  final String assemblyConstituency;
  final String assemblyNo;
  final String zoneName;
  final int totalPopulation;
  final int scPopulation;
  final int stPopulation;
  final String? constituencyId;
  // Raw GeoJSON geometry, JSON-encoded — same Firestore nested-array
  // workaround as ConstituencyModel.boundaryGeoJson.
  final String? boundaryGeoJson;

  const WardModel({
    required this.id,
    required this.wardName,
    required this.corporation,
    required this.assemblyConstituency,
    required this.assemblyNo,
    required this.zoneName,
    this.totalPopulation = 0,
    this.scPopulation = 0,
    this.stPopulation = 0,
    this.constituencyId,
    this.boundaryGeoJson,
  });

  factory WardModel.fromMap(String id, Map<String, dynamic> map) {
    return WardModel(
      id: id,
      wardName: map['wardName'] as String? ?? '',
      corporation: map['corporation'] as String? ?? '',
      assemblyConstituency: map['assemblyConstituency'] as String? ?? '',
      assemblyNo: map['assemblyNo'] as String? ?? '',
      zoneName: map['zoneName'] as String? ?? '',
      totalPopulation: map['totalPopulation'] as int? ?? 0,
      scPopulation: map['scPopulation'] as int? ?? 0,
      stPopulation: map['stPopulation'] as int? ?? 0,
      constituencyId: map['constituencyId'] as String?,
      boundaryGeoJson: map['boundaryGeoJson'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wardName': wardName,
      'corporation': corporation,
      'assemblyConstituency': assemblyConstituency,
      'assemblyNo': assemblyNo,
      'zoneName': zoneName,
      'totalPopulation': totalPopulation,
      'scPopulation': scPopulation,
      'stPopulation': stPopulation,
      'constituencyId': constituencyId,
      'boundaryGeoJson': boundaryGeoJson,
    };
  }
}
