import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/citizen_stats.dart';
import '../../../core/services/profile_completeness.dart';
import '../../../core/services/storage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/animated_stat_tile.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import '../../../shared/widgets/citizen_activity_widgets.dart';
import '../../../shared/widgets/citizen_avatar.dart';
import '../../../shared/widgets/consistency_map.dart';
import '../../../shared/widgets/mp_constituency_card.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import '../../onboarding/auth/auth_common.dart';
import '../../onboarding/language_select_screen.dart';

final _profileSubmissionsProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchUserSubmissions(uid);
});

/// The MLA and assembly segment for the citizen's home — from their BBMP
/// ward, GBA ward or taluk doc, whichever they have (all carry
/// `mlaName`/`assemblyConstituency`).
/// Keyed by `(wardId, talukId)` — a record, so equal ids share one fetch.
final _homeRepresentativeProvider = FutureProvider.family<
    ({String? mla, String? assembly})?,
    (String?, String?)>((ref, ids) async {
  final fs = ref.watch(firestoreServiceProvider);
  final (wardId, talukId) = ids;
  if (wardId != null) {
    final ward = await fs.getWard(wardId);
    if (ward != null) {
      return (mla: ward.mlaName, assembly: ward.assemblyConstituency);
    }
  }
  if (talukId != null) {
    final taluk = await fs.getTaluk(talukId);
    if (taluk != null) {
      return (mla: taluk.mlaName, assembly: taluk.assemblyConstituency);
    }
  }
  return null;
});

