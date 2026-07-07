class ConstituencyModel {
  final String id;
  final String name;
  final String state;
  final String mpUserId;
  final String? mpName;
  final String? mpPhotoUrl;
  // Raw GeoJSON geometry, JSON-encoded — Firestore rejects arrays nested
  // directly in arrays, which is exactly what GeoJSON coordinate rings are,
  // so this is stored/read as a string rather than a nested map. Routing
  // itself doesn't depend on this field (see
  // functions/src/lib/constituencyGeo.ts); it's kept for any future
  // map-rendering use.
  final String? boundaryGeoJson;

  const ConstituencyModel({
    required this.id,
    required this.name,
    required this.state,
    required this.mpUserId,
    this.mpName,
    this.mpPhotoUrl,
    this.boundaryGeoJson,
  });

  factory ConstituencyModel.fromMap(String id, Map<String, dynamic> map) {
    return ConstituencyModel(
      id: id,
      name: map['name'] as String? ?? '',
      state: map['state'] as String? ?? '',
      mpUserId: map['mpUserId'] as String? ?? '',
      mpName: map['mpName'] as String?,
      mpPhotoUrl: map['mpPhotoUrl'] as String?,
      boundaryGeoJson: map['boundaryGeoJson'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'state': state,
      'mpUserId': mpUserId,
      if (mpName != null) 'mpName': mpName,
      if (mpPhotoUrl != null) 'mpPhotoUrl': mpPhotoUrl,
      'boundaryGeoJson': boundaryGeoJson,
    };
  }
}
