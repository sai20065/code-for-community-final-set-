import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/app/providers/public_data_providers.dart';
import 'package:praja_dhvani/core/models/public_models.dart';
import 'package:praja_dhvani/core/models/representative_models.dart';
import 'package:praja_dhvani/features/public/leaderboard/representative_leaderboard_screen.dart';
import 'package:praja_dhvani/features/public/report/public_report_card_screen.dart';
import 'package:praja_dhvani/l10n/app_localizations.dart';
import 'package:praja_dhvani/l10n/app_localizations_en.dart';
import 'package:praja_dhvani/shared/widgets/share_actions.dart';

Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

PublicTicketModel _ticket({String status = 'new', String? resolved, String? assemblyId = 'KA-AC-150'}) =>
    PublicTicketModel.fromMap('sub1', {
      'tokenId': 'PD-KA-PRB-261020-0001',
      'theme': 'roads',
      'status': status,
      'publicSummary': 'Deep potholes on the main road',
      'constituencyId': 'blr-north',
      'wardId': 'w1',
      'assemblyId': assemblyId,
      'createdDate': '2026-10-15',
      'resolvedDate': resolved,
      'supporterCount': 3,
      'suggestedOfficeName': 'Greater Bengaluru Authority (BBMP)',
      'suggestedOfficeUrl': 'https://bbmp.gov.in/',
    });

final _reps = PublicReps.fromMap({
  'rosterAsOf': '2026-10-25',
  'mla': {
    'KA-AC-150': {'seat': 'Yelahanka', 'name': 'S. R. Vishwanath', 'vacant': false},
    'KA-AC-100': {'seat': 'Hiriyur', 'name': null, 'vacant': true},
  },
  'mp': {
    'blr-north': {'seat': 'Bangalore North', 'name': 'Shobha Karandlaje'},
  },
  'wardNames': {'w1': 'Yelahanka New Town'},
});

void main() {
  final l10n = AppLocalizationsEn();

  group('report card data', () {
    test('days open counts to today, days to fix stops at the fix', () {
      expect(_ticket().daysOpen(DateTime(2026, 10, 25)), 10);
      expect(_ticket(status: 'resolved', resolved: '2026-10-18').daysOpen(DateTime(2026, 10, 25)), 3);
    });

    test('place prefers the ward name', () {
      expect(placeLabel(_ticket(), _reps, null), 'Yelahanka New Town');
    });

    test('the post names both representatives and links to the card', () {
      final post = reportSharePost(l10n, _ticket(), _reps, 'Yelahanka New Town');
      expect(post.text, contains('Deep potholes on the main road'));
      expect(post.text, contains('MLA: S. R. Vishwanath'));
      expect(post.text, contains('MP: Shobha Karandlaje'));
      expect(post.text, contains('#Prajadhwani'));
      expect(post.url, 'https://code-for-community-e2cf2.web.app/#/public/report/sub1');
    });

    test('social links are encoded and carry the card link', () {
      final post = reportSharePost(l10n, _ticket(), _reps, 'Yelahanka');
      for (final uri in [post.xUri, post.whatsAppUri, post.facebookUri]) {
        expect(uri.toString(), isNot(contains(' ')));
        expect(uri.toString(), isNot(contains('+')));
        expect(Uri.decodeFull(uri.toString()), contains('/public/report/sub1'));
      }
      expect(post.xUri.host, 'x.com');
      expect(post.whatsAppUri.host, 'wa.me');
      expect(post.facebookUri.host, 'www.facebook.com');
    });

    test('vacant and unknown seats are said plainly, not guessed', () {
      final vacant = reportSharePost(l10n, _ticket(assemblyId: 'KA-AC-100'), _reps, 'Hiriyur');
      expect(vacant.text, contains('MLA: Seat vacant'));
      final unknown = reportSharePost(l10n, _ticket(assemblyId: null), _reps, 'x');
      expect(unknown.text, contains('MLA: Not yet recorded'));
    });
  });

  testWidgets('the card shows MLA, MP and days open, and no photo', (tester) async {
    await tester.pumpWidget(_app(PublicReportCard(ticket: _ticket(), reps: _reps, place: 'Yelahanka New Town')));
    expect(find.text('S. R. Vishwanath'), findsNothing); // inside a Text.rich
    expect(find.textContaining('S. R. Vishwanath', findRichText: true), findsOneWidget);
    expect(find.textContaining('Shobha Karandlaje', findRichText: true), findsOneWidget);
    expect(find.textContaining('Open ', findRichText: true), findsOneWidget);
    expect(find.text('4 people reported this'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('Post on social media offers X, WhatsApp, Facebook and copy', (tester) async {
    await tester.pumpWidget(_app(ShareActions(
      post: reportSharePost(l10n, _ticket(), _reps, 'Yelahanka'),
    )));
    await tester.tap(find.text('Post on social media'));
    await tester.pumpAndSettle();
    for (final label in ['Post on X', 'Send on WhatsApp', 'Share on Facebook', 'Copy post text']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('leaderboard lists ranked seats first, then the rest', (tester) async {
    final board = RepresentativeLeaderboard.fromMap({
      'windowDays': 90,
      'minReports': 5,
      'rows': [
        {'repId': 'KA-AC-180', 'name': 'Dheeraj Muniraj', 'seat': 'Doddaballapur', 'reports': 6, 'open': 5, 'fixed': 1, 'fixedPct': 16.7, 'rank': 1},
        {'repId': 'KA-AC-150', 'name': 'S. R. Vishwanath', 'seat': 'Yelahanka', 'reports': 2, 'open': 2, 'fixed': 0, 'fixedPct': 0, 'rank': null},
      ],
    });
    await tester.pumpWidget(_app(
      const LeaderboardList(board: 'mla'),
      overrides: [leaderboardProvider.overrideWith((ref, b) => Stream.value(board))],
    ));
    await tester.pump();
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Dheeraj Muniraj'), findsOneWidget);
    expect(find.text('NOT ENOUGH REPORTS YET'), findsOneWidget);
    expect(find.text('S. R. Vishwanath'), findsOneWidget);
    expect(find.textContaining('Party is not shown'), findsOneWidget);
    final first = tester.getTopLeft(find.text('Dheeraj Muniraj')).dy;
    final second = tester.getTopLeft(find.text('S. R. Vishwanath')).dy;
    expect(first, lessThan(second));
  });

  test('leaderboard post states the share fixed, not a verdict', () {
    final row = LeaderboardRow.fromMap({
      'repId': 'KA-AC-180', 'name': 'Dheeraj Muniraj', 'seat': 'Doddaballapur',
      'reports': 6, 'open': 5, 'fixed': 1, 'fixedPct': 16.7, 'rank': 1,
    });
    final post = leaderboardSharePost(l10n, row, 90);
    expect(post.text,
        'Dheeraj Muniraj (Doddaballapur): 16.7% of 6 reported problems fixed in the last 90 days, 5 still open. #Prajadhwani');
    expect(post.url, endsWith('/#/public/leaderboard'));
  });
}
