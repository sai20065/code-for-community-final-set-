import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A tiny axis-less trend line over a cluster's weekly report counts.
///
/// Deliberately unlabelled: at this size a reader can only take away shape —
/// rising, falling, spiky — and adding axes would imply a precision the
/// 40-pixel height can't deliver. The exact numbers live on the detail
/// screen.
class WeeklySparkline extends StatelessWidget {
  const WeeklySparkline({
    super.key,
    required this.values,
    this.color = AppColors.indigo,
    this.height = 38,
  });

  final List<int> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    // One point can't show a trend, and a straight line drawn from a single
    // week would read as "flat" rather than "not enough data yet".
    if (values.length < 2) return SizedBox(height: height);

    final maxValue =
        values.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 1e9);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxValue * 1.15,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i].toDouble()),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.0),
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
