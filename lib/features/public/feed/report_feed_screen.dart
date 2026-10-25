import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/feed_providers.dart';
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/representative_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/feed_post_card.dart';
import '../../../shared/widgets/report_post_text.dart';

/// The citizen feed: real reports as Instagram-style posts, newest first —
/// the citizen's district by default, the whole state on a tap. Photos
/// appear only when the reporter opted in, and only as the blurred public
/// copy.
class ReportFeedScreen extends ConsumerStatefulWidget {
  const ReportFeedScreen({super.key});

  @override
  ConsumerState<ReportFeedScreen> createState() => _ReportFeedScreenState();
}

class _ReportFeedScreenState extends ConsumerState<ReportFeedScreen> {
  final _scroll = ScrollController();
  bool? _nearMe;
  bool _withPhotos = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  FeedFilter get _filter {
    final district = ref.read(currentUserProfileProvider).valueOrNull?.districtId;
    final near = (_nearMe ?? district != null) && district != null;
    return FeedFilter(districtId: near ? district : null, withPhotos: _withPhotos);
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 800) {
      ref.read(feedProvider(_filter).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final district = ref.watch(currentUserProfileProvider).valueOrNull?.districtId;
    final nearMe = (_nearMe ?? district != null) && district != null;
    final filter = _filter;
    final feed = ref.watch(feedProvider(filter));
    final reps = ref.watch(publicRepsProvider).valueOrNull ?? PublicReps.empty;
    final geo = ref.watch(karnatakaGeoProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.feedTitle),
        actions: [
          IconButton(
            tooltip: l10n.leaderboardTitle,
            onPressed: () => context.push('/public/leaderboard'),
            icon: const Icon(Icons.leaderboard_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedProvider(filter).notifier).refresh(),
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          itemCount: feed.posts.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(spacing: 8, children: [
                  if (district != null)
                    ChoiceChip(
                      label: Text(l10n.feedNearMe),
                      selected: nearMe,
                      onSelected: (_) => setState(() => _nearMe = true),
                    ),
                  ChoiceChip(
                    label: Text(l10n.feedAllKarnataka),
                    selected: !nearMe,
                    onSelected: (_) => setState(() => _nearMe = false),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: Text(l10n.feedWithPhotos),
                    selected: _withPhotos,
                    onSelected: (v) => setState(() => _withPhotos = v),
                  ),
                ]),
              );
            }
            if (i == feed.posts.length + 1) {
              if (feed.loading) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (feed.error) {
                return Center(
                  child: TextButton(
                    onPressed: () => ref.read(feedProvider(filter).notifier).loadMore(),
                    child: Text(l10n.somethingWentWrong),
                  ),
                );
              }
              if (feed.posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  child: Column(children: [
                    const Icon(Icons.dynamic_feed_rounded, size: 48, color: AppColors.inkFaint),
                    const SizedBox(height: 12),
                    Text(l10n.feedEmpty, textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkSoft)),
                  ]),
                );
              }
              return const SizedBox(height: 24);
            }
            final t = feed.posts[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FeedPostCard(ticket: t, reps: reps, place: placeLabel(t, reps, geo)),
            );
          },
        ),
      ),
    );
  }
}

/// "Reports near you" — the home screen's horizontal strip into the feed.
class HomeFeedStrip extends ConsumerWidget {
  const HomeFeedStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final district = ref.watch(currentUserProfileProvider).valueOrNull?.districtId;
    final posts = ref.watch(homeFeedPreviewProvider(district)).valueOrNull ?? const [];
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(l10n.reportsNearYou,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          TextButton(onPressed: () => context.push('/feed'), child: Text(l10n.seeAll)),
        ]),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => FeedTile(ticket: posts[i]),
          ),
        ),
      ],
    );
  }
}
