import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/core/models/official_scope.dart';
import 'package:praja_dhvani/core/models/public_models.dart';
import 'package:praja_dhvani/core/models/user_model.dart';
import 'package:praja_dhvani/core/services/official_stats.dart';

UserModel official({
  String? type,
  String? jType,
  String? jId,
  String? jName,
  String? constituencyId,
}) =>
    UserModel(
      uid: 'u',
      role: UserRole.official,
      createdAt: DateTime(2026, 1, 1),
      officialType: type,
      jurisdictionType: jType,
      jurisdictionId: jId,
      jurisdictionName: jName,
      constituencyId: constituencyId,
    );

PublicTicketModel ticket(String status, String created, [String? resolved]) =>
    PublicTicketModel.fromMap('t', {
      'tokenId': 'PD-1',
      'status': status,
      'createdDate': created,
      'resolvedDate': resolved,
      'constituencyId': '2927',
      'submissionCategory': 'problem',
      'publicSummary': '',
    });

void main() {
  group('OfficialScope.fromUser', () {
    test('legacy MP (no officialType) scopes to constituencyId', () {
      final s = OfficialScope.fromUser(official(constituencyId: '2927'))!;
      expect(s.type, OfficialType.mp);
      expect(s.field, 'constituencyId');
      expect(s.id, '2927');
      expect(s.key, '2927'); // shares the public dashboard cache
    });

    test('each officer type maps to its ticket field', () {
      final cases = {
        ('mla', 'assembly', 'KA-AC-150'): 'assemblyId',
        ('wardOfficer', 'bbmpWard', 'BBMP-151'): 'bbmpWardId',
        ('tahsildar', 'taluk', '2102'): 'talukId',
        ('districtOfficer', 'district', '21'): 'districtId',
      };
      cases.forEach((k, field) {
        final s = OfficialScope.fromUser(
            official(type: k.$1, jType: k.$2, jId: k.$3, jName: 'X'))!;
        expect(s.field, field);
        expect(s.key, '$field:${k.$3}');
      });
    });

    test('an official with no area has no scope', () {
      expect(OfficialScope.fromUser(official(type: 'mla')), isNull);
    });
  });

  group('performance', () {
    final today = DateTime(2026, 10, 12);

    test('rates, durations and backlog', () {
      final p = computePerformance([
        ticket('resolved', '2026-10-01', '2026-10-03'), // 2 days
        ticket('resolved', '2026-10-05', '2026-10-09'), // 4 days
        ticket('new', '2026-09-01'), // overdue
        ticket('inProgress', '2026-10-10'),
      ], today: today);
      expect(p.total, 4);
      expect(p.resolved, 2);
      expect(p.resolutionRate, 50);
      expect(p.avgDaysToResolve, 3);
      expect(p.resolvedThisWeek, 1);
      expect(p.overdueOpen, 1);
      expect(p.weeklyResolved.last, 1);
    });

    test('badges unlock by resolved count', () {
      final p = computePerformance(
        [for (var i = 0; i < 10; i++) ticket('resolved', '2026-10-01', '2026-10-02')],
        today: today,
      );
      final earned = {for (final b in officialBadges(p)) b.$1: b.$2};
      expect(earned[OfficialBadge.firstResolution], isTrue);
      expect(earned[OfficialBadge.resolved10], isTrue);
      expect(earned[OfficialBadge.resolved50], isFalse);
      expect(earned[OfficialBadge.quickResponder], isTrue);
      expect(earned[OfficialBadge.zeroBacklog], isTrue);
    });
  });
}
