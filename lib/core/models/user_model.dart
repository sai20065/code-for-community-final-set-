import 'package:cloud_firestore/cloud_firestore.dart';

/// `admin` = Prajadhwani platform admin (approves officials). Granted only
/// by `functions/src/scripts/makeAdmin.ts`; rules forbid any client write.
enum UserRole { citizen, official, admin }

/// How a citizen authenticated — persisted so there's a stored record of it,
/// rather than only being derivable transiently from the current Firebase
/// Auth session. [password] (username + password) is the only method new
/// citizens can use; the others are kept so older profiles still parse.
enum SignInMethod { password, anonymous, phone, email }

/// Identity is Firebase Auth username + password (the username is mapped to
/// a synthetic address internally — see `AuthService`; no email or phone
/// number is ever asked for or stored). `users/{uid}` is created at Sign Up
/// with [username] and name, then filled in incrementally: home location
/// and constituency at Location Setup. `signupCompletedAt` is the
/// authoritative "this citizen has a real, saved profile" marker — Sign In
/// trusts it over any local, per-device onboarding-progress state.
class UserModel {
  final String uid;
  final String? name;

  /// Lowercase login name, unique app-wide via `usernames/{username}`.
  final String? username;
  final int? age;
  final String? pincodeHome;
  final String? addressHome;
  final String? wardNumber;
  final double? lat;
  final double? lng;
  final UserRole role;
  final String? constituencyId;

  /// Display name for [constituencyId] (e.g. "Chikballapur"), saved at
  /// Location Setup so the profile never has to show a bare id.
  final String? constituencyName;
  final String? homeBoothId;
  final String? homeBoothName;

  /// Home district / taluk / ward, resolved by point-in-polygon from the
  /// citizen's confirmed location at Location Setup (see
  /// `functions/src/constituencies/resolveConstituencyForLocation.ts`).
  ///
  /// These are what actually place a citizen on the map — a pincode does
  /// not: pincodes are postal routing areas that straddle taluk and ward
  /// boundaries, so [pincodeHome] is a display/contact field, never the
  /// thing an area query is keyed on. Null outside Karnataka (district,
  /// taluk) or outside Bengaluru (ward), which is normal, not an error.
  final String? districtId;
  final String? districtName;
  final String? talukId;
  final String? talukName;
  final String? homeWardId;
  final String? homeWardName;

  /// Home ward in the 198-ward BBMP layer (alongside the GBA [homeWardId]).
  final String? homeBbmpWardId;
  final String? homeBbmpWardName;

  /// Storage path of the citizen's optional profile photo
  /// (`avatars/{uid}/avatar.jpg`). Read through Storage rules, never a
  /// public URL.
  final String? photoPath;

  /// Set by the `setSecurityQuestion` function, so the profile can show
  /// whether password recovery is set up without reading `userSecrets`.
  final bool hasSecurityQuestion;

  // ---- Officials (server-written; see reviewOfficialApplication.ts) -------
  /// `mp` | `mla` | `wardOfficer` | `tahsildar` | `districtOfficer`. Null on
  /// legacy MP accounts, which are treated as `mp`.
  final String? officialType;

  /// `constituency` | `assembly` | `bbmpWard` | `taluk` | `district`.
  final String? jurisdictionType;
  final String? jurisdictionId;
  final String? jurisdictionName;
  final String? designation;
  final String? officialEmail;
  final DateTime? approvedAt;
  final String preferredLanguage;
  final SignInMethod? signInMethod;
  final DateTime createdAt;
  final DateTime? signupCompletedAt;

  const UserModel({
    required this.uid,
    required this.role,
    required this.createdAt,
    this.name,
    this.username,
    this.age,
    this.pincodeHome,
    this.addressHome,
    this.wardNumber,
    this.lat,
    this.lng,
    this.constituencyId,
    this.constituencyName,
    this.homeBoothId,
    this.homeBoothName,
    this.districtId,
    this.districtName,
    this.talukId,
    this.talukName,
    this.homeWardId,
    this.homeWardName,
    this.homeBbmpWardId,
    this.homeBbmpWardName,
    this.photoPath,
    this.hasSecurityQuestion = false,
    this.officialType,
    this.jurisdictionType,
    this.jurisdictionId,
    this.jurisdictionName,
    this.designation,
    this.officialEmail,
    this.approvedAt,
    this.preferredLanguage = 'en',
    this.signInMethod,
    this.signupCompletedAt,
  });

