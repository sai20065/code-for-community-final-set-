import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/citizen_stats.dart';
import '../../../core/services/firestore_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/citizen_activity_widgets.dart';
import '../../../shared/widgets/consistency_map.dart';
import '../../../shared/widgets/mp_constituency_card.dart';
import '../../onboarding/language_select_screen.dart';

final _profileSubmissionsProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchUserSubmissions(uid);
});

/// Profile: home constituency/booth/pincode/language at a glance, a privacy
/// reminder (what's stored and why), and sign-out. Nothing here lets the
/// citizen see or edit an Aadhaar number — there isn't one stored.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authService = AuthService();
    final profileAsync = ref.watch(currentUserProfileProvider);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.profileTitle),
      ),
      body: profileAsync.when(
        data: (profile) {
          final languageEntry = kSupportedLanguages.firstWhere(
            (l) => l.$1 == (profile?.preferredLanguage ?? 'en'),
            orElse: () => ('en', 'English', 'English'),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: appCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.name ?? l10n.citizenDefault,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.flag_rounded,
                      label: l10n.homeConstituency,
                      value: profile?.constituencyId ?? l10n.notYetMatched,
                    ),
                    const Divider(height: 22),
                    _InfoRow(
                      icon: Icons.place_rounded,
                      label: l10n.homeBooth,
                      value: profile?.homeBoothName ?? l10n.notYetMatched,
                    ),
                    const Divider(height: 22),
                    _InfoRow(
                      icon: Icons.pin_drop_rounded,
                      label: l10n.pincode,
                      value: profile?.pincodeHome ?? '—',
                    ),
                    const Divider(height: 22),
                    InkWell(
                      onTap: () => context.go('/language', extra: true),
                      borderRadius: BorderRadius.circular(10),
                      child: _InfoRow(
                        icon: Icons.language_rounded,
                        label: l10n.preferredLanguage,
                        value: '${languageEntry.$3} (${languageEntry.$2})',
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                      ),
                    ),
                  ],
                ),
              ),
              if (uid != null) ...[
                const SizedBox(height: 16),
                _CivicActivityCard(uid: uid),
              ],
              const SizedBox(height: 16),
              MpConstituencyCard(constituencyId: profile?.constituencyId),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/public/dashboard'),
                icon: const Icon(Icons.travel_explore_rounded),
                label: Text(l10n.seePublicDashboard),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.indigoMist,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_rounded, size: 18, color: AppColors.indigoDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.privacyStoreAddress,
                        style: const TextStyle(fontSize: 12, color: AppColors.indigoDeep, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await authService.signOut();
                  await ref.read(onboardingProgressProvider.notifier).reset();
                  if (context.mounted) context.go('/language');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.vermilion,
                  side: const BorderSide(color: AppColors.vermilion),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.signOutClears),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
      ),
    );
  }
}

/// The full 26-week activity picture: contribution grid, streaks, level
/// progress, badges, and a way out to the public dashboard.
///
/// Shares `_profileSubmissionsProvider` with nothing else on this screen —
/// riverpod caches it per-uid, so if the citizen came from Home (which
/// already watches the same underlying query) this costs nothing extra.
class _CivicActivityCard extends ConsumerWidget {
  const _CivicActivityCard({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final submissionsAsync = ref.watch(_profileSubmissionsProvider(uid));

    return submissionsAsync.when(
      data: (submissions) {
        final grid = buildContributionGrid(submissions);
        final streaks = computeStreaks(submissions);
        final level = computeLevel(submissions.length);
        final badges = computeBadges(submissions);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: appCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.yourCivicActivity,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 14),
              if (submissions.isEmpty)
                Text(l10n.consistencyEmptyNudge,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.inkFaint, height: 1.4))
              else ...[
                StreakBadgeRow(stats: streaks),
                const SizedBox(height: 16),
                Text(l10n.contributionsInLast26Weeks,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.inkFaint)),
                const SizedBox(height: 8),
                ConsistencyMap(grid: grid),
                const SizedBox(height: 18),
                LevelProgressBar(level: level),
                const SizedBox(height: 18),
                BadgeGrid(badges: badges),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkFaint),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
