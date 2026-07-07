import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/mp_constituency_card.dart';
import '../../../shared/widgets/status_stepper.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

const _kFilterCategories = ['education', 'roads', 'water', 'skilling', 'health'];

/// Home: booth/constituency context up top, category filter chips, a
/// "Trending near you" ranked-suggestion feed (public — feedback-category
/// only, per the Firestore security rules' own-area/feedback-only sharing
/// model), a private "Your recent reports" strip for the citizen's own
/// problem tickets, and a single FAB that opens the category picker (the
/// first step of the submit flow) rather than jumping straight into a
/// preset mode.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: profileAsync.when(
          data: (profile) => Text(
            profile?.name != null ? l10n.greetingHi(profile!.name!) : 'Prajadhwani',
          ),
          loading: () => const Text('Prajadhwani'),
          error: (_, __) => const Text('Prajadhwani'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Column(
            children: [
              profileAsync.when(
                data: (profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    profile?.constituencyId != null
                        ? l10n.homeAreaLabel(
                            '${profile!.constituencyId}'
                            '${profile.homeBoothName != null ? " · ${l10n.boothLabel(profile.homeBoothName!)}" : ""}')
                        : l10n.pincodeLabel(profile?.pincodeHome ?? "—"),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const TricolorTrustStrip(),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: l10n.myTickets,
            onPressed: () => context.go('/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _kFilterCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final id = _kFilterCategories[index];
                      final selected = _categoryFilter == id;
                      return _FilterChip(
                        themeId: id,
                        selected: selected,
                        onTap: () => setState(
                          () => _categoryFilter = selected ? null : id,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: profileAsync.when(
                    data: (profile) =>
                        MpConstituencyCard(constituencyId: profile?.constituencyId),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                if (uid != null) ...[
                  const SizedBox(height: 14),
                  _MyRecentReports(uid: uid),
                ],
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(l10n.trendingNearYou,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: profileAsync.when(
                    data: (profile) {
                      final constituencyId = profile?.constituencyId;
                      if (uid == null || constituencyId == null) {
                        return _EmptyState(message: l10n.emptyAreaSuggestions);
                      }
                      return _TrendingFeed(
                        constituencyId: constituencyId,
                        categoryFilter: _categoryFilter,
                        uid: uid,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _EmptyState(message: l10n.couldNotLoadSuggestions),
                  ),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              heroTag: 'new-submission-fab',
              backgroundColor: AppColors.saffron,
              onPressed: () => context.go('/compose'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.newSubmission),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.themeId, required this.selected, required this.onTap});

  final String themeId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(themeId);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kThemeIcons[themeId], size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              kThemeLabels[themeId] ?? themeId,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: selected ? color : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.record_voice_over_rounded, size: 48, color: AppColors.indigoMist),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkFaint)),
          ],
        ),
      ),
    );
  }
}

/// Private strip of the citizen's own most-recent problem reports — kept
/// separate from the public "Trending near you" feed below, since Firestore
/// security rules only let a citizen read their OWN problem tickets (only
/// `feedback`-category tickets are shared across a constituency).
class _MyRecentReports extends ConsumerWidget {
  const _MyRecentReports({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(_userSubmissionsProvider(uid));
    return submissionsAsync.when(
      data: (submissions) {
        final reports = submissions
            .where((s) => s.category == SubmissionCategory.problem)
            .take(3)
            .toList();
        if (reports.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(AppLocalizations.of(context).yourRecentReports,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final s = reports[index];
                  return _MyReportCard(
                    submission: s,
                    onTap: () => context.go('/reports/${s.id}', extra: s),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

final _userSubmissionsProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchUserSubmissions(uid);
});

class _MyReportCard extends StatelessWidget {
  const _MyReportCard({required this.submission, required this.onTap});

  final SubmissionModel submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeId = submission.theme ?? 'more';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(kThemeIcons[themeId], size: 14, color: categoryColor(themeId)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      submission.rawText ?? submission.transcript ?? submission.tokenId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              StatusStepper(status: submission.status, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingFeed extends ConsumerWidget {
  const _TrendingFeed({
    required this.constituencyId,
    required this.categoryFilter,
    required this.uid,
  });

  final String constituencyId;
  final String? categoryFilter;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(_trendingProvider(constituencyId));
    return trendingAsync.when(
      data: (suggestions) {
        final filtered = categoryFilter == null
            ? suggestions
            : suggestions.where((s) => s.theme == categoryFilter).toList();
        if (filtered.isEmpty) {
          return _EmptyState(message: AppLocalizations.of(context).noSuggestionsYet);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final s = filtered[index];
            return _TrendingCard(
              rank: index + 1,
              submission: s,
              isSupportedByMe: s.supporterIds.contains(uid),
              onSupport: () => ref.read(firestoreServiceProvider).toggleSupport(s.id, uid),
              onTap: () => context.go('/reports/${s.id}', extra: s),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _EmptyState(message: AppLocalizations.of(context).couldNotLoadSuggestions),
    );
  }
}

final _trendingProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, constituencyId) {
  return ref.watch(firestoreServiceProvider).watchTrendingSuggestions(constituencyId);
});

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.rank,
    required this.submission,
    required this.isSupportedByMe,
    required this.onSupport,
    required this.onTap,
  });

  final int rank;
  final SubmissionModel submission;
  final bool isSupportedByMe;
  final VoidCallback onSupport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeId = submission.theme ?? 'more';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        color: AppColors.indigo,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: categoryColor(themeId),
                    child: Icon(kThemeIcons[themeId], color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, right: 70),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            submission.rawText ?? submission.transcript ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.supportersCount(submission.supporterCount),
                            style: const TextStyle(color: AppColors.inkFaint, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onSupport,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(44, 36),
                      foregroundColor: isSupportedByMe ? Colors.white : AppColors.saffronDeep,
                      backgroundColor: isSupportedByMe ? AppColors.saffron : Colors.white,
                      side: const BorderSide(color: AppColors.saffron),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isSupportedByMe ? l10n.supported : l10n.iSupportThis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.saffronMist,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.suggestionUpper,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.saffronDeep),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
