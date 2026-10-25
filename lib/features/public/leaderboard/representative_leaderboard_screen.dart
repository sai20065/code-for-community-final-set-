import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/representative_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/share_actions.dart';
import '../map/area_reports_sheet.dart';

/// MLAs and MPs ranked by how many of the problems reported in their area
/// were fixed. Built server-side every 6 hours from public tickets only
/// (functions/src/public/leaderboard.ts) — trial data never counts, vacant
/// seats and seats with too few reports are listed but not ranked, and
/// party is deliberately not shown.
class RepresentativeLeaderboardScreen extends StatelessWidget {
  const RepresentativeLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/public/karnataka'),
          ),
          title: Text(l10n.leaderboardTitle),
          bottom: TabBar(tabs: [Tab(text: l10n.leaderboardMlaTab), Tab(text: l10n.leaderboardMpTab)]),
        ),
        body: const TabBarView(children: [
          LeaderboardList(board: 'mla'),
          LeaderboardList(board: 'mp'),
        ]),
      ),
    );
  }
}

/// The share text for one representative's row.
SharePost leaderboardSharePost(AppLocalizations l10n, LeaderboardRow r, int windowDays) {
  final name = r.vacant ? l10n.seatVacant : (r.name ?? l10n.repNotRecorded);
  return SharePost(
    text: l10n.shareLeaderboardRow(name, r.seat, _pct(r.fixedPct), r.reports, windowDays, r.open),
    url: publicWebLink('/public/leaderboard'),
  );
}

String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class LeaderboardList extends ConsumerWidget {
  const LeaderboardList({super.key, required this.board});

  final String board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(leaderboardProvider(board));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
      data: (lb) {
        final data = lb ?? const RepresentativeLeaderboard();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.indigoMist,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                l10n.leaderboardFairness(data.windowDays, data.minReports),
                style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.indigoDeep),
              ),
            ),
            const SizedBox(height: 12),
            if (data.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(l10n.leaderboardEmpty(data.windowDays),
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
              ),
            for (final r in data.ranked) _RowTile(row: r, board: board, windowDays: data.windowDays),
            if (data.unranked.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                child: Text(l10n.notEnoughReports.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
              ),
              for (final r in data.unranked) _RowTile(row: r, board: board, windowDays: data.windowDays),
            ],
          ],
        );
      },
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.board, required this.windowDays});

  final LeaderboardRow row;
  final String board;
  final int windowDays;

  void _openDetails(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = row;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.vacant ? l10n.seatVacant : (r.name ?? l10n.repNotRecorded),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${board == 'mla' ? l10n.mlaLabel : l10n.mpLabel} · ${r.seat}',
                  style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 12),
              Text(l10n.fixedPctLabel(_pct(r.fixedPct)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(l10n.leaderboardStats(r.reports, r.open)),
              if (r.medianDaysToFix != null) Text(l10n.medianFixDays(r.medianDaysToFix!)),
              const SizedBox(height: 16),
              ShareActions(post: leaderboardSharePost(l10n, r, windowDays)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AreaReportsSheet(
                      areaName: r.seat,
                      ticketField: board == 'mla' ? 'assemblyId' : 'constituencyId',
                      areaId: r.repId,
                      reportCount: r.reports,
                      icon: Icons.how_to_vote_rounded,
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt_rounded),
                label: Text(l10n.seeReportsInArea),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = row;
    final ranked = r.rank != null;
    final barColor = r.fixedPct >= 60
        ? AppColors.teal
        : r.fixedPct >= 30
            ? AppColors.saffronDeep
            : AppColors.vermilion;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(ranked ? '#${r.rank}' : '—',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ranked ? AppColors.indigoDeep : AppColors.inkFaint)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.vacant ? l10n.seatVacant : (r.name ?? l10n.repNotRecorded),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(r.seat, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (r.fixedPct / 100).clamp(0, 1),
                        minHeight: 6,
                        color: barColor,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${l10n.fixedPctLabel(_pct(r.fixedPct))} · ${l10n.leaderboardStats(r.reports, r.open)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
