import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/public_models.dart';
import '../../../core/models/solution_card_model.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import '../../../shared/widgets/weekly_sparkline.dart';

/// The government-side workspace: one screen, six tabs — Overview, Reports,
/// Map, Hotspots, Emergency, Analytics.
///
/// **Everything here reads `publicTickets`/`publicClusters`, the anonymised
/// projections**, not `submissions` or `users`. An official tapping a map
/// indicator or a queue row sees a token number, the reported problem and
/// its area — and structurally cannot see a name, phone number or address,
/// because those fields are never written to the collections this screen
/// reads. Status writes are the one exception, and they go to
/// `submissions/{id}` by id without reading it back (`publicTickets` shares
/// the submission's document id — see
/// `functions/src/public/onSubmissionWritten.ts`).
class GovDashboardScreen extends ConsumerWidget {
  const GovDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      data: (profile) {
        final constituencyId = profile?.constituencyId;
        if (constituencyId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Government dashboard')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This account is not linked to a constituency yet. Contact '
                  'the Prajadhwani administrator to have it assigned.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _GovShell(constituencyId: constituencyId);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Government dashboard')),
        body: const Center(child: Text('Could not load your profile.')),
      ),
    );
  }
}

class _GovShell extends ConsumerWidget {
  const _GovShell({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final constituency = ref.watch(constituencyProvider(constituencyId)).valueOrNull;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/public/dashboard'),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Government dashboard', style: TextStyle(fontSize: 16)),
              Text(
                constituency?.name ?? constituencyId,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) context.go('/welcome');
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.saffron,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            tabs: [
              Tab(icon: Icon(Icons.space_dashboard_rounded, size: 18), text: 'Overview'),
              Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'Reports'),
              Tab(icon: Icon(Icons.map_rounded, size: 18), text: 'Map'),
              Tab(icon: Icon(Icons.local_fire_department_rounded, size: 18), text: 'Hotspots'),
              Tab(icon: Icon(Icons.emergency_rounded, size: 18), text: 'Emergency'),
              Tab(icon: Icon(Icons.insights_rounded, size: 18), text: 'Analytics'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(constituencyId: constituencyId),
            _ReportsTab(constituencyId: constituencyId),
            const _MapTab(),
            _HotspotsTab(constituencyId: constituencyId),
            _EmergencyTab(constituencyId: constituencyId),
            _AnalyticsTab(constituencyId: constituencyId),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared derivations
// ---------------------------------------------------------------------------

/// The counts every tab reads off the same ticket list, computed once rather
/// than re-walked per widget.
class _Counts {
  _Counts(List<PublicTicketModel> tickets) {
    total = tickets.length;
    for (final t in tickets) {
      switch (t.status) {
        case 'resolved':
          resolved++;
        case 'inProgress':
          inProgress++;
        case 'reviewed':
          reviewed++;
        default:
          fresh++;
      }
      final theme = t.theme ?? 'more';
      byTheme[theme] = (byTheme[theme] ?? 0) + 1;
    }
  }

  int total = 0;
  int fresh = 0;
  int reviewed = 0;
  int inProgress = 0;
  int resolved = 0;
  final Map<String, int> byTheme = {};

  int get open => total - resolved;
  int get resolvedPct => total == 0 ? 0 : ((resolved / total) * 100).round();
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(publicAllTicketsProvider(constituencyId));
    final clustersAsync = ref.watch(publicClustersProvider(constituencyId));

    return ticketsAsync.when(
      data: (tickets) {
        final counts = _Counts(tickets);
        final clusters = clustersAsync.valueOrNull ?? const <PublicClusterModel>[];
        final urgent = clusters.where((c) => c.priorityScore >= 70).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _PrivacyNote(),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  label: 'Open reports',
                  value: '${counts.open}',
                  icon: Icons.folder_open_rounded,
                  tint: AppColors.vermilion,
                ),
                _StatCard(
                  label: 'In progress',
                  value: '${counts.inProgress}',
                  icon: Icons.engineering_rounded,
                  tint: AppColors.saffronDeep,
                ),
                _StatCard(
                  label: 'Resolved',
                  value: '${counts.resolved}',
                  icon: Icons.task_alt_rounded,
                  tint: AppColors.teal,
                ),
                _StatCard(
                  label: 'Resolution rate',
                  value: '${counts.resolvedPct}%',
                  icon: Icons.trending_up_rounded,
                  tint: AppColors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (urgent > 0)
              _Banner(
                icon: Icons.priority_high_rounded,
                tint: AppColors.vermilion,
                title: '$urgent issue${urgent == 1 ? "" : "s"} in the red tier',
                body: 'Priority 70 or above. See the Emergency tab for the '
                    'full list and who to route each one to.',
              ),
            const SizedBox(height: 16),
            const _SectionHeader('Actions'),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.picture_as_pdf_rounded,
              tint: AppColors.vermilion,
              title: 'Generate constituency briefing',
              subtitle: 'AI summary, top issues, departments and cost bands',
              onTap: () => context.go('/official/report'),
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.checklist_rounded,
              tint: AppColors.indigo,
              title: 'Bulk status updates',
              subtitle: 'Mark several reports in progress or resolved at once',
              onTap: () => context.go('/official/tickets'),
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.public_rounded,
              tint: AppColors.teal,
              title: 'Public dashboard',
              subtitle: 'See exactly what citizens see for this constituency',
              onTap: () => context.go('/public/dashboard'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _TabError(what: 'the overview'),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  String _query = '';
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ticketsAsync =
        ref.watch(publicAllTicketsProvider(widget.constituencyId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by token number',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final entry in const <(String?, String)>[
                (null, 'All'),
                ('new', 'New'),
                ('reviewed', 'Reviewed'),
                ('inProgress', 'In progress'),
                ('resolved', 'Resolved'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.$2, style: const TextStyle(fontSize: 12)),
                    selected: _statusFilter == entry.$1,
                    onSelected: (_) =>
                        setState(() => _statusFilter = entry.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            data: (all) {
              final filtered = all.where((t) {
                if (_statusFilter != null && t.status != _statusFilter) {
                  return false;
                }
                if (_query.isEmpty) return true;
                return t.tokenId.toLowerCase().contains(_query.toLowerCase());
              }).toList();
              if (filtered.isEmpty) {
                return const _TabEmpty(
                  message: 'No reports match this filter.',
                  hint: 'Clear the search or pick a different status.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _GovTicketCard(
                  ticket: filtered[i],
                  onStatusChanged: (status) => ref
                      .read(firestoreServiceProvider)
                      .updateSubmissionStatus(filtered[i].id, status),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const _TabError(what: 'the report queue'),
          ),
        ),
      ],
    );
  }
}

/// The full extent of what an official sees about one report: the token
/// number the citizen holds, the AI-written problem summary, the area, and
/// a status control. No identity, by construction — `publicTickets` has no
/// field for one.
class _GovTicketCard extends StatelessWidget {
  const _GovTicketCard({required this.ticket, required this.onStatusChanged});

  final PublicTicketModel ticket;
  final ValueChanged<SubmissionStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final themeId = ticket.theme ?? 'more';
    final tint = categoryColor(themeId);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kThemeIcons[themeId], size: 16, color: tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.tokenId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.indigo,
                      ),
                    ),
                    Text(
                      kThemeLabels[themeId] ?? themeId,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.publicSummary.isEmpty
                ? 'Summary pending review'
                : ticket.publicSummary,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 13, color: AppColors.inkFaint),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _locationLabel(ticket),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkFaint),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<SubmissionStatus>(
                  isDense: true,
                  value: _statusFromString(ticket.status),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                  items: const [
                    DropdownMenuItem(
                        value: SubmissionStatus.newSubmission, child: Text('New')),
                    DropdownMenuItem(
                        value: SubmissionStatus.reviewed, child: Text('Reviewed')),
                    DropdownMenuItem(
                        value: SubmissionStatus.inProgress,
                        child: Text('In progress')),
                    DropdownMenuItem(
                        value: SubmissionStatus.resolved, child: Text('Resolved')),
                  ],
                  onChanged: (s) {
                    if (s != null) onStatusChanged(s);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

SubmissionStatus _statusFromString(String raw) {
  switch (raw) {
    case 'reviewed':
      return SubmissionStatus.reviewed;
    case 'inProgress':
      return SubmissionStatus.inProgress;
    case 'resolved':
      return SubmissionStatus.resolved;
    default:
      return SubmissionStatus.newSubmission;
  }
}

/// The coarsest area label the projection carries. Deliberately never a
/// pincode or a street: `geoPrecision` is at best `approx-300m`, and a
/// precise-looking address next to a blurred point would overstate it.
String _locationLabel(PublicTicketModel ticket) {
  final parts = [
    if ((ticket.wardId ?? '').isNotEmpty) 'Ward ${ticket.wardId}',
    if ((ticket.talukId ?? '').isNotEmpty) 'Taluk ${ticket.talukId}',
    if ((ticket.constituencyName ?? '').isNotEmpty) ticket.constituencyName!,
  ];
  if (parts.isEmpty) return 'Area not resolved';
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------

/// The government map is the same public area map — same polygons, same
/// tappable indicators, same anonymised report list behind each one. There
/// is deliberately no privileged official view: if a location were precise
/// enough to be worth a separate map, it would be precise enough to
/// identify the person who reported it.
class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Banner(
          icon: Icons.map_rounded,
          tint: AppColors.indigo,
          title: 'Area map',
          body: 'District, taluk and ward boundaries, coloured by severity. '
              'Tap any circle to read every report filed in that area.',
        ),
        const SizedBox(height: 14),
        _ActionRow(
          icon: Icons.open_in_full_rounded,
          tint: AppColors.indigo,
          title: 'Open the full map',
          subtitle: 'Boundaries, hotspot circles and booth pins',
          onTap: () => context.go('/public/map'),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Icons.travel_explore_rounded,
          tint: AppColors.teal,
          title: 'Jump to a district or taluk',
          subtitle: 'Frame the map on one area',
          onTap: () => context.go('/public/area'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hotspots
// ---------------------------------------------------------------------------

class _HotspotsTab extends ConsumerWidget {
  const _HotspotsTab({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clustersAsync = ref.watch(publicClustersProvider(constituencyId));
    return clustersAsync.when(
      data: (clusters) {
        if (clusters.isEmpty) {
          return const _TabEmpty(
            message: 'No issue groups tracked yet.',
            hint: 'Hotspots appear once several reports about the same '
                'problem have been filed nearby.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clusters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) =>
              _HotspotCard(rank: i + 1, cluster: clusters[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _TabError(what: 'hotspots'),
    );
  }
}

class _HotspotCard extends StatelessWidget {
  const _HotspotCard({required this.rank, required this.cluster});

  final int rank;
  final PublicClusterModel cluster;

  @override
  Widget build(BuildContext context) {
    final priority = cluster.priorityScore;
    final tint = priority >= 70
        ? AppColors.vermilion
        : priority >= 40
            ? AppColors.saffron
            : AppColors.teal;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => context.go('/public/cluster/${cluster.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('#$rank',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: tint)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cluster.title ?? cluster.summaryText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      priority.toStringAsFixed(0),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniStat(
                      icon: Icons.description_outlined,
                      label: '${cluster.submissionCount} reports'),
                  const SizedBox(width: 14),
                  if (cluster.uniqueReporterCount > 0)
                    _MiniStat(
                        icon: Icons.people_outline_rounded,
                        label: '${cluster.uniqueReporterCount} people'),
                  const Spacer(),
                  if (cluster.recentWeeklySeries.isNotEmpty)
                    SizedBox(
                      width: 62,
                      child: WeeklySparkline(
                        values: cluster.recentWeeklySeries,
                        color: tint,
                        height: 22,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency
// ---------------------------------------------------------------------------

/// Red-tier issues plus the department each one routes to — the "who do I
/// call right now" tab. Departments come from the Solution Card's routing
/// agent, so this is the same answer the citizen sees, not a second one.
class _EmergencyTab extends ConsumerWidget {
  const _EmergencyTab({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clustersAsync = ref.watch(publicClustersProvider(constituencyId));
    final cardsAsync = ref.watch(publicSolutionCardsProvider(constituencyId));

    return clustersAsync.when(
      data: (clusters) {
        final urgent =
            clusters.where((c) => c.priorityScore >= 70).toList();
        final cards = cardsAsync.valueOrNull ?? const <SolutionCardModel>[];
        final cardsByCluster = {for (final c in cards) c.clusterId: c};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Banner(
              icon: Icons.emergency_rounded,
              tint: AppColors.vermilion,
              title: urgent.isEmpty
                  ? 'Nothing in the red tier'
                  : '${urgent.length} issue${urgent.length == 1 ? "" : "s"} '
                      'need attention now',
              body: 'Priority 70 and above, with the department the routing '
                  'agent assigned to each.',
            ),
            const SizedBox(height: 14),
            if (urgent.isEmpty)
              const _TabEmpty(
                message: 'No urgent issues right now.',
                hint: 'Issues appear here the moment their priority crosses '
                    '70.',
              )
            else
              for (final cluster in urgent) ...[
                _EmergencyCard(
                  cluster: cluster,
                  card: cardsByCluster[cluster.id],
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _TabError(what: 'urgent issues'),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.cluster, required this.card});

  final PublicClusterModel cluster;
  final SolutionCardModel? card;

  @override
  Widget build(BuildContext context) {
    final routing = card?.routing;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.vermilion.withValues(alpha: 0.35)),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  size: 17, color: AppColors.vermilion),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cluster.title ?? cluster.summaryText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (routing == null)
            const Text(
              'No department assigned yet — the routing agent has not run '
              'for this issue.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkFaint,
                  fontStyle: FontStyle.italic),
            )
          else ...[
            _KeyValue(label: 'Department', value: routing.primary.name),
            if ((routing.primary.phone ?? '').isNotEmpty)
              _KeyValue(label: 'Phone', value: routing.primary.phone!),
            if ((routing.primary.email ?? '').isNotEmpty)
              _KeyValue(label: 'Email', value: routing.primary.email!),
            if (routing.escalation != null)
              _KeyValue(
                  label: 'Escalate to', value: routing.escalation!.name),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/public/cluster/${cluster.id}'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('Full solution card',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(publicAllTicketsProvider(constituencyId));

    return ticketsAsync.when(
      data: (tickets) {
        if (tickets.isEmpty) {
          return const _TabEmpty(
            message: 'Nothing to analyse yet.',
            hint: 'Charts fill in as reports come in.',
          );
        }
        final counts = _Counts(tickets);
        final themes = counts.byTheme.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Reports per day over the last 14 days present in the data. Keyed
        // on `createdDate` (day granularity) because that is the finest the
        // projection carries — a precise timestamp next to even a blurred
        // location would be a re-identification vector.
        final byDay = <String, int>{};
        for (final t in tickets) {
          if (t.createdDate.isEmpty) continue;
          byDay[t.createdDate] = (byDay[t.createdDate] ?? 0) + 1;
        }
        final days = byDay.keys.toList()..sort();
        final recentDays =
            days.length <= 14 ? days : days.sublist(days.length - 14);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Status breakdown'),
            const SizedBox(height: 10),
            _BarRow(
                label: 'New',
                value: counts.fresh,
                total: counts.total,
                tint: AppColors.inkFaint),
            _BarRow(
                label: 'Reviewed',
                value: counts.reviewed,
                total: counts.total,
                tint: AppColors.indigo),
            _BarRow(
                label: 'In progress',
                value: counts.inProgress,
                total: counts.total,
                tint: AppColors.saffron),
            _BarRow(
                label: 'Resolved',
                value: counts.resolved,
                total: counts.total,
                tint: AppColors.teal),
            const SizedBox(height: 24),
            const _SectionHeader('Reports by category'),
            const SizedBox(height: 10),
            for (final entry in themes)
              _BarRow(
                label: kThemeLabels[entry.key] ?? entry.key,
                value: entry.value,
                total: counts.total,
                tint: categoryColor(entry.key),
              ),
            const SizedBox(height: 24),
            const _SectionHeader('Daily volume'),
            const SizedBox(height: 4),
            const Text(
              'Reports filed per day, most recent on the right.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: appCardShadow,
              ),
              child: WeeklySparkline(
                values: [for (final d in recentDays) byDay[d] ?? 0],
                color: AppColors.indigo,
                height: 70,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _TabError(what: 'analytics'),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.tint,
  });

  final String label;
  final int value;
  final int total;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Text('$value',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: tint)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: tint.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(tint),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealMist,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'You see token numbers, the reported problem and its area. '
              'Names, phone numbers and addresses are never shared with any '
              'office.',
              style: TextStyle(fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 19, color: tint),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: tint)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.inkFaint)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: tint)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.inkFaint)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkFaint)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkFaint),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
      ],
    );
  }
}

class _TabEmpty extends StatelessWidget {
  const _TabEmpty({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                size: 38, color: AppColors.indigoMist),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkFaint, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _TabError extends StatelessWidget {
  const _TabError({required this.what});

  final String what;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text('Could not load $what. Check your connection and retry.',
            textAlign: TextAlign.center),
      ),
    );
  }
}
