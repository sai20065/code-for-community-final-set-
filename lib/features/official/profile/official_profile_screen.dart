import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/official_scope.dart';
import '../../../core/models/public_models.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/official_stats.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/animated_stat_tile.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import '../../../shared/widgets/citizen_avatar.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import '../../../shared/widgets/weekly_sparkline.dart';
import '../../onboarding/auth/auth_common.dart';
import '../briefing/ai_briefing_card.dart';

/// Collection holding the boundary for each jurisdiction type.
const _boundaryCollection = {
  'constituency': 'constituencies',
  'assembly': 'assemblies',
  'bbmpWard': 'wards',
  'taluk': 'taluks',
  'district': 'districts',
};

/// The area's outline rings, for the "My jurisdiction" map.
final _jurisdictionRingsProvider =
    FutureProvider.family<List<List<LatLng>>, (String, String)>((ref, key) async {
  final (type, id) = key;
  final coll = _boundaryCollection[type];
  if (coll == null) return const [];
  final data = (await FirebaseFirestore.instance.collection(coll).doc(id).get()).data();
  final raw = data?['boundaryGeoJson'];
  if (raw is! String) return const [];
  try {
    final g = jsonDecode(raw) as Map<String, dynamic>;
    List<LatLng> ring(List r) => [
          for (final p in r)
            LatLng(((p as List)[1] as num).toDouble(), (p[0] as num).toDouble())
        ];
    return switch (g['type']) {
      'Polygon' => [ring((g['coordinates'] as List).first as List)],
      'MultiPolygon' => [
          for (final poly in g['coordinates'] as List) ring((poly as List).first as List)
        ],
      _ => const [],
    };
  } catch (_) {
    return const [];
  }
});

