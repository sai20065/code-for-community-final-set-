import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/core/models/submission_model.dart';
import 'package:praja_dhvani/features/citizen/confirmation/submission_confirmation_screen.dart';
import 'package:praja_dhvani/l10n/app_localizations.dart';
import 'package:praja_dhvani/shared/widgets/suggested_office_card.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: w!,
      ),
      home: child,
    );

const _bwssb = {
  'departmentId': 'KA-BWSSB',
  'name': 'Bangalore Water Supply and Sewerage Board',
  'shortName': 'BWSSB',
  'officerDesignation': 'Assistant Executive Engineer, service station',
  'email': 'callcenter@bwssb.gov.in',
  'websiteUrl': 'https://bwssb.karnataka.gov.in/',
  'phone': null,
  'matchQuality': 'exact',
  'source': 'gemma',
};

SubmissionModel _ticket([Map<String, dynamic>? office]) => SubmissionModel.fromMap('s1', {
      'userId': 'u',
      'type': 'text',
      'rawText': 'No water for four days',
      'tokenId': 'PD-KA-PRB-261025-0001',
      'location': {'pincode': '560001', 'lat': 12.97, 'lng': 77.59},
      if (office != null) 'suggestedOffice': office,
    });

void main() {
  group('SuggestedOffice', () {
    test('parses the backend shape', () {
      final o = _ticket(_bwssb).suggestedOffice!;
      expect(o.shortName, 'BWSSB');
      expect(o.email, 'callcenter@bwssb.gov.in');
      expect(o.source, 'gemma');
    });

    test('absent or nameless means not yet suggested', () {
      expect(_ticket().suggestedOffice, isNull);
      expect(_ticket({'departmentId': 'X', 'name': ''}).suggestedOffice, isNull);
    });

    test('the pre-filled email carries the ticket id, words and map link', () {
      final uri = SuggestedOfficeCard.mailtoFor(
        _ticket(_bwssb).suggestedOffice!,
        tokenId: 'PD-1',
        reportText: 'No water',
        lat: 12.97,
        lng: 77.59,
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'callcenter@bwssb.gov.in');
      final body = Uri.decodeComponent(uri.query);
      expect(body, contains('ticket PD-1'));
      expect(body, contains('No water'));
      expect(body, contains('maps.google.com/?q=12.97,77.59'));
      expect(uri.query, isNot(contains('+')));
    });
  });

  group('SuggestedOfficeCard', () {
    testWidgets('shows the website and hides email when there is none', (tester) async {
      final office = SuggestedOffice.fromMap({..._bwssb, 'email': null})!;
      await tester.pumpWidget(_app(Scaffold(
        body: SuggestedOfficeCard(office: office, tokenId: 'PD-1'),
      )));
      expect(find.text('Suggested office to file the problem'), findsOneWidget);
      expect(find.text('Official website'), findsOneWidget);
      expect(find.text('Email the office'), findsNothing);
    });

    testWidgets('compact card renders nothing until an office exists', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
        body: SuggestedOfficeCard(office: null, tokenId: 'PD-1', compact: true),
      )));
      expect(find.byType(Text), findsNothing);
    });
  });

  testWidgets('confirmation screen fills the office in once the backend writes it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final updates = StreamController<SubmissionModel?>();
    addTearDown(updates.close);

    await tester.pumpWidget(_app(
      SubmissionConfirmationScreen(submission: _ticket(), updates: updates.stream),
    ));
    await tester.pump();
    expect(find.text('Finding the right office for your problem…'), findsOneWidget);

    updates.add(_ticket(_bwssb));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bangalore Water Supply and Sewerage Board'), findsOneWidget);
    expect(find.text('Email the office'), findsOneWidget);
    expect(find.text('Finding the right office for your problem…'), findsNothing);
  });
}
