import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { citizen, official }

/// Identity is Firebase Anonymous Auth (no phone number, no Aadhaar number
/// ever stored) — `users/{uid}` is created the moment sign-in succeeds and
/// filled in incrementally: name/address/pincode arrive from one-time
/// Aadhaar OCR extraction (image discarded immediately server-side, never
/// persisted), age from Basic Info, constituencyId from pincode resolution
/// in Location Setup.
class UserModel {
  final String uid;
  final String? name;
  final int? age;
  final String? pincodeHome;
  final String? addressHome;
  final double? lat;
  final double? lng;
  final UserRole role;
  final String? constituencyId;
  final String preferredLanguage;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.role,
    required this.createdAt,
    this.name,
    this.age,
    this.pincodeHome,
    this.addressHome,
    this.lat,
    this.lng,
    this.constituencyId,
    this.preferredLanguage = 'en',
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String?,
      age: map['age'] as int?,
      pincodeHome: map['pincodeHome'] as String?,
      addressHome: map['addressHome'] as String?,
      lat: (map['location']?['lat'] as num?)?.toDouble(),
      lng: (map['location']?['lng'] as num?)?.toDouble(),
      role: (map['role'] as String? ?? 'citizen') == 'official'
          ? UserRole.official
          : UserRole.citizen,
      constituencyId: map['constituencyId'] as String?,
      preferredLanguage: map['preferredLanguage'] as String? ?? 'en',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (pincodeHome != null) 'pincodeHome': pincodeHome,
      if (addressHome != null) 'addressHome': addressHome,
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
      'role': role.name,
      if (constituencyId != null) 'constituencyId': constituencyId,
      'preferredLanguage': preferredLanguage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? name,
    int? age,
    String? pincodeHome,
    String? addressHome,
    double? lat,
    double? lng,
    String? constituencyId,
    String? preferredLanguage,
  }) {
    return UserModel(
      uid: uid,
      role: role,
      createdAt: createdAt,
      name: name ?? this.name,
      age: age ?? this.age,
      pincodeHome: pincodeHome ?? this.pincodeHome,
      addressHome: addressHome ?? this.addressHome,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      constituencyId: constituencyId ?? this.constituencyId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}
