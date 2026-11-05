/// One Bengaluru municipal ward, from either of two layers kept side by
/// side in `wards/`:
///  - the 369 GBA wards (2025 delimitation), id `<Corporation>-<n>`,
///    [corporation] = `Central`/`East`/`North`/`South`/`West`
///    (`functions/src/scripts/seedWards.ts`);
///  - the 198 BBMP wards (2010 delimitation), id `BBMP-<wardNo>`,
///    [corporation] = `BBMP` (`functions/src/scripts/seedBbmpWards.ts`).
/// Wards roll up to a parent Lok Sabha [constituencyId] —
/// there is no separate corporator login; ward data is a visual/reporting
/// layer on top of the existing constituency-scoped MP dashboard.
class WardModel {
  final String id;

  bool get isBbmp => corporation == 'BBMP';

  /// BBMP ward number, 1–198 (null for GBA wards).
  final int? wardNo;
  final String wardName;
  final String corporation;
  final String assemblyConstituency;
  final String assemblyNo;
  final String zoneName;
  /// Sitting MLA for [assemblyConstituency], stamped on by
  /// `functions/src/scripts/seedMlaRoster.ts`. Null until that roster is
  /// seeded — the UI shows the assembly name alone rather than a blank.
  final String? mlaName;
  final String? mlaParty;
  final int totalPopulation;
  final int scPopulation;
  final int stPopulation;
  final String? constituencyId;
  // Raw GeoJSON geometry, JSON-encoded — same Firestore nested-array
  // workaround as ConstituencyModel.boundaryGeoJson.
  final String? boundaryGeoJson;

  const WardModel({
    required this.id,
    this.wardNo,
    required this.wardName,
    required this.corporation,
    required this.assemblyConstituency,
    required this.assemblyNo,
    required this.zoneName,
    this.mlaName,
    this.mlaParty,
    this.totalPopulation = 0,
    this.scPopulation = 0,
    this.stPopulation = 0,
    this.constituencyId,
    this.boundaryGeoJson,
  });

  factory WardModel.fromMap(String id, Map<String, dynamic> map) {
    return WardModel(
      id: id,
      wardNo: (map['wardNo'] as num?)?.toInt(),
      wardName: map['wardName'] as String? ?? '',
      corporation: map['corporation'] as String? ?? '',
      assemblyConstituency: map['assemblyConstituency'] as String? ?? '',
      assemblyNo: map['assemblyNo'] as String? ?? '',
      zoneName: map['zoneName'] as String? ?? '',
      mlaName: map['mlaName'] as String?,
      mlaParty: map['mlaParty'] as String?,
      totalPopulation: map['totalPopulation'] as int? ?? 0,
      scPopulation: map['scPopulation'] as int? ?? 0,
      stPopulation: map['stPopulation'] as int? ?? 0,
      constituencyId: map['constituencyId'] as String?,
      boundaryGeoJson: map['boundaryGeoJson'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (wardNo != null) 'wardNo': wardNo,
      'wardName': wardName,
      'corporation': corporation,
      'assemblyConstituency': assemblyConstituency,
      'assemblyNo': assemblyNo,
      'zoneName': zoneName,
      'mlaName': mlaName,
      'mlaParty': mlaParty,
      'totalPopulation': totalPopulation,
      'scPopulation': scPopulation,
      'stPopulation': stPopulation,
      'constituencyId': constituencyId,
      'boundaryGeoJson': boundaryGeoJson,
    };
  }
}
