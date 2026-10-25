import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/feed_comment_model.dart';
import '../../core/models/public_models.dart';
import '../../core/services/feed_service.dart';
import '../../core/services/karnataka_geo_service.dart';
import 'auth_state_provider.dart';
import 'current_user_profile_provider.dart';

final feedServiceProvider = Provider<FeedService>((ref) => FeedService());

/// Bundled district/taluk names, decoded once per run.
final karnatakaGeoProvider = FutureProvider<KarnatakaGeo>((ref) {
  ref.keepAlive();
  return KarnatakaGeoService.instance.load();
});

/// Which slice of the feed: a district ("near me") or the whole state,
/// optionally photos only.
class FeedFilter {
  const FeedFilter({this.districtId, this.withPhotos = false});

  final String? districtId;
  final bool withPhotos;

  @override
  bool operator ==(Object other) =>
      other is FeedFilter && other.districtId == districtId && other.withPhotos == withPhotos;

  @override
  int get hashCode => Object.hash(districtId, withPhotos);
}

class FeedState {
  const FeedState({
    this.posts = const [],
    this.loading = false,
    this.hasMore = true,
    this.error = false,
  });

  final List<PublicTicketModel> posts;
  final bool loading;
  final bool hasMore;
  final bool error;

  FeedState copyWith({List<PublicTicketModel>? posts, bool? loading, bool? hasMore, bool? error}) =>
      FeedState(
        posts: posts ?? this.posts,
        loading: loading ?? this.loading,
        hasMore: hasMore ?? this.hasMore,
        error: error ?? this.error,
      );
}

/// Pages through the feed — one fetch per page rather than a live listener
/// on hundreds of posts, so scrolling stays cheap on reads.
class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._service, this._filter) : super(const FeedState()) {
    loadMore();
  }

  final FeedService _service;
  final FeedFilter _filter;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true, error: false);
    try {
      final page = await _service.page(
        districtId: _filter.districtId,
        withPhotos: _filter.withPhotos,
        after: _cursor,
      );
      _cursor = page.cursor;
      state = state.copyWith(
        posts: [...state.posts, ...page.posts],
        loading: false,
        hasMore: page.hasMore,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: true);
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    state = const FeedState();
    await loadMore();
  }
}

final feedProvider = StateNotifierProvider.autoDispose.family<FeedNotifier, FeedState, FeedFilter>(
  (ref, filter) => FeedNotifier(ref.watch(feedServiceProvider), filter),
);

/// The latest few posts for the home strip: the citizen's district first,
/// the whole state when their district has none yet.
final homeFeedPreviewProvider =
    FutureProvider.autoDispose.family<List<PublicTicketModel>, String?>((ref, districtId) async {
  final service = ref.watch(feedServiceProvider);
  if (districtId != null) {
    final near = await service.page(districtId: districtId, limit: 8);
    if (near.posts.isNotEmpty) return near.posts;
  }
  return (await service.page(limit: 8)).posts;
});

/// Reports this citizen said "Me too" to (empty when signed out).
final mySupportsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return ref.watch(feedServiceProvider).watchMySupports(uid);
});

/// Ids of the citizen's own reports — "Me too" is off on those.
final myReportIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return ref
      .watch(firestoreServiceProvider)
      .watchUserSubmissions(uid)
      .map((list) => list.map((s) => s.id).toSet());
});

final feedCommentsProvider = StreamProvider.autoDispose.family<List<FeedComment>, String>(
  (ref, ticketId) => ref.watch(feedServiceProvider).watchComments(ticketId),
);
