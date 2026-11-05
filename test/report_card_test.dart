import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/app/providers/auth_state_provider.dart';
import 'package:praja_dhvani/app/providers/current_user_profile_provider.dart';
import 'package:praja_dhvani/app/providers/feed_providers.dart';
import 'package:praja_dhvani/app/providers/public_data_providers.dart';
import 'package:praja_dhvani/core/models/feed_comment_model.dart';
import 'package:praja_dhvani/core/models/public_models.dart';
import 'package:praja_dhvani/core/models/representative_models.dart';
import 'package:praja_dhvani/features/public/leaderboard/representative_leaderboard_screen.dart';
import 'package:praja_dhvani/features/public/report/public_report_card_screen.dart';
import 'package:praja_dhvani/shared/widgets/report_post_text.dart';
import 'package:praja_dhvani/l10n/app_localizations.dart';
import 'package:praja_dhvani/core/services/feed_service.dart';
import 'package:praja_dhvani/l10n/app_localizations_en.dart';
import 'package:praja_dhvani/shared/widgets/comments_sheet.dart';
import 'package:praja_dhvani/shared/widgets/feed_post_card.dart';
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

  final feedOverrides = <Override>[
    mySupportsProvider.overrideWith((ref) => Stream.value(const <String>{})),
    feedCommentsProvider.overrideWith((ref, id) => Stream.value(const <FeedComment>[])),
    authStateProvider.overrideWith((ref) => Stream.value(null)),
    currentUserProfileProvider.overrideWith((ref) => Stream.value(null)),
  ];

  testWidgets('the card names the MLA and MP, without calling them responsible', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      ReportCardBody(ticket: _ticket(), reps: _reps, place: 'Yelahanka New Town', showNearby: false),
      overrides: feedOverrides,
    ));
    await tester.pump();
    expect(find.textContaining('S. R. Vishwanath', findRichText: true), findsWidgets);
    expect(find.textContaining('Shobha Karandlaje', findRichText: true), findsWidgets);
    expect(find.textContaining(RegExp('responsib', caseSensitive: false), findRichText: true), findsNothing);
    expect(find.textContaining(RegExp(r'^Open \d+ days$'), findRichText: true), findsOneWidget);
    expect(find.text('3 people said Me too'), findsOneWidget);
    expect(find.text('Greater Bengaluru Authority (BBMP)'), findsOneWidget);
    // No public photo on this ticket: a themed cover, never an image.
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('a post with a published photo shows it', (tester) async {
    final withPhoto = PublicTicketModel.fromMap('p1', {
      'tokenId': 'PD-1', 'theme': 'water', 'status': 'new', 'publicSummary': 'Pipe burst',
      'createdDate': '2026-10-20',
      'photoUrl': 'https://firebasestorage.googleapis.com/v0/b/x/o/public%2Ffeed%2Fp1.jpg?alt=media',
      'photoWidth': 1080, 'photoHeight': 810,
    });
    await tester.pumpWidget(_app(
      SingleChildScrollView(child: FeedPostCard(ticket: withPhoto, reps: _reps, place: 'Hebbal')),
      overrides: feedOverrides,
    ));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('Me too'), findsNothing); // icon button with tooltip
    expect(find.byTooltip('Me too'), findsOneWidget);
    expect(find.text('Open card'), findsOneWidget);
  });

  testWidgets('signed-out visitors can read comments but are asked to sign in', (tester) async {
    await tester.pumpWidget(_app(
      const CommentsSheet(ticketId: 'sub1'),
      overrides: feedOverrides,
    ));
    await tester.pump();
    expect(find.text('No comments yet — start the conversation'), findsOneWidget);
    expect(find.text('Sign in to comment'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  test('the feed appends pages and stops at the end', () async {
    final fake = _FakeFeed();
    final notifier = FeedNotifier(fake, const FeedFilter());
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.posts.length, 15);
    await notifier.loadMore();
    expect(notifier.state.posts.length, 20);
    expect(notifier.state.hasMore, isFalse);
    await notifier.loadMore();
    expect(fake.calls, 2);
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

/// Two pages: 15 posts, then 5 and the end.
class _FakeFeed implements FeedService {
  int calls = 0;

  @override
  Future<FeedPage> page({
    String? districtId,
    bool withPhotos = false,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = FeedService.pageSize,
  }) async {
    calls++;
    final n = calls == 1 ? 15 : 5;
    final posts = List.generate(n, (i) => PublicTicketModel.fromMap('t$calls-$i', {
          'tokenId': 'PD-$i', 'status': 'new', 'publicSummary': 's', 'createdDate': '2026-10-20',
        }));
    return FeedPage(posts, null, hasMore: n == limit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
