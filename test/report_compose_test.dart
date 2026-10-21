import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/core/models/submission_model.dart';
import 'package:praja_dhvani/core/services/auth_service.dart';
import 'package:praja_dhvani/core/services/firestore_service.dart';
import 'package:praja_dhvani/core/services/location_service.dart';
import 'package:praja_dhvani/core/services/storage_service.dart';
import 'package:praja_dhvani/core/services/transcription_service.dart';
import 'package:praja_dhvani/features/citizen/compose/report_compose_screen.dart';
import 'package:praja_dhvani/l10n/app_localizations.dart';
import 'package:praja_dhvani/shared/widgets/officer_mascot_3d.dart';

/// Signed-out stand-ins: the screen never reaches Firebase without a uid.
class _FakeAuth implements AuthService {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirestoreService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStorage implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTranscription implements TranscriptionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocation implements LocationService {
  @override
  Future<(double, double)?> getCurrentLatLng() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: w!,
      ),
      home: child,
    );

ReportComposeScreen _screen([SubmissionCategory? category]) => ReportComposeScreen(
      initialCategory: category,
      authService: _FakeAuth(),
      firestoreService: _FakeFirestore(),
      storageService: _FakeStorage(),
      transcriptionService: _FakeTranscription(),
      locationService: _FakeLocation(),
    );

/// Tall enough that every card is built (the list is lazy).
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

ElevatedButton _submitButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

void main() {
  group('ReportComposeScreen', () {
    testWidgets('text, voice and photo inputs share one screen', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(_screen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("What's the issue?"), findsOneWidget);
      expect(find.text('Tap the mic to speak instead of typing'), findsOneWidget);
      expect(find.text('Add a photo (optional)'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
    });

    testWidgets('submit enables once there is text, and the Text chip lights up',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(_screen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(_submitButton(tester).onPressed, isNull);
      expect(find.text('Type, speak or add a photo to submit'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'Big pothole near the bus stand');
      await tester.pump(const Duration(milliseconds: 300));

      expect(_submitButton(tester).onPressed, isNotNull);
      expect(find.text('Type, speak or add a photo to submit'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      // The on-device heuristic offers a category to confirm.
      expect(find.textContaining('Roads'), findsWidgets);
    });

    testWidgets('the header toggle switches between report and suggestion',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(_screen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Report a problem'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.lightbulb_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Share Your Suggestion'), findsOneWidget);
      expect(find.text("What's your idea?"), findsOneWidget);
    });
  });

  group('OfficerMascot3D', () {
    testWidgets('plays the intro and shows the promise with the ticket id',
        (tester) async {
      await tester.pumpWidget(_app(const Center(
        child: OfficerMascot3D(
          message: 'Your problem is registered!',
          ticketLabel: 'Your ticket: PD-TEST-0001',
        ),
      )));
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Your problem is registered!'), findsOneWidget);
      expect(find.text('Your ticket: PD-TEST-0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion jumps to the final frame', (tester) async {
      await tester.pumpWidget(_app(
        const Center(child: OfficerMascot3D(message: 'Done')),
        reduceMotion: true,
      ));
      await tester.pumpAndSettle();
      final opacity = tester.widget<Opacity>(
          find.ancestor(of: find.text('Done'), matching: find.byType(Opacity)).first);
      expect(opacity.opacity, 1.0);
    });
  });
}
