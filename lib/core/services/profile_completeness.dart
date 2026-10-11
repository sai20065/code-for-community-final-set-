import '../models/user_model.dart';

/// One thing a citizen can still add to their profile.
enum ProfileItem { photo, age, homeLocation, securityQuestion }

class ProfileCompleteness {
  const ProfileCompleteness({required this.missing, required this.total});

  /// What's still missing, in the order the profile asks for it.
  final List<ProfileItem> missing;
  final int total;

  int get done => total - missing.length;
  double get fraction => total == 0 ? 1 : done / total;
  int get percent => (fraction * 100).round();
  bool get isComplete => missing.isEmpty;
}

/// How complete a citizen's profile is. Name and username always exist
/// after Sign Up, so they count as done; the rest are what Profile nudges
/// for — each one either makes routing work (home location), protects the
/// account (security question) or makes the profile feel like theirs.
ProfileCompleteness profileCompleteness(UserModel user) {
  final missing = <ProfileItem>[
    if (user.lat == null || user.lng == null || user.constituencyId == null)
      ProfileItem.homeLocation,
    if (!user.hasSecurityQuestion) ProfileItem.securityQuestion,
    if (user.age == null) ProfileItem.age,
    if (user.photoPath == null) ProfileItem.photo,
  ];
  // name + username + the four items above
  return ProfileCompleteness(missing: missing, total: 6);
}
