/// One of Karnataka's 30 districts (official KSRSAC/KGIS boundary data — see
/// `functions/src/scripts/seedTaluksAndDistricts.ts`).
///
/// A district can span several Lok Sabha constituencies, so it is a browsing
/// and display layer only — never a routing unit. Citizens pick
/// District → Taluk (or District → BBMP ward inside Bengaluru Urban) to
/// choose which area's map they want to look at.
class DistrictModel {
  final String id;
  final String name;
  // Raw GeoJSON geometry, JSON-encoded — same Firestore nested-array
  // workaround as ConstituencyModel.boundaryGeoJson.
  final String? boundaryGeoJson;

  const DistrictModel({
    required this.id,
    required this.name,
    this.boundaryGeoJson,
  });

  factory DistrictModel.fromMap(String id, Map<String, dynamic> map) {
    return DistrictModel(
      id: id,
      name: map['name'] as String? ?? '',
      boundaryGeoJson: map['boundaryGeoJson'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'boundaryGeoJson': boundaryGeoJson,
      };
}
