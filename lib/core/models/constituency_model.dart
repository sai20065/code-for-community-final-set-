class ConstituencyModel {
  final String id;
  final String name;
  final String state;
  final String mpUserId;
  final Map<String, dynamic>? boundaryGeoJson;

  const ConstituencyModel({
    required this.id,
    required this.name,
    required this.state,
    required this.mpUserId,
    this.boundaryGeoJson,
  });

  factory ConstituencyModel.fromMap(String id, Map<String, dynamic> map) {
    return ConstituencyModel(
      id: id,
      name: map['name'] as String? ?? '',
      state: map['state'] as String? ?? '',
      mpUserId: map['mpUserId'] as String? ?? '',
      boundaryGeoJson: map['boundaryGeoJson'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'state': state,
      'mpUserId': mpUserId,
      'boundaryGeoJson': boundaryGeoJson,
    };
  }
}
