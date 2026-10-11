import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers/current_user_profile_provider.dart';
import '../../app/theme.dart';
import '../../core/models/official_scope.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/official_service.dart';
import '../../shared/widgets/animated_stat_tile.dart';
import '../official/briefing/ai_briefing_card.dart';

final _overviewProvider =
    FutureProvider.autoDispose<AdminOverview>((ref) => OfficialService().adminOverview());

final _applicationsProvider = StreamProvider.autoDispose
    .family<List<OfficialApplication>, String>(
        (ref, status) => OfficialService().watchApplications(status));

/// Prajadhwani Admin console: platform overview with a statewide AI
/// briefing + PDF report, and the approvals queue for self-registered
/// MLAs and officers.
class AdminConsoleScreen extends ConsumerWidget {
  const AdminConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    return profile.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Could not load your account.'))),
      data: (p) {
        if (p?.role != UserRole.admin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Prajadhwani Admin')),
            body: Center(
              child: FilledButton(
                onPressed: () => context.go('/admin/login'),
                child: const Text('Sign in as admin'),
              ),
            ),
          );
        }
        final pending = ref.watch(_applicationsProvider('pending')).valueOrNull?.length ?? 0;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.paper,
            appBar: AppBar(
              backgroundColor: AppColors.tealDeep,
              title: const Text('Prajadhwani Admin'),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) context.go('/welcome');
                  },
                ),
              ],
              bottom: TabBar(
                indicatorColor: AppColors.saffron,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  const Tab(icon: Icon(Icons.insights_rounded), text: 'Overview'),
                  Tab(
                    icon: Badge(
                      isLabelVisible: pending > 0,
                      label: Text('$pending'),
                      child: const Icon(Icons.how_to_reg_rounded),
                    ),
                    text: 'Approvals',
                  ),
                ],
              ),
            ),
            body: const TabBarView(children: [_OverviewTab(), _ApprovalsTab()]),
          ),
        );
      },
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(_overviewProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_overviewProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          overview.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Text('Could not load platform numbers.'),
            data: (o) {
              final rate = o.reports == 0 ? 0 : (o.resolved * 100 / o.reports).round();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      AnimatedStatTile(value: o.citizens, label: 'Citizens', color: AppColors.saffronDeep, icon: Icons.groups_rounded),
                      AnimatedStatTile(value: o.officials, label: 'Approved officials', color: AppColors.indigo, icon: Icons.verified_user_rounded),
                      AnimatedStatTile(value: o.reportsThisWeek, label: 'Reports this week', color: AppColors.vermilion, icon: Icons.campaign_rounded),
                      AnimatedStatTile(value: rate, suffix: '%', label: 'Resolved statewide', color: AppColors.teal, icon: Icons.task_alt_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      boxShadow: appCardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Officials by role',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        for (final t in OfficialType.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(t.icon, size: 18, color: AppColors.indigo),
                                const SizedBox(width: 10),
                                Expanded(child: Text(t.label)),
                                Text('${o.byType[t.name] ?? 0}',
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        if (o.pending > 0) ...[
                          const Divider(),
                          Text('${o.pending} application${o.pending == 1 ? '' : 's'} waiting for review',
                              style: const TextStyle(
                                  color: AppColors.vermilion, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Statewide briefing',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const AiBriefingCard(),
        ],
      ),
    );
  }
}

class _ApprovalsTab extends StatefulWidget {
  const _ApprovalsTab();

  @override
  State<_ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<_ApprovalsTab> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final apps = ref.watch(_applicationsProvider(_status));
              return apps.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text('Could not load: $e')),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text('No $_status applications.',
                            style: const TextStyle(color: AppColors.inkSoft)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ApplicationCard(app: list[i]),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  const _ApplicationCard({required this.app});

  final OfficialApplication app;

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  final _service = OfficialService();
  late final Future<Uint8List?> _proof = widget.app.proofPath == null
      ? Future.value(null)
      : _service.loadProof(widget.app.proofPath!).catchError((_) => null);
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    String? reason;
    if (!approve) {
      final ctrl = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject application'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Reason shown to the applicant'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (reason == null || reason.isEmpty) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.review(widget.app.uid, approve: approve, reason: reason);
      messenger.showSnackBar(SnackBar(
          content: Text(approve ? '${widget.app.name} approved.' : 'Application rejected.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _viewProof(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.memory(bytes)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    return Container(
      padding: const EdgeInsets.all(14),
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
              CircleAvatar(
                backgroundColor: AppColors.indigoMist,
                child: Icon(a.officialType.icon, color: AppColors.indigo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${a.officialType.shortLabel} · ${a.jurisdictionName}',
                        style: const TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text([a.designation, a.officialEmail].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          if (a.submittedAt != null)
            Text('Submitted ${DateFormat.yMMMd().add_jm().format(a.submittedAt!)}',
                style: const TextStyle(color: AppColors.inkFaint, fontSize: 12)),
          if (a.status == 'rejected' && (a.rejectionReason ?? '').isNotEmpty)
            Text('Reason: ${a.rejectionReason}',
                style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
          const SizedBox(height: 10),
          FutureBuilder<Uint8List?>(
            future: _proof,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 120, child: Center(child: CircularProgressIndicator()));
              }
              final bytes = snap.data;
              if (bytes == null) {
                return const Text('No proof image available.',
                    style: TextStyle(color: AppColors.inkFaint));
              }
              return GestureDetector(
                onTap: () => _viewProof(bytes),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, height: 160, fit: BoxFit.cover),
                ),
              );
            },
          ),
          if (a.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _decide(false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.vermilion,
                      side: const BorderSide(color: AppColors.vermilion),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _decide(true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
