import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/core/models/submission_model.dart';
import 'package:praja_dhvani/core/services/work_service.dart';
import 'package:praja_dhvani/features/citizen/reports/fix_confirmation_card.dart';
import 'package:praja_dhvani/l10n/app_localizations.dart';

class _FakeWork extends WorkService {
  _FakeWork() : super(functions: null);
  final answers = <bool>[];

  @override
  Future<void> citizenRespond(String ticketId,
      {required bool fixed, String? note}) async {
    answers.add(fixed);
  }
}

SubmissionModel _sub({
  required SubmissionStatus status,
  DateTime? fixedAt,
  String? response,
  String? worker,
  SubmissionCategory category = SubmissionCategory.problem,
}) =>
    SubmissionModel(
      id: 's1',
      userId: 'u1',
      type: SubmissionType.text,
      inputMode: 'text',
      language: 'en',
      location: const SubmissionLocation(pincode: '560001'),
      status: status,
      tokenId: 'T-1',
      createdAt: DateTime(2026, 11, 1),
      category: category,
      fixedAt: fixedAt,
      citizenResponseKind: response,
      assignedToName: worker,
    );

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  group('answerWindowLeft', () {
    final fixed = DateTime(2026, 11, 1, 10);
    test('counts down from 48 hours', () {
      expect(answerWindowLeft(fixed, fixed.add(const Duration(hours: 10))),
          const Duration(hours: 38));
    });
    test('is zero at and after 48 hours', () {
      expect(answerWindowLeft(fixed, fixed.add(const Duration(hours: 48))),
          Duration.zero);
      expect(answerWindowLeft(fixed, fixed.add(const Duration(hours: 70))),
          Duration.zero);
    });
  });

  group('status', () {
    test('closed round-trips through the wire name', () {
      expect(SubmissionModel.statusFromString('closed'), SubmissionStatus.closed);
      expect(SubmissionModel.statusToString(SubmissionStatus.closed), 'closed');
    });
  });

  group('FixConfirmationCard', () {
    testWidgets('asks the citizen inside the window and sends yes', (t) async {
      final fake = _FakeWork();
      var changed = 0;
      await t.pumpWidget(_wrap(FixConfirmationCard(
        submission: _sub(
          status: SubmissionStatus.resolved,
          fixedAt: DateTime.now().subtract(const Duration(hours: 5)),
          worker: 'Ravi',
        ),
        onChanged: () => changed++,
        service: fake,
      )));
      expect(find.text('Was this fixed?'), findsOneWidget);
      expect(find.textContaining('left to answer'), findsOneWidget);
      expect(find.text('Assigned to Ravi'), findsOneWidget);
      await t.tap(find.text("Yes, it's fixed"));
      await t.pump();
      expect(fake.answers, [true]);
      expect(changed, 1);
      expect(find.text('Thank you. This report is now closed.'), findsOneWidget);
    });

    testWidgets('no sends not-fixed', (t) async {
      final fake = _FakeWork();
      await t.pumpWidget(_wrap(FixConfirmationCard(
        submission: _sub(
          status: SubmissionStatus.resolved,
          fixedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        onChanged: () {},
        service: fake,
      )));
      await t.tap(find.text('No, still broken'));
      await t.pump();
      expect(fake.answers, [false]);
    });

    testWidgets('after 48 hours there are no buttons, only a waiting line',
        (t) async {
      await t.pumpWidget(_wrap(FixConfirmationCard(
        submission: _sub(
          status: SubmissionStatus.resolved,
          fixedAt: DateTime.now().subtract(const Duration(hours: 50)),
        ),
        onChanged: () {},
      )));
      expect(find.text('Waiting to be closed'), findsOneWidget);
      expect(find.text("Yes, it's fixed"), findsNothing);
    });

    testWidgets('closed by the system reads as such', (t) async {
      await t.pumpWidget(_wrap(FixConfirmationCard(
        submission: _sub(
          status: SubmissionStatus.closed,
          fixedAt: DateTime.now().subtract(const Duration(hours: 60)),
        ),
        onChanged: () {},
      )));
      expect(find.text('Closed after 48 hours without an answer'), findsOneWidget);
    });

    testWidgets('shows nothing for a suggestion or an open report', (t) async {
      await t.pumpWidget(_wrap(FixConfirmationCard(
        submission: _sub(
            status: SubmissionStatus.resolved,
            category: SubmissionCategory.feedback,
            fixedAt: DateTime.now()),
        onChanged: () {},
      )));
      expect(find.byType(Container), findsNothing);
      await t.pumpWidget(_wrap(FixConfirmationCard(
        submission: _sub(status: SubmissionStatus.inProgress),
        onChanged: () {},
      )));
      expect(find.text('Was this fixed?'), findsNothing);
    });
  });
}
