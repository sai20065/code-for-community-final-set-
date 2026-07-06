import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

const _kFilterCategories = ['education', 'roads', 'water', 'skilling', 'health'];

/// Home: booth/constituency context up top, category filter chips, a
/// "Trending near you" ranked-suggestion feed, and two FABs distinct by
/// priority — primary "Submit suggestion" (saffron, bottom-right) is the
/// main product surface; secondary "Report problem" (vermilion outline,
/// bottom-left) is the simpler civic-issue flow.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: profileAsync.when(
          data: (profile) => Text(
            profile?.name != null ? 'Hi, ${profile!.name}' : 'Prajadhwani',
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
                        ? 'Constituency ${profile!.constituencyId} · Pincode ${profile.pincodeHome ?? "—"}'
                        : 'Pincode ${profile?.pincodeHome ?? "—"}',
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
            tooltip: 'My tickets',
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
                  child: Row(
                    children: [
                      Text('Trending near you',
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
                        return const _EmptyState(
                          message:
                              'Suggestions from your constituency will appear here once your area is confirmed.',
                        );
                      }
                      return _TrendingFeed(
                        constituencyId: constituencyId,
                        categoryFilter: _categoryFilter,
                        uid: uid,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const _EmptyState(message: 'Could not load suggestions.'),
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
              heroTag: 'suggest-fab',
              backgroundColor: AppColors.saffron,
              onPressed: () => context.go('/compose/text', extra: SubmissionCategory.feedback),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Submit suggestion'),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              heroTag: 'report-fab',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.vermilion,
              elevation: 1,
              onPressed: () => context.go('/compose/photo', extra: SubmissionCategory.problem),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Report problem'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: AppColors.vermilion, width: 1.4),
              ),
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
            Icon(Icons.record_voice_over_rounded, size: 48, color: AppColors.indigoMist),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkFaint)),
          ],
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
          return const _EmptyState(
            message: 'No suggestions yet — be the first to submit one for your area.',
          );
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
      error: (_, __) => const _EmptyState(message: 'Could not load suggestions.'),
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
    final themeId = submission.theme ?? 'more';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                      '${submission.supporterCount} supporters',
                      style: TextStyle(color: AppColors.inkFaint, fontSize: 11.5),
                    ),
                  ],
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
                  isSupportedByMe ? 'Supported' : 'I support this',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
