import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/cluster_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Section 5.4: bar chart (tickets by theme) + line chart (trend over
/// time) — max 2 chart types visible at once. Bar chart reads live
/// `clusters` data (populated by the Gemini pipeline); the weekly trend
/// reads live per-day ticket counts. Scoped to the signed-in official's own
/// constituency.
class ThemesOverviewScreen extends ConsumerWidget {
  const ThemesOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Themes Overview')),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            final constituencyId = profile?.constituencyId;
            if (constituencyId == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Your account isn\'t linked to a constituency yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _ThemesBody(constituencyId: constituencyId);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Could not load your profile.')),
        ),
      ),
    );
  }
}

class _ThemesBody extends ConsumerStatefulWidget {
  const _ThemesBody({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_ThemesBody> createState() => _ThemesBodyState();
}

class _ThemesBodyState extends ConsumerState<_ThemesBody> {
  List<double>? _weeklyTrend;

  @override
  void initState() {
    super.initState();
    _loadWeeklyTrend();
  }

  Future<void> _loadWeeklyTrend() async {
    final service = ref.read(firestoreServiceProvider);
    final now = DateTime.now();
    final counts = <double>[];
    for (var i = 6; i >= 0; i--) {
      final dayStart = DateTime(now.year, now.month, now.day - i);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final startCount =
          await service.countSubmissionsSince(widget.constituencyId, dayStart);
      final endCount =
          await service.countSubmissionsSince(widget.constituencyId, dayEnd);
      counts.add((startCount - endCount).toDouble().abs());
    }
    if (mounted) setState(() => _weeklyTrend = counts);
  }

  @override
  Widget build(BuildContext context) {
    final clustersAsync = ref.watch(_clustersProvider(widget.constituencyId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tickets by theme', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        clustersAsync.when(
          data: (clusters) {
            final themeCounts = <String, double>{};
            for (final c in clusters) {
              themeCounts[c.theme] =
                  (themeCounts[c.theme] ?? 0) + c.submissionCount;
            }
            if (themeCounts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No clustered tickets yet.',
                    style: TextStyle(color: Colors.grey)),
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
          error: (_, __) => const Text('Could not load themes.'),
        ),
        const SizedBox(height: 28),
        Text('Weekly trend', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _weeklyTrend == null
              ? const Center(child: CircularProgressIndicator())
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < _weeklyTrend!.length; i++)
                            FlSpot(i.toDouble(), _weeklyTrend![i]),
                        ],
                        isCurved: true,
                        color: AppColors.trustBlue,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.trustBlue.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

final _clustersProvider =
    StreamProvider.family<List<ClusterModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchClustersForConstituency(constituencyId);
});
