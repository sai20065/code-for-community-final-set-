import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { citizen, official }

/// How a citizen authenticated — persisted so there's a stored record of it,
/// rather than only being derivable transiently from the current Firebase
/// Auth session.
enum SignInMethod { anonymous, phone, email }

/// Identity is Firebase Auth — Anonymous, Phone (OTP), or Email/password,
/// citizen's choice (no Aadhaar number ever stored regardless of which) —
/// `users/{uid}` is created the moment sign-in succeeds and filled in
/// incrementally: name/address/pincode/wardNumber arrive from one-time
/// Aadhaar OCR extraction (image discarded immediately server-side, never
/// persisted), age from Basic Info, constituencyId from pincode resolution
/// in Location Setup. `signupCompletedAt` is the authoritative "this citizen
/// has a real, saved profile" marker — Sign In trusts it over any local,
/// per-device onboarding-progress state.
class UserModel {
  final String uid;
  final String? name;
  final int? age;
  final String? pincodeHome;
  final String? addressHome;
  final String? wardNumber;
  final double? lat;
  final double? lng;
  final UserRole role;
  final String? constituencyId;
  final String? homeBoothId;
  final String? homeBoothName;
  final String preferredLanguage;
  final SignInMethod? signInMethod;
  final double? aadhaarExtractionConfidence;
  final DateTime createdAt;
  final DateTime? signupCompletedAt;

  const UserModel({
    required this.uid,
    required this.role,
    required this.createdAt,
    this.name,
    this.age,
    this.pincodeHome,
    this.addressHome,
    this.wardNumber,
    this.lat,
    this.lng,
    this.constituencyId,
    this.homeBoothId,
    this.homeBoothName,
    this.preferredLanguage = 'en',
    this.signInMethod,
    this.aadhaarExtractionConfidence,
    this.signupCompletedAt,
  });

  static SignInMethod? _signInMethodFromString(String? value) {
    switch (value) {
      case 'phone':
        return SignInMethod.phone;
      case 'email':
        return SignInMethod.email;
      case 'anonymous':
        return SignInMethod.anonymous;
      default:
        return null;
    }
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String?,
      age: map['age'] as int?,
      pincodeHome: map['pincodeHome'] as String?,
      addressHome: map['addressHome'] as String?,
      wardNumber: map['wardNumber'] as String?,
      lat: (map['location']?['lat'] as num?)?.toDouble(),
      lng: (map['location']?['lng'] as num?)?.toDouble(),
      role: (map['role'] as String? ?? 'citizen') == 'official'
          ? UserRole.official
          : UserRole.citizen,
      constituencyId: map['constituencyId'] as String?,
      homeBoothId: map['homeBoothId'] as String?,
      homeBoothName: map['homeBoothName'] as String?,
      preferredLanguage: map['preferredLanguage'] as String? ?? 'en',
      signInMethod: _signInMethodFromString(map['signInMethod'] as String?),
      aadhaarExtractionConfidence:
          (map['aadhaarExtractionConfidence'] as num?)?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      signupCompletedAt:
          (map['signupCompletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (pincodeHome != null) 'pincodeHome': pincodeHome,
      if (addressHome != null) 'addressHome': addressHome,
      if (wardNumber != null) 'wardNumber': wardNumber,
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
      'role': role.name,
      if (constituencyId != null) 'constituencyId': constituencyId,
      if (homeBoothId != null) 'homeBoothId': homeBoothId,
      if (homeBoothName != null) 'homeBoothName': homeBoothName,
      'preferredLanguage': preferredLanguage,
      if (signInMethod != null) 'signInMethod': signInMethod!.name,
      if (aadhaarExtractionConfidence != null)
        'aadhaarExtractionConfidence': aadhaarExtractionConfidence,
      'createdAt': Timestamp.fromDate(createdAt),
      if (signupCompletedAt != null)
        'signupCompletedAt': Timestamp.fromDate(signupCompletedAt!),
    };
  }

  UserModel copyWith({
    String? name,
    int? age,
    String? pincodeHome,
    String? addressHome,
    String? wardNumber,
    double? lat,
    double? lng,
    String? constituencyId,
    String? homeBoothId,
    String? homeBoothName,
    String? preferredLanguage,
    SignInMethod? signInMethod,
    double? aadhaarExtractionConfidence,
    DateTime? signupCompletedAt,
  }) {
    return UserModel(
      uid: uid,
      role: role,
      createdAt: createdAt,
      name: name ?? this.name,
      age: age ?? this.age,
      pincodeHome: pincodeHome ?? this.pincodeHome,
      addressHome: addressHome ?? this.addressHome,
      wardNumber: wardNumber ?? this.wardNumber,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      constituencyId: constituencyId ?? this.constituencyId,
      homeBoothId: homeBoothId ?? this.homeBoothId,
      homeBoothName: homeBoothName ?? this.homeBoothName,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      signInMethod: signInMethod ?? this.signInMethod,
      aadhaarExtractionConfidence:
          aadhaarExtractionConfidence ?? this.aadhaarExtractionConfidence,
      signupCompletedAt: signupCompletedAt ?? this.signupCompletedAt,
    );
  }
}
