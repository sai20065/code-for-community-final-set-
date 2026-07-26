import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Section 5.4: bar chart (tickets by theme) + line chart (trend over
/// time) — max 2 chart types visible at once.
///
/// Public: both charts are built entirely from `publicClusters` (theme
/// totals and each cluster's `weeklyCounts`), never from a per-day scan of
/// `submissions` — which the public dashboard can't read, and which the
/// previous version of this screen queried fourteen times on every load.
class ThemesOverviewScreen extends ConsumerWidget {
  const ThemesOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final constituencyId = ref.watch(effectivePublicConstituencyProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/public/dashboard'),
        ),
        title: Text(l10n.themesOverview),
      ),
      body: SafeArea(
        child: constituencyId == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.chooseConstituency, textAlign: TextAlign.center),
                ),
              )
            : _ThemesBody(constituencyId: constituencyId),
      ),
    );
  }
}

class _ThemesBody extends ConsumerWidget {
  const _ThemesBody({required this.constituencyId});

  final String constituencyId;

  /// Sums each cluster's `weeklyCounts` into a single constituency-wide
  /// series, last 8 ISO weeks. All the granularity this needs — and all the
  /// granularity `publicClusters` publishes on purpose.
  List<double> _weeklySeries(List clusters) {
    final totals = <String, double>{};
    for (final c in clusters) {
      c.weeklyCounts.forEach((week, count) {
        totals[week] = (totals[week] ?? 0) + count;
      });
    }
    final weeks = totals.keys.toList()..sort();
    final recent = weeks.length <= 8 ? weeks : weeks.sublist(weeks.length - 8);
    return [for (final w in recent) totals[w] ?? 0];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clustersAsync = ref.watch(publicClustersProvider(constituencyId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.ticketsByTheme, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        clustersAsync.when(
          data: (clusters) {
            final themeCounts = <String, double>{};
            for (final c in clusters) {
              themeCounts[c.theme] =
                  (themeCounts[c.theme] ?? 0) + c.submissionCount;
            }
            if (themeCounts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.noClusteredTickets,
                    style: const TextStyle(color: Colors.grey)),
              );
            }
            final themeIds = themeCounts.keys.toList();
            return SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final id = themeIds[value.toInt() % themeIds.length];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(kThemeIcons[id], size: 16,
                                color: categoryColor(id)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < themeIds.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: themeCounts[themeIds[i]]!,
                          color: categoryColor(themeIds[i]),
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ]),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Text(l10n.couldNotLoadThemes),
        ),
        const SizedBox(height: 28),
        Text(l10n.weeklyTrend, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: clustersAsync.when(
            data: (clusters) {
              final series = _weeklySeries(clusters);
              if (series.isEmpty) {
                return Center(
                  child: Text(l10n.noClusteredTickets,
                      style: const TextStyle(color: Colors.grey)),
                );
              }
              return LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < series.length; i++)
                          FlSpot(i.toDouble(), series[i]),
                      ],
                      isCurved: true,
                      color: AppColors.indigo,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.indigo.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text(l10n.couldNotLoadThemes),
          ),
        ),
      ],
    );
  }
}