/// The citizen's profile, built to make civic participation feel worth it:
/// who they are and what level they've reached, the impact they've had, the
/// next thing to unlock, the place they represent and who represents them,
/// then account settings. Every number comes from their own submissions —
/// nothing here compares them to anyone else.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: FilledButton(
                onPressed: () => context.go('/signin'),
                child: Text(l10n.signIn),
              ),
            );
          }
          final submissions =
              ref.watch(_profileSubmissionsProvider(profile.uid)).valueOrNull ??
                  const <SubmissionModel>[];
          return _ProfileBody(profile: profile, submissions: submissions);
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.submissions});

  final UserModel profile;
  final List<SubmissionModel> submissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final level = computeLevel(submissions.length);
    final completeness = profileCompleteness(profile);
    final resolved =
        submissions.where((s) => s.status == SubmissionStatus.resolved).length;
    final supporters = submissions.fold<int>(0, (a, s) => a + s.supporterCount);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _HeroHeader(profile: profile, level: level),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedStatTile(
                      value: submissions.length,
                      label: l10n.statReportsFiled,
                      color: AppColors.indigo,
                      icon: Icons.campaign_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedStatTile(
                      value: resolved,
                      label: l10n.statResolved,
                      color: AppColors.teal,
                      icon: Icons.task_alt_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedStatTile(
                      value: supporters,
                      label: l10n.statSupporters,
                      color: AppColors.saffronDeep,
                      icon: Icons.favorite_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!completeness.isComplete) ...[
                _CompletenessCard(profile: profile, completeness: completeness),
                const SizedBox(height: 14),
              ],
              _MotivationCard(level: level, submissions: submissions),
              const SizedBox(height: 14),
              _MyPlaceCard(profile: profile),
              const SizedBox(height: 14),
              _RepresentativesCard(profile: profile),
              const SizedBox(height: 14),
              _Section(
                title: l10n.badgesTitle,
                icon: Icons.military_tech_rounded,
                child: BadgeGrid(badges: computeBadges(submissions)),
              ),
              const SizedBox(height: 14),
              _RecentReportsCard(submissions: submissions),
              const SizedBox(height: 14),
              _AccountCard(profile: profile),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero header
// ---------------------------------------------------------------------------

class _HeroHeader extends ConsumerStatefulWidget {
  const _HeroHeader({required this.profile, required this.level});

  final UserModel profile;
  final CitizenLevel level;

  @override
  ConsumerState<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends ConsumerState<_HeroHeader> {
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.length > StorageService.maxAvatarBytes) {
        throw StateError('too large');
      }
      final path = await StorageService()
          .uploadAvatar(userId: widget.profile.uid, bytes: bytes);
      await ref
          .read(firestoreServiceProvider)
          .upsertUser(widget.profile.copyWith(photoPath: path));
      ref.invalidate(avatarBytesProvider(path));
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoUpdated)));
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoFailed)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.profile;
    final level = widget.level;
    final since = DateFormat.yMMM(Localizations.localeOf(context).toString())
        .format(p.createdAt);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.indigoDeep, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
                Expanded(
                  child: Text(l10n.profileTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CitizenAvatar(
                  name: p.name,
                  photoPath: p.photoPath,
                  levelProgress: level.progress,
                  size: 108,
                  seed: p.uid,
                ),
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Material(
                    color: AppColors.saffron,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploading ? null : _pickPhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.photo_camera_rounded,
                                size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(p.name ?? l10n.citizenDefault,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            if ((p.username ?? '').isNotEmpty)
              Text('@${p.username}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.saffron.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.saffron.withValues(alpha: 0.6)),
              ),
              child: Text(
                '${l10n.levelLabel(level.level)} · ${levelTitle(level.level, l10n)}',
                style: const TextStyle(
                    color: AppColors.saffron,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.memberSince(since),
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 18),
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.saffron,
                  Colors.white,
                  AppColors.teal,
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// "Profile 50% complete" with one tappable fix per missing item.
class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.profile, required this.completeness});

  final UserModel profile;
  final ProfileCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.saffronMist,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.saffron.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profileCompleteTitle(completeness.percent),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.saffronDeep)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completeness.fraction,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.saffron,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in completeness.missing)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_iconFor(item), color: AppColors.saffronDeep),
              title: Text(_labelFor(item, l10n),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _fix(context, item),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(ProfileItem item) => switch (item) {
        ProfileItem.photo => Icons.add_a_photo_rounded,
        ProfileItem.age => Icons.cake_rounded,
        ProfileItem.homeLocation => Icons.home_rounded,
        ProfileItem.securityQuestion => Icons.shield_rounded,
      };

  String _labelFor(ProfileItem item, AppLocalizations l10n) => switch (item) {
        ProfileItem.photo => l10n.completeAddPhoto,
        ProfileItem.age => l10n.completeAddAge,
        ProfileItem.homeLocation => l10n.completeSetHome,
        ProfileItem.securityQuestion => l10n.completeSecurityQuestion,
      };

  void _fix(BuildContext context, ProfileItem item) {
    switch (item) {
      case ProfileItem.homeLocation:
        context.go('/signup/location', extra: true);
      case ProfileItem.securityQuestion:
        _showSheet(context, const _ChangeSecurityQuestionForm());
      case ProfileItem.age:
        _showSheet(context, _EditProfileForm(profile: profile));
      case ProfileItem.photo:
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10nOf(context).tapCameraToAddPhoto)));
    }
  }
}

AppLocalizations l10nOf(BuildContext context) => AppLocalizations.of(context);

void _showSheet(BuildContext context, Widget child) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(child: child),
    ),
  );
}

/// Level progress, streak and the one next thing to do.
class _MotivationCard extends StatelessWidget {
  const _MotivationCard({required this.level, required this.submissions});

