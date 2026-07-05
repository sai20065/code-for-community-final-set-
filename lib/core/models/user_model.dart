import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { citizen, official }

/// Written incrementally across the onboarding flow (Phase 2): the phone/
/// role/createdAt/preferredLanguage fields land first at OTP verification,
/// then name/age, then location — so `users/{uid}` always exists from the
/// moment a phone number is verified, even if the user quits mid-onboarding.
class UserModel {
  final String uid;
  final String? name;
  final int? age;
  final String phone;
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
    required this.phone,
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
      phone: map['phone'] as String? ?? '',
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
      'phone': phone,
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
    String? preferredLanguage,
  }) {
    return UserModel(
      uid: uid,
      phone: phone,
      role: role,
      createdAt: createdAt,
      name: name ?? this.name,
      age: age ?? this.age,
      pincodeHome: pincodeHome ?? this.pincodeHome,
      addressHome: addressHome ?? this.addressHome,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      constituencyId: constituencyId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}
