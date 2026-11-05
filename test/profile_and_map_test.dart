import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/app/theme.dart';
import 'package:praja_dhvani/core/models/public_models.dart';
import 'package:praja_dhvani/core/models/user_model.dart';
import 'package:praja_dhvani/features/public/map/karnataka_map_screen.dart';

UserModel citizen({
  int? age,
  String? pincode,
  double? lat,
  double? lng,
  String? constituencyId,
  String? constituencyName,
  String? bbmpWard,
  DateTime? completedAt,
}) =>
    UserModel(
      uid: 'u',
      role: UserRole.citizen,
      createdAt: DateTime(2026, 10, 22),
      age: age,
      pincodeHome: pincode,
      lat: lat,
      lng: lng,
      constituencyId: constituencyId,
      constituencyName: constituencyName,
      homeBbmpWardName: bbmpWard,
      signupCompletedAt: completedAt,
    );

void main() {
  group('isProfileComplete', () {
    test('an account created but never onboarded is incomplete, even if the '
        'old flow stamped signupCompletedAt', () {
      final p = citizen(completedAt: DateTime(2026, 10, 22));
      expect(p.isProfileComplete, isFalse);
      expect(p.resumeOnboardingRoute, '/signup/basic-info');
    });

    test('age saved but no location resumes at the location step', () {
      expect(citizen(age: 29).resumeOnboardingRoute, '/signup/location');
    });

    test('a saved home location completes the profile', () {
      final p = citizen(age: 29, pincode: '560001', lat: 12.97, lng: 77.6);
      expect(p.isProfileComplete, isTrue);
    });
  });

  group('homeAreaLabel', () {
    test('prefers ward and constituency names over the raw id', () {
      final p = citizen(
          constituencyId: '2925',
          constituencyName: 'Bangalore Central',
          bbmpWard: 'Sampangiram Nagar');
      expect(p.homeAreaLabel, 'Sampangiram Nagar · Bangalore Central');
    });

    test('falls back to the raw id only when nothing better exists', () {
      expect(citizen(constituencyId: '2925').homeAreaLabel, '2925');
      expect(citizen().homeAreaLabel, isNull);
    });
  });

  group('live map indicators', () {
    test('cluster colour follows the share of unresolved reports', () {
      expect(openShareColor(9, 10), AppColors.vermilion);
      expect(openShareColor(5, 10), AppColors.saffronDeep);
      expect(openShareColor(1, 10), AppColors.teal);
    });

    test('tickets parse district and coarse precision for the map', () {
      final t = PublicTicketModel.fromMap('t', {
        'tokenId': 'PD-1',
        'status': 'resolved',
        'districtId': '20',
        'geo': {'lat': 12.9, 'lng': 77.6},
        'geoPrecision': 'taluk',
      });
      expect(t.districtId, '20');
      expect(t.isOpen, isFalse);
      expect(t.geoPrecision, 'taluk');
      expect(t.constituencyId, '');
    });
  });
}
