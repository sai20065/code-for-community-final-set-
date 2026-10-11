import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/core/models/user_model.dart';
import 'package:praja_dhvani/core/services/profile_completeness.dart';

void main() {
  final base = UserModel(
    uid: 'u1',
    role: UserRole.citizen,
    createdAt: DateTime(2026, 10, 11),
    name: 'Ravi',
    username: 'ravi',
  );

  test('a brand-new profile lists everything still missing', () {
    final c = profileCompleteness(base);
    expect(c.missing, [
      ProfileItem.homeLocation,
      ProfileItem.securityQuestion,
      ProfileItem.age,
      ProfileItem.photo,
    ]);
    expect(c.percent, 33); // name + username of 6
  });

  test('a fully filled profile is complete', () {
    final full = UserModel(
      uid: 'u1',
      role: UserRole.citizen,
      createdAt: DateTime(2026, 10, 11),
      name: 'Ravi',
      username: 'ravi',
      age: 30,
      lat: 13.0,
      lng: 77.5,
      constituencyId: '2927',
      photoPath: 'avatars/u1/avatar.jpg',
      hasSecurityQuestion: true,
    );
    final c = profileCompleteness(full);
    expect(c.isComplete, isTrue);
    expect(c.percent, 100);
  });

  test('copyWith keeps the security-question flag', () {
    final withFlag = UserModel(
      uid: 'u1',
      role: UserRole.citizen,
      createdAt: DateTime(2026, 10, 11),
      hasSecurityQuestion: true,
    );
    expect(withFlag.copyWith(age: 30).hasSecurityQuestion, isTrue);
  });
}
