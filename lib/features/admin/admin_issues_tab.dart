import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/work_providers.dart';
import '../../app/theme.dart';
import '../../core/services/work_service.dart';
import '../official/work/assign_sheet.dart';

/// Admin-only: similar issues grouped by place, type and other parameters,
/// with bulk assign and close. Reads through `getAdminIssueGroups`, which
/// returns summaries and tokens, never who reported.
class AdminIssuesTab extends ConsumerStatefulWidget {
  const AdminIssuesTab({super.key});

  @override
  ConsumerState<AdminIssuesTab> createState() => _AdminIssuesTabState();
}

class _AdminIssuesTabState extends ConsumerState<AdminIssuesTab> {
  static const _groupKeys = <(String, String)>[
    ('district', 'District'),
    ('taluk', 'Taluk'),
    ('assembly', 'Constituency'),
    ('theme', 'Type'),
    ('status', 'Status'),
    ('assigned', 'Assigned to'),
  ];

  final Set<String> _groupBy = {'district', 'theme'};
  String? _status;
  String? _assigned; // 'yes' | 'no'
  bool _closeable = false;
  bool _reopened = false;
  int? _minAgeDays;

  Future<IssueOverview>? _future;
  String? _openKey;
  Future<IssueOverview>? _openFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Map<String, dynamic> get _filters => {
        if (_status != null) 'status': _status,
        if (_assigned != null) 'assigned': _assigned,
        if (_closeable) 'closeable': true,
        if (_reopened) 'reopened': true,
        if (_minAgeDays != null) 'minAgeDays': _minAgeDays,
      };

  List<String> get _keys => [
        for (final k in _groupKeys)
          if (_groupBy.contains(k.$1)) k.$1,
      ];

  void _reload() {
    setState(() {
      _openKey = null;
      _openFuture = null;
      _future = ref
          .read(workServiceProvider)
          .adminIssues(groupBy: _keys.isEmpty ? ['theme'] : _keys, filters: _filters);
    });
  }

