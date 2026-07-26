import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/services/citizen_stats.dart';

/// Five steps from the palette's lightest indigo to its deepest, for a
/// grid cell's intensity bucket (0–4). Uses the app's own tokens rather than
/// GitHub's green so the grid reads as part of this product.
///
/// Top-level so [ConsistencyLegend] can render the same scale without
/// needing a grid to ask.
Color consistencyLevelColor(int level) {
  switch (level) {
    case 0:
      return AppColors.inkFaint.withValues(alpha: 0.12);
    case 1:
      return AppColors.indigo.withValues(alpha: 0.25);
    case 2:
      return AppColors.indigo.withValues(alpha: 0.45);
    case 3:
      return AppColors.indigo.withValues(alpha: 0.70);
    default:
      return AppColors.indigoDeep;
  }
}

/// A GitHub-style contribution grid of a citizen's own reporting activity.
///
/// Seven rows (Mon–Sun) by N week columns, scrollable horizontally so it
/// never forces the page to. Built from plain `Container`s rather than a
/// `CustomPaint` — a few hundred small boxes is well within Flutter's
/// comfort zone, and it keeps per-cell tooltips and semantics for free,
/// which a painter would have to reimplement.
class ConsistencyMap extends StatelessWidget {
  const ConsistencyMap({
    super.key,
    required this.grid,
    this.cellSize = 11,
    this.cellGap = 3,
  });

  final ContributionGrid grid;
  final double cellSize;
  final double cellGap;

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final columns = <Widget>[];
    final monthHeaders = <Widget>[];
    var lastMonth = -1;

    for (var week = 0; week < grid.weeks; week++) {
      final weekStart = grid.startDate.add(Duration(days: week * 7));

      // One label per month, above the week its month begins in.
      final showLabel = weekStart.month != lastMonth;
      lastMonth = weekStart.month;
      monthHeaders.add(SizedBox(
        width: cellSize + cellGap,
        child: showLabel
            ? Text(
                _monthLabels[weekStart.month - 1],
                style: const TextStyle(
                    fontSize: 8, color: AppColors.inkFaint),
                overflow: TextOverflow.visible,
                softWrap: false,
              )
            : const SizedBox.shrink(),
      ));

      columns.add(Padding(
        padding: EdgeInsets.only(right: cellGap),
        child: Column(
          children: [
            for (var day = 0; day < 7; day++)
              _Cell(
                day: weekStart.add(Duration(days: day)),
                grid: grid,
                size: cellSize,
                gap: cellGap,
                color: consistencyLevelColor(
                    grid.levelFor(weekStart.add(Duration(days: day)))),
              ),
          ],
        ),
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Newest weeks are the interesting ones, so start scrolled to them.
      reverse: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: monthHeaders),
            const SizedBox(height: 3),
            Row(children: columns),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.grid,
    required this.size,
    required this.gap,
    required this.color,
  });

  final DateTime day;
  final ContributionGrid grid;
  final double size;
  final double gap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final count = grid.countFor(day);
    final dateLabel = '${day.year}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final message = count == 0 ? dateLabel : '$dateLabel · $count';

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Tooltip(
        message: message,
        waitDuration: const Duration(milliseconds: 400),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}

/// The colour scale, so the grid's shading means something.
class ConsistencyLegend extends StatelessWidget {
  const ConsistencyLegend({super.key, required this.lessLabel, required this.moreLabel});

  final String lessLabel;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(lessLabel,
            style: const TextStyle(fontSize: 9, color: AppColors.inkFaint)),
        const SizedBox(width: 4),
        for (var level = 0; level < 5; level++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: consistencyLevelColor(level),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text(moreLabel,
            style: const TextStyle(fontSize: 9, color: AppColors.inkFaint)),
      ],
    );
  }
}
