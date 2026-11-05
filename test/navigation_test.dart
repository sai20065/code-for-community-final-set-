import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:praja_dhvani/app/navigation.dart';
import 'package:praja_dhvani/core/models/user_model.dart';

UserModel _user(UserRole role, {String? officialType}) => UserModel(
      uid: 'u1',
      role: role,
      createdAt: DateTime(2026, 11, 1),
      officialType: officialType,
    );

void main() {
  group('homeRouteFor', () {
    test('citizens and signed-out visitors keep the citizen home', () {
      expect(homeRouteFor(_user(UserRole.citizen)), '/home');
      expect(homeRouteFor(null), '/home');
    });

    test('officials go to their dashboard, never the citizen home', () {
      for (final type in ['mp', 'mla', 'wardOfficer', 'tahsildar', 'districtOfficer', null]) {
        expect(homeRouteFor(_user(UserRole.official, officialType: type)), '/gov/dashboard');
      }
    });

    test('field workers go to their task list', () {
      expect(homeRouteFor(_user(UserRole.official, officialType: 'fieldWorker')), '/worker/tasks');
    });

    test('admins go to the admin console', () {
      expect(homeRouteFor(_user(UserRole.admin)), '/admin');
    });
  });

  testWidgets('drill-downs stack on the dashboard, so back always returns to it', (t) async {
    final router = GoRouter(initialLocation: '/gov/dashboard', routes: [
      GoRoute(path: '/gov/dashboard', builder: (_, __) => const Text('DASHBOARD')),
      GoRoute(path: '/public/area', builder: (_, __) => const Text('AREA')),
      GoRoute(path: '/public/map', builder: (_, __) => const Text('MAP')),
    ]);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/public/area');
    await t.pumpAndSettle();
    expect(find.text('AREA'), findsOneWidget);
    // Picking an area replaces the picker with the map, keeping the dashboard below.
    router.replace('/public/map');
    await t.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await t.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);
  });
}
