/// One of Karnataka's 227 taluks (official KSRSAC/KGIS boundary data — see
/// `functions/src/scripts/seedTaluksAndDistricts.ts`). Taluks are the
/// ward-equivalent fine-grained map/reporting unit for every constituency
/// outside Bengaluru Urban, which uses [WardModel]'s 369 GBA wards instead.
class TalukModel {
  final String id;
  final String talukName;
  final String? districtId;
  final String? districtName;
  final String? constituencyId;
  // Raw GeoJSON geometry, JSON-encoded — same Firestore nested-array
  // workaround as ConstituencyModel.boundaryGeoJson.
  final String? boundaryGeoJson;

  const TalukModel({
    required this.id,
    required this.talukName,
    this.districtId,
    this.districtName,
    this.constituencyId,
    this.boundaryGeoJson,
  });

  factory TalukModel.fromMap(String id, Map<String, dynamic> map) {
    return TalukModel(
      id: id,
      talukName: map['talukName'] as String? ?? '',
      districtId: map['districtId'] as String?,
      districtName: map['districtName'] as String?,
      constituencyId: map['constituencyId'] as String?,
      boundaryGeoJson: map['boundaryGeoJson'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'talukName': talukName,
      'districtId': districtId,
      'districtName': districtName,
      'constituencyId': constituencyId,
      'boundaryGeoJson': boundaryGeoJson,
    };
  }
}