/// Profile for MPs, MLAs, BBMP ward officers, Tahsildars and District
/// officers: who they are, how their area is doing, the badges their
/// responsiveness has earned, an AI briefing + PDF report, their
/// jurisdiction on a map and the area's top issues.
class OfficialProfileScreen extends ConsumerWidget {
  const OfficialProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your profile.')),
        data: (p) {
          final scope = p == null ? null : OfficialScope.fromUser(p);
          if (p == null || p.role != UserRole.official || scope == null) {
            return Center(
              child: FilledButton(
                onPressed: () => context.go('/gov/login'),
                child: const Text('Sign in as an official'),
              ),
            );
          }
          final tickets = ref.watch(publicAllTicketsProvider(scope.key)).valueOrNull ??
              const <PublicTicketModel>[];
          final clusters = ref.watch(publicClustersProvider(scope.key)).valueOrNull ??
              const <PublicClusterModel>[];
          final perf = computePerformance(tickets);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(profile: p, scope: scope, perf: perf),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.list(children: [
                  _PerformanceCard(perf: perf),
                  const SizedBox(height: 14),
                  _BadgesCard(perf: perf),
                  const SizedBox(height: 14),
                  const AiBriefingCard(compact: true),
                  const SizedBox(height: 14),
                  _JurisdictionCard(profile: p, scope: scope),
                  const SizedBox(height: 14),
                  _TopIssuesCard(clusters: clusters.take(3).toList()),
                  const SizedBox(height: 14),
                  _AccountCard(profile: p, scope: scope),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child, this.trailing});

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
          Row(children: [
            Icon(icon, size: 19, color: AppColors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Hero extends ConsumerStatefulWidget {
  const _Hero({required this.profile, required this.scope, required this.perf});

  final UserModel profile;
  final OfficialScope scope;
  final OfficialPerformance perf;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final path = await StorageService().uploadAvatar(userId: widget.profile.uid, bytes: bytes);
      await ref.read(firestoreServiceProvider).upsertUser(widget.profile.copyWith(photoPath: path));
      ref.invalidate(avatarBytesProvider(path));
      messenger.showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't upload the photo.")));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final s = widget.scope;
    final since = p.approvedAt ?? p.createdAt;
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
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/gov/dashboard'),
              ),
              const Expanded(
                child: Text('My profile',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ]),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CitizenAvatar(
                  name: p.name,
                  photoPath: p.photoPath,
                  levelProgress: widget.perf.resolutionRate / 100,
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(p.name ?? s.type.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: AppColors.saffron, size: 20),
              ],
            ),
            if ((p.designation ?? '').isNotEmpty)
              Text(p.designation!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.saffron.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.saffron.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.type.icon, size: 15, color: AppColors.saffron),
                  const SizedBox(width: 6),
                  Text('${s.type.shortLabel} · ${s.name}',
                      style: const TextStyle(
                          color: AppColors.saffron, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Verified official · serving since ${DateFormat.yMMM().format(since)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 18),
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.saffron, Colors.white, AppColors.teal]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.perf});

  final OfficialPerformance perf;

  @override
  Widget build(BuildContext context) {
    final avg = perf.avgDaysToResolve;
    return _Section(
      title: 'Performance in your area',
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: AnimatedStatTile(
                  value: perf.open, label: 'Open', color: AppColors.vermilion, icon: Icons.folder_open_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedStatTile(
                  value: perf.inProgress,
                  label: 'In progress',
                  color: AppColors.saffronDeep,
                  icon: Icons.engineering_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedStatTile(
                  value: perf.resolved, label: 'Resolved', color: AppColors.teal, icon: Icons.task_alt_rounded),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _Metric('${perf.resolutionRate}%', 'resolution rate'),
            _Metric(avg == null ? '—' : '${avg.toStringAsFixed(1)} d', 'avg. to resolve'),
            _Metric('${perf.resolvedThisWeek}', 'resolved this week'),
          ]),
          const SizedBox(height: 14),
          const Text('Resolved per week (last 8 weeks)',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
          const SizedBox(height: 6),
          WeeklySparkline(values: perf.weeklyResolved, color: AppColors.teal, height: 48),
          if (perf.overdueOpen > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.vermilionMist,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${perf.overdueOpen} report${perf.overdueOpen == 1 ? ' has' : 's have'} '
                  'been open for over 14 days.',
                  style: const TextStyle(color: AppColors.vermilionDeep, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.go('/official/tickets'),
            icon: const Icon(Icons.checklist_rounded),
            label: const Text('Work through open reports'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.indigoDeep)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.perf});

  final OfficialPerformance perf;

  @override
  Widget build(BuildContext context) {
    final badges = officialBadges(perf);
    final earned = badges.where((b) => b.$2).length;
    return _Section(
      title: 'Responsiveness badges',
      icon: Icons.military_tech_rounded,
      trailing: Text('$earned / ${badges.length}',
          style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700)),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (badge, got, progress) in badges)
            Tooltip(
              message: badge.hint,
              child: Container(
                width: 96,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: got ? AppColors.saffronMist : const Color(0xFFF1F0F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: got ? AppColors.saffron : Colors.transparent),
                ),
                child: Column(
                  children: [
                    Icon(
                      got ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                      color: got ? AppColors.saffronDeep : AppColors.inkFaint,
                    ),
                    const SizedBox(height: 4),
                    Text(badge.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: got ? AppColors.ink : AppColors.inkFaint)),
                    if (!got) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: AppColors.saffron,
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JurisdictionCard extends ConsumerWidget {
  const _JurisdictionCard({required this.profile, required this.scope});

  final UserModel profile;
  final OfficialScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jType = profile.jurisdictionType ?? scope.type.jurisdictionType;
    final rings = ref.watch(_jurisdictionRingsProvider((jType, scope.id))).valueOrNull ?? const [];
    final points = rings.expand((r) => r).toList();
    return _Section(
      title: 'My jurisdiction',
      icon: Icons.map_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(scope.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(scope.type.areaNoun, style: const TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          if (points.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    children: [
                      appBaseTileLayer(context, style: AppMapStyle.positron),
                      PolygonLayer(polygons: [
                        for (final r in rings)
                          Polygon(
                            points: r,
                            color: AppColors.indigo.withValues(alpha: 0.15),
                            borderColor: AppColors.indigo,
                            borderStrokeWidth: 2.5,
                          ),
                      ]),
                      appMapAttributionCompact(),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              if (scope.constituencyId != null) {
                ref.read(publicConstituencyProvider.notifier).select(scope.constituencyId!);
              }
              context.go('/gov/dashboard');
            },
            icon: const Icon(Icons.space_dashboard_rounded),
            label: const Text('Open dashboard'),
          ),
        ],
      ),
    );
  }
}

class _TopIssuesCard extends StatelessWidget {
  const _TopIssuesCard({required this.clusters});

  final List<PublicClusterModel> clusters;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Top issues in my area',
      icon: Icons.local_fire_department_rounded,
      child: clusters.isEmpty
          ? const Text('No issue groups yet — reports will appear here as citizens file them.',
              style: TextStyle(color: AppColors.inkSoft))
          : Column(
              children: [
                for (final c in clusters)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: categoryColor(c.theme).withValues(alpha: 0.14),
                      child: Icon(kThemeIcons[c.theme] ?? Icons.place, color: categoryColor(c.theme)),
                    ),
                    title: Text(c.summaryText.isEmpty ? c.theme : c.summaryText,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${c.submissionCount} reports · priority ${c.priorityScore.round()}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/public/cluster/${c.id}'),
                  ),
              ],
            ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.profile, required this.scope});

  final UserModel profile;
  final OfficialScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(IconData i, String t, VoidCallback onTap, {String? sub}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(i, color: AppColors.indigo),
          title: Text(t),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );
    final isMp = scope.type == OfficialType.mp;
    return _Section(
      title: 'Account',
      icon: Icons.settings_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(Icons.badge_rounded, 'Edit name & designation',
              () => _editProfile(context, ref)),
          if (!isMp)
            tile(Icons.lock_reset_rounded, 'Change password', () => _changePassword(context),
                sub: profile.officialEmail),
          if (isMp)
            tile(Icons.mail_lock_rounded, 'Reset credentials by email',
                () => context.go('/mp/forgot-credentials')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/welcome');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.vermilion,
              side: const BorderSide(color: AppColors.vermilion),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.paper,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: child,
        ),
      );

  void _editProfile(BuildContext context, WidgetRef ref) {
    final name = TextEditingController(text: profile.name ?? '');
    final designation = TextEditingController(text: profile.designation ?? '');
    _sheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Edit name & designation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 10),
          TextField(
              controller: designation, decoration: const InputDecoration(labelText: 'Designation')),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).upsertUser(profile.copyWith(
                    name: name.text.trim(),
                    designation: designation.text.trim(),
                  ));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context) {
    final current = TextEditingController();
    final next = TextEditingController();
    String? error;
    _sheet(
      context,
      StatefulBuilder(
        builder: (ctx, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Change password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              PasswordField(controller: current, label: 'Current password'),
              const SizedBox(height: 10),
              PasswordField(controller: next, label: 'New password (8+ characters)'),
              if (error != null) AuthErrorBanner(error!),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () async {
                  if (next.text.length < 8) return;
                  try {
                    await AuthService().changePassword(
                        currentPassword: current.text, newPassword: next.text);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password changed.')));
                    }
                  } catch (_) {
                    setState(() => error = 'Current password is wrong.');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