  static SignInMethod? _signInMethodFromString(String? value) {
    switch (value) {
      case 'password':
        return SignInMethod.password;
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
      username: map['username'] as String?,
      age: map['age'] as int?,
      pincodeHome: map['pincodeHome'] as String?,
      addressHome: map['addressHome'] as String?,
      wardNumber: map['wardNumber'] as String?,
      lat: (map['location']?['lat'] as num?)?.toDouble(),
      lng: (map['location']?['lng'] as num?)?.toDouble(),
      role: switch (map['role']) {
        'official' => UserRole.official,
        'admin' => UserRole.admin,
        _ => UserRole.citizen,
      },
      constituencyId: map['constituencyId'] as String?,
      constituencyName: map['constituencyName'] as String?,
      homeBoothId: map['homeBoothId'] as String?,
      homeBoothName: map['homeBoothName'] as String?,
      districtId: map['districtId'] as String?,
      districtName: map['districtName'] as String?,
      talukId: map['talukId'] as String?,
      talukName: map['talukName'] as String?,
      homeWardId: map['homeWardId'] as String?,
      homeWardName: map['homeWardName'] as String?,
      homeBbmpWardId: map['homeBbmpWardId'] as String?,
      homeBbmpWardName: map['homeBbmpWardName'] as String?,
      photoPath: map['photoPath'] as String?,
      hasSecurityQuestion: map['hasSecurityQuestion'] == true,
      officialType: map['officialType'] as String?,
      jurisdictionType: map['jurisdiction']?['type'] as String?,
      jurisdictionId: map['jurisdiction']?['id'] as String?,
      jurisdictionName: map['jurisdiction']?['name'] as String?,
      designation: map['designation'] as String?,
      officialEmail: map['officialEmail'] as String?,
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      preferredLanguage: map['preferredLanguage'] as String? ?? 'en',
      signInMethod: _signInMethodFromString(map['signInMethod'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      signupCompletedAt:
          (map['signupCompletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (age != null) 'age': age,
      if (pincodeHome != null) 'pincodeHome': pincodeHome,
      if (addressHome != null) 'addressHome': addressHome,
      if (wardNumber != null) 'wardNumber': wardNumber,
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
      'role': role.name,
      if (designation != null) 'designation': designation,
      if (constituencyId != null) 'constituencyId': constituencyId,
      if (constituencyName != null) 'constituencyName': constituencyName,
      if (homeBoothId != null) 'homeBoothId': homeBoothId,
      if (homeBoothName != null) 'homeBoothName': homeBoothName,
      if (districtId != null) 'districtId': districtId,
      if (districtName != null) 'districtName': districtName,
      if (talukId != null) 'talukId': talukId,
      if (talukName != null) 'talukName': talukName,
      if (homeWardId != null) 'homeWardId': homeWardId,
      if (homeWardName != null) 'homeWardName': homeWardName,
      if (homeBbmpWardId != null) 'homeBbmpWardId': homeBbmpWardId,
      if (homeBbmpWardName != null) 'homeBbmpWardName': homeBbmpWardName,
      if (photoPath != null) 'photoPath': photoPath,
      'preferredLanguage': preferredLanguage,
      if (signInMethod != null) 'signInMethod': signInMethod!.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (signupCompletedAt != null)
        'signupCompletedAt': Timestamp.fromDate(signupCompletedAt!),
    };
  }

  UserModel copyWith({
    String? name,
    String? username,
    int? age,
    String? pincodeHome,
    String? addressHome,
    String? wardNumber,
    double? lat,
    double? lng,
    String? constituencyId,
    String? constituencyName,
    String? homeBoothId,
    String? homeBoothName,
    String? districtId,
    String? districtName,
    String? talukId,
    String? talukName,
    String? homeWardId,
    String? homeWardName,
    String? homeBbmpWardId,
    String? homeBbmpWardName,
    String? photoPath,
    String? designation,
    String? preferredLanguage,
    SignInMethod? signInMethod,
    DateTime? signupCompletedAt,
  }) {
    return UserModel(
      uid: uid,
      role: role,
      createdAt: createdAt,
      name: name ?? this.name,
      username: username ?? this.username,
      age: age ?? this.age,
      pincodeHome: pincodeHome ?? this.pincodeHome,
      addressHome: addressHome ?? this.addressHome,
      wardNumber: wardNumber ?? this.wardNumber,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      constituencyId: constituencyId ?? this.constituencyId,
      constituencyName: constituencyName ?? this.constituencyName,
      homeBoothId: homeBoothId ?? this.homeBoothId,
      homeBoothName: homeBoothName ?? this.homeBoothName,
      districtId: districtId ?? this.districtId,
      districtName: districtName ?? this.districtName,
      talukId: talukId ?? this.talukId,
      talukName: talukName ?? this.talukName,
      homeWardId: homeWardId ?? this.homeWardId,
      homeWardName: homeWardName ?? this.homeWardName,
      homeBbmpWardId: homeBbmpWardId ?? this.homeBbmpWardId,
      homeBbmpWardName: homeBbmpWardName ?? this.homeBbmpWardName,
      photoPath: photoPath ?? this.photoPath,
      hasSecurityQuestion: hasSecurityQuestion,
      officialType: officialType,
      jurisdictionType: jurisdictionType,
      jurisdictionId: jurisdictionId,
      jurisdictionName: jurisdictionName,
      designation: designation ?? this.designation,
      officialEmail: officialEmail,
      approvedAt: approvedAt,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      signInMethod: signInMethod ?? this.signInMethod,
      signupCompletedAt: signupCompletedAt ?? this.signupCompletedAt,
    );
  }
}