  void _open(IssueGroup g) {
    setState(() {
      if (_openKey == g.key) {
        _openKey = null;
        _openFuture = null;
        return;
      }
      _openKey = g.key;
      _openFuture = ref.read(workServiceProvider).adminIssues(
            groupBy: _keys.isEmpty ? ['theme'] : _keys,
            filters: _filters,
            openGroup: g.key,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _filterPanel(),
          const SizedBox(height: 12),
          FutureBuilder<IssueOverview>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError || snap.data == null) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load the issue groups. Pull to retry.'),
                );
              }
              final o = snap.data!;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _totals(o),
                if (o.capped)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Showing the latest 2,000 problem reports.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
                  ),
                const SizedBox(height: 12),
                if (o.groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No reports match these filters.', textAlign: TextAlign.center),
                  ),
                for (final g in o.groups) _groupCard(g),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Group by', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final k in _groupKeys)
            FilterChip(
              label: Text(k.$2, style: const TextStyle(fontSize: 12)),
              selected: _groupBy.contains(k.$1),
              onSelected: (on) {
                if (on && _groupBy.length >= 3) return;
                if (!on && _groupBy.length == 1) return;
                setState(() => on ? _groupBy.add(k.$1) : _groupBy.remove(k.$1));
                _reload();
              },
            ),
        ]),
        const SizedBox(height: 8),
        const Text('Show only', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          _choice('Unassigned', _assigned == 'no', (on) => _assigned = on ? 'no' : null),
          _choice('Assigned', _assigned == 'yes', (on) => _assigned = on ? 'yes' : null),
          _choice('Closeable now', _closeable, (on) => _closeable = on),
          _choice('Citizen said not fixed', _reopened, (on) => _reopened = on),
          _choice('Older than 7 days', _minAgeDays == 7, (on) => _minAgeDays = on ? 7 : null),
          _choice('Open', _status == 'new', (on) => _status = on ? 'new' : null),
          _choice('In progress', _status == 'inProgress', (on) => _status = on ? 'inProgress' : null),
          _choice('Fixed, awaiting citizen', _status == 'resolved', (on) => _status = on ? 'resolved' : null),
        ]),
      ]),
    );
  }

  Widget _choice(String label, bool selected, void Function(bool) apply) => ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (on) {
          setState(() => apply(on));
          _reload();
        },
      );

  Widget _totals(IssueOverview o) {
    Widget tile(String label, int? v, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('${v ?? 0}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
              Text(label, style: const TextStyle(fontSize: 10.5), textAlign: TextAlign.center),
            ]),
          ),
        );
    return Row(children: [
      tile('Reports', o.totals['tickets'], AppColors.indigo),
      tile('Open', o.totals['open'], AppColors.saffronDeep),
      tile('Unassigned', o.totals['unassigned'], AppColors.vermilion),
      tile('Closeable', o.totals['closeable'], AppColors.tealDeep),
    ]);
  }

  Widget _groupCard(IssueGroup g) {
    final fixedShare = g.count == 0 ? 0.0 : g.fixed / g.count;
    final open = _openKey == g.key;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => _open(g),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(g.title.isEmpty ? 'All reports' : g.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fixedShare,
                  minHeight: 6,
                  color: AppColors.teal,
                  backgroundColor: AppColors.indigoMist,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 4, children: [
                _stat('${g.count} reports'),
                _stat('${g.open} open'),
                _stat('${g.fixed} fixed'),
                _stat('${g.unassigned} unassigned', warn: g.unassigned > 0),
                _stat('avg ${g.avgAgeDays.toStringAsFixed(0)} days old'),
                if (g.closeable > 0) _stat('${g.closeable} ready to close'),
                if (g.reopened > 0) _stat('${g.reopened} reopened', warn: true),
              ]),
            ]),
          ),
        ),
        if (open) _tickets(),
      ]),
    );
  }

  Widget _stat(String text, {bool warn = false}) => Text(text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: warn ? FontWeight.w800 : FontWeight.w500,
          color: warn ? AppColors.vermilion : AppColors.inkFaint));

  Widget _tickets() {
    return FutureBuilder<IssueOverview>(
      future: _openFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        final list = snap.data?.tickets ?? const <IssueTicket>[];
        if (list.isEmpty) {
          return const Padding(padding: EdgeInsets.all(16), child: Text('No tickets to show.'));
        }
        final unassigned = [
          for (final t in list)
            if (t.assignedTo == null && t.status != 'resolved' && t.status != 'closed') t.id
        ];
        final closeable = [
          for (final t in list)
            if (t.closeState == 'closeable') t.id
        ];
        return Column(children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text('Assign ${unassigned.length} unassigned'),
                onPressed: unassigned.isEmpty
                    ? null
                    : () async {
                        if (await showAssignSheet(context, ticketIds: unassigned)) _reload();
                      },
              ),
              TextButton.icon(
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text('Close ${closeable.length} ready'),
                onPressed: closeable.isEmpty ? null : () => _closeAll(closeable),
              ),
            ]),
          ),
          for (final t in list.take(60)) _ticketRow(t),
          if (list.length > 60)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Showing 60 of ${list.length}.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
            ),
        ]);
      },
    );
  }

  Future<void> _closeAll(List<String> ids) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await ref.read(workServiceProvider).close(ids);
      messenger.showSnackBar(SnackBar(content: Text('Closed $n ${n == 1 ? 'ticket' : 'tickets'}.')));
      _reload();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not close. Try again.')));
    }
  }

  Widget _ticketRow(IssueTicket t) {
    final label = switch (t.status) {
      'reviewed' => 'Assigned',
      'inProgress' => 'In progress',
      'resolved' => t.closeState == 'closeable' ? 'Fixed · ready to close' : 'Fixed · awaiting citizen',
      'closed' => 'Closed',
      _ => 'New',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(t.tokenId,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.indigo)),
          const Spacer(),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor(t.status))),
        ]),
        Text(t.summary.isEmpty ? t.theme : t.summary,
            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
        Text(
            '${[t.taluk, t.district].where((s) => s.isNotEmpty && s != 'unknown').join(', ')} · ${t.ageDays} days old'
            '${t.assignedTo != null ? ' · ${t.assignedTo}' : ''}${t.reopened ? ' · reopened' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
      ]),
    );
  }
}
