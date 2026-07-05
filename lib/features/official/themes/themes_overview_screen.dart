import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Section 5.4: bar chart (submissions by theme) + line chart (trend over
/// time) — max 2 chart types visible at once (Section 3.8 progressive
/// disclosure for time-poor officials).
class ThemesOverviewScreen extends StatelessWidget {
  const ThemesOverviewScreen({super.key});

  static const _themeCounts = {
    'roads': 24.0,
    'water': 15.0,
    'electricity': 18.0,
    'health': 6.0,
    'sanitation': 11.0,
    'education': 4.0,
  };

  static const _weeklyTrend = [8.0, 12.0, 9.0, 15.0, 11.0, 18.0, 14.0];

  @override
  Widget build(BuildContext context) {
    final themeIds = _themeCounts.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Themes Overview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Submissions by theme',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
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
                          toY: _themeCounts[themeIds[i]]!,
                          color: categoryColor(themeIds[i]),
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Weekly trend',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < _weeklyTrend.length; i++)
                          FlSpot(i.toDouble(), _weeklyTrend[i]),
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
        ),
      ),
    );
  }
}
