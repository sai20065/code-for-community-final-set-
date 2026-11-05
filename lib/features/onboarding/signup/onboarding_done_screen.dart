import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/citizen_avatar.dart';
import '../../../shared/widgets/mp_constituency_card.dart';
import '../../../shared/widgets/primary_button.dart';

/// Final onboarding step, shown exactly once: "Your civic profile is
/// ready". Instead of a bare "you're set up", the new citizen sees their own
/// profile come together — avatar, Level 1 badge, the area they now speak
/// for and who represents it — then three concrete first steps, so the
/// very first thing they do in the app is meaningful.
class OnboardingDoneScreen extends ConsumerStatefulWidget {
  const OnboardingDoneScreen({super.key});

  @override
  ConsumerState<OnboardingDoneScreen> createState() =>
      _OnboardingDoneScreenState();
}

class _OnboardingDoneScreenState extends ConsumerState<OnboardingDoneScreen>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _player
        .play(AssetSource('sounds/success_chime.wav'), volume: 0.6)
        .catchError((_) {});
  }

  @override
  void dispose() {
    _intro.dispose();
    _player.dispose();
    super.dispose();
  }

  /// Staggered fade + rise for each block, so the profile "assembles".
  Widget _reveal(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.4).clamp(0, 1), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }

  void _openAreaMap(UserModel p) {
    if (p.constituencyId != null) {
      ref.read(publicConstituencyProvider.notifier).select(p.constituencyId!);
    }
    context.go('/public/map');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reveal(0, _Header(profile: profile)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _reveal(0.2, _AreaCard(profile: profile)),
                        const SizedBox(height: 14),
                        _reveal(
                          0.35,
                          _FirstSteps(
                            onReport: () => context.go('/compose'),
                            onSupport: () => context.go('/home'),
                            onMap: () => _openAreaMap(profile),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _reveal(
                          0.5,
                          PrimaryButton(
                            label: l10n.goToHome,
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () => context.go('/home'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => context.go('/profile'),
                          child: Text(l10n.viewMyProfile),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserModel profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstName = (profile.name ?? '').trim().split(RegExp(r'\s+')).first;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            children: [
              CitizenAvatar(
                name: profile.name,
                photoPath: profile.photoPath,
                levelProgress: 0.08,
                size: 112,
                seed: profile.uid,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.revealWelcome(firstName.isEmpty ? l10n.citizenDefault : firstName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.revealSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.saffron,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_rounded,
                        size: 18, color: AppColors.ink),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.levelLabel(1)} · ${levelTitle(1, l10n)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              if ((profile.username ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('@${profile.username}',
                    style: const TextStyle(color: Colors.white60)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.profile});

  final UserModel profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = profile;
    final local = p.homeBbmpWardName ?? p.homeWardName ?? p.talukName;
    final lines = [
      if ((local ?? '').isNotEmpty) local!,
      if ((p.districtName ?? '').isNotEmpty) p.districtName!,
      if ((p.constituencyName ?? '').isNotEmpty)
        l10n.placeConstituencyShort(p.constituencyName!),
    ];
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
              const Icon(Icons.place_rounded, color: AppColors.vermilion),
              const SizedBox(width: 8),
              Text(l10n.yourAreaTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lines.isEmpty ? l10n.noHomeLocation : lines.join(' · '),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(l10n.yourAreaNote,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSoft, height: 1.4)),
          const SizedBox(height: 12),
          MpConstituencyCard(constituencyId: p.constituencyId),
        ],
      ),
    );
  }
}

class _FirstSteps extends StatelessWidget {
  const _FirstSteps({
    required this.onReport,
    required this.onSupport,
    required this.onMap,
  });

  final VoidCallback onReport;
  final VoidCallback onSupport;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget step(int n, IconData icon, Color color, String title, String body,
            VoidCallback onTap) =>
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$n. $title',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(body,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkFaint),
              ],
            ),
          ),
        );

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
              const Icon(Icons.flag_rounded, color: AppColors.teal),
              const SizedBox(width: 8),
              Text(l10n.firstStepsTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          step(1, Icons.campaign_rounded, AppColors.vermilion,
              l10n.stepFirstReport, l10n.stepFirstReportBody, onReport),
          step(2, Icons.favorite_rounded, AppColors.saffronDeep,
              l10n.stepSupport, l10n.stepSupportBody, onSupport),
          step(3, Icons.map_rounded, AppColors.teal, l10n.stepExploreMap,
              l10n.stepExploreMapBody, onMap),
        ],
      ),
    );
  }
}