  final CitizenLevel level;
  final List<SubmissionModel> submissions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nudge = submissions.isEmpty
        ? l10n.nudgeFirstReport
        : level.isMaxLevel
            ? l10n.levelMaxReached
            : l10n.nudgeNextLevel(level.reportsToNext, level.level + 1,
                levelTitle(level.level + 1, l10n));
    return _Section(
      title: l10n.yourCivicJourney,
      icon: Icons.emoji_events_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LevelProgressBar(level: level),
          const SizedBox(height: 14),
          StreakBadgeRow(stats: computeStreaks(submissions)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.indigoMist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded,
                    color: AppColors.indigo, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(nudge,
                      style: const TextStyle(
                          color: AppColors.indigoDeep,
                          fontWeight: FontWeight.w600,
                          height: 1.35)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/compose'),
            icon: const Icon(Icons.add_comment_rounded),
            label: Text(l10n.fileAReport),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.saffron,
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the citizen lives, in every unit the app routes by, with a
/// mini map of their home pin.
class _MyPlaceCard extends StatelessWidget {
  const _MyPlaceCard({required this.profile});

  final UserModel profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = profile;
    final hasPin = p.lat != null && p.lng != null;
    final rows = <(IconData, String, String?)>[
      (Icons.home_rounded, l10n.placeAddress, p.addressHome),
      (Icons.pin_drop_rounded, l10n.pincode, p.pincodeHome),
      (Icons.grid_on_rounded, l10n.placeBbmpWard, p.homeBbmpWardName),
      (Icons.grid_view_rounded, l10n.placeGbaWard, p.homeWardName),
      (Icons.location_city_rounded, l10n.placeTaluk, p.talukName),
      (Icons.map_rounded, l10n.placeDistrict, p.districtName),
      (Icons.how_to_vote_rounded, l10n.placeConstituency,
          p.constituencyName ?? p.constituencyId),
    ].where((r) => (r.$3 ?? '').trim().isNotEmpty).toList();

    return _Section(
      title: l10n.myPlaceTitle,
      icon: Icons.place_rounded,
      trailing: TextButton(
        onPressed: () => context.go('/signup/location', extra: true),
        child: Text(hasPin ? l10n.changeLabel : l10n.completeSetHome),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasPin) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 150,
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(p.lat!, p.lng!),
                      initialZoom: 14,
                    ),
                    children: [
                      appBaseTileLayer(context),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on,
                              size: 40, color: AppColors.vermilion),
                        ),
                      ]),
                      appMapAttributionCompact(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (rows.isEmpty)
            Text(l10n.noHomeLocation,
                style: const TextStyle(color: AppColors.inkFaint))
          else
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: AppColors.inkFaint),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkFaint)),
                    ),
                    Expanded(
                      child: Text(value!,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RepresentativesCard extends ConsumerWidget {
  const _RepresentativesCard({required this.profile});

  final UserModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rep = ref
        .watch(_homeRepresentativeProvider(
            (profile.homeBbmpWardId ?? profile.homeWardId, profile.talukId)))
        .valueOrNull;
    return _Section(
      title: l10n.myRepresentativesTitle,
      icon: Icons.account_balance_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MpConstituencyCard(constituencyId: profile.constituencyId),
          if ((rep?.assembly ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.saffronMist,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.saffronDeep,
                    child: Text('MLA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (rep!.mla ?? '').isNotEmpty
                              ? rep.mla!
                              : l10n.mlaNotListed,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(l10n.assemblySegment(rep.assembly!),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Contribution grid plus the last three reports, so "past info" is one
/// glance away.
class _RecentReportsCard extends StatelessWidget {
  const _RecentReportsCard({required this.submissions});

  final List<SubmissionModel> submissions;

  String _statusText(SubmissionStatus s, AppLocalizations l10n) =>
      switch (s) {
        SubmissionStatus.newSubmission => l10n.statusFiled,
        SubmissionStatus.reviewed => l10n.statusAcknowledged,
        SubmissionStatus.inProgress => l10n.statusInProgress,
        SubmissionStatus.resolved => l10n.statusResolved,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Section(
      title: l10n.yourCivicActivity,
      icon: Icons.history_rounded,
      trailing: submissions.isEmpty
          ? null
          : TextButton(
              onPressed: () => context.go('/reports'),
              child: Text(l10n.seeAll),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.contributionsInLast26Weeks,
              style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
          const SizedBox(height: 8),
          ConsistencyMap(grid: buildContributionGrid(submissions)),
          const SizedBox(height: 12),
          if (submissions.isEmpty)
            Text(l10n.consistencyEmptyNudge,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.inkFaint, height: 1.4))
          else
            for (final s in submissions.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(kThemeIcons[s.theme ?? 'more'],
                    color: categoryColor(s.theme ?? 'more')),
                title: Text(s.tokenId,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                subtitle: Text(
                  (s.rawText ?? s.transcript ?? '').trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.status == SubmissionStatus.resolved
                        ? AppColors.tealMist
                        : AppColors.indigoMist,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_statusText(s.status, l10n),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: s.status == SubmissionStatus.resolved
                              ? AppColors.tealDeep
                              : AppColors.indigo)),
                ),
                onTap: () => context.push('/reports/${s.id}', extra: s),
              ),
        ],
      ),
    );
  }
}

/// Name/age, language, password, security question, dashboard, privacy,
/// sign out.
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.profile});

  final UserModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageEntry = kSupportedLanguages.firstWhere(
      (l) => l.$1 == profile.preferredLanguage,
      orElse: () => ('en', 'English', 'English'),
    );
    Widget tile(IconData icon, String title, VoidCallback onTap,
            {String? subtitle}) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.indigo),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );

    return _Section(
      title: l10n.accountSettingsTitle,
      icon: Icons.settings_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(Icons.badge_rounded, l10n.editNameAge,
              () => _showSheet(context, _EditProfileForm(profile: profile))),
          tile(Icons.language_rounded, l10n.preferredLanguage,
              () => context.go('/language', extra: true),
              subtitle: '${languageEntry.$3} (${languageEntry.$2})'),
          tile(Icons.lock_reset_rounded, l10n.changePasswordTitle,
              () => _showSheet(context, const _ChangePasswordForm())),
          tile(
            Icons.shield_outlined,
            l10n.changeSecurityQuestionTitle,
            () => _showSheet(context, const _ChangeSecurityQuestionForm()),
            subtitle: profile.hasSecurityQuestion
                ? l10n.recoveryIsSetUp
                : l10n.recoveryNotSetUp,
          ),
          tile(Icons.travel_explore_rounded, l10n.seePublicDashboard,
              () => context.go('/public/dashboard')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.indigoMist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_rounded,
                    size: 18, color: AppColors.indigoDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.privacyStoreAddress,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.indigoDeep,
                          height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              await ref.read(onboardingProgressProvider.notifier).reset();
              if (context.mounted) context.go('/welcome');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.vermilion,
              side: const BorderSide(color: AppColors.vermilion),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.signOutClears),
          ),
        ],
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.profile});

  final UserModel profile;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name ?? '');
  late final _age =
      TextEditingController(text: widget.profile.age?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(firestoreServiceProvider).upsertUser(widget.profile.copyWith(
          name: _name.text.trim(),
          age: int.tryParse(_age.text.trim()),
        ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.editNameAge,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.fullName),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? l10n.nameRequired : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.age),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              return n == null || n < 10 || n > 120 ? l10n.enterValidAge : null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.saveLabel),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService().changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
    } on CitizenAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = citizenAuthErrorText(e.failure, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.changePasswordTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          PasswordField(
            controller: _current,
            label: l10n.currentPasswordLabel,
            validator: (v) => (v ?? '').isEmpty ? l10n.passwordTooShort : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _next,
            label: l10n.newPasswordLabel,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => validateNewPasswordField(v, l10n),
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirm,
            label: l10n.confirmPasswordLabel,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => v != _next.text ? l10n.passwordsDontMatch : null,
          ),
          const SizedBox(height: 16),
          if (_error != null) AuthErrorBanner(_error!),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(l10n.saveLabel),
          ),
        ],
      ),
    );
  }
}

class _ChangeSecurityQuestionForm extends StatefulWidget {
  const _ChangeSecurityQuestionForm();

  @override
  State<_ChangeSecurityQuestionForm> createState() =>
      _ChangeSecurityQuestionFormState();
}

class _ChangeSecurityQuestionFormState
    extends State<_ChangeSecurityQuestionForm> {
  final _formKey = GlobalKey<FormState>();
  final _answer = TextEditingController();
  String _questionId = kSecurityQuestionIds.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AccountRecoveryService().setSecurityQuestion(
        questionId: _questionId,
        answer: _answer.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.securityQuestionSaved)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.couldNotContinue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.changeSecurityQuestionTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SecurityQuestionFields(
            questionId: _questionId,
            onQuestionChanged: (id) => setState(() => _questionId = id),
            answerController: _answer,
          ),
          const SizedBox(height: 16),
          if (_error != null) AuthErrorBanner(_error!),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(l10n.saveLabel),
          ),
        ],
      ),
    );
  }
}
