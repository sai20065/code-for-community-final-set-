import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/services/citizen_stats.dart';
import '../../l10n/app_localizations.dart';

/// Current streak / longest streak / total reports.
///
/// Note all three numbers are measured in **weeks**, not days. See the note
/// on [StreakStats]: a daily streak manufactures junk tickets, because the
/// cheapest way to keep it alive is to file something rather than to notice
/// something.
class StreakBadgeRow extends StatelessWidget {
  const StreakBadgeRow({super.key, required this.stats, this.compact = false});

  final StreakStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatBlock(
            value: '${stats.currentWeeks}',
            label: l10n.activeWeeksStreak,
            color: AppColors.saffronDeep,
            icon: stats.currentWeeks > 0 ? Icons.local_fire_department_rounded : null,
            compact: compact,
          ),
        ),
        Expanded(
          child: _StatBlock(
            value: '${stats.longestWeeks}',
            label: l10n.longestStreak,
            color: AppColors.indigo,
            compact: compact,
          ),
        ),
        Expanded(
          child: _StatBlock(
            value: '${stats.totalReports}',
            label: l10n.totalReports,
            color: AppColors.teal,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 14 : 16, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 9.5 : 10.5,
            color: AppColors.inkFaint,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Progress toward the next personal milestone.
///
/// A milestone, not a ranking — the citizen is compared to their own past,
/// never to their neighbours. A public leaderboard of who reports most would
/// reward volume in a system where each report is supposed to cost the filer
/// some thought.
class LevelProgressBar extends StatelessWidget {
  const LevelProgressBar({super.key, required this.level});

  final CitizenLevel level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.saffron.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.levelLabel(level.level),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.saffronDeep,
                ),
              ),
            ),
            const Spacer(),
            Text(
              level.isMaxLevel
                  ? l10n.levelMaxReached
                  : l10n.reportsToNextLevel(level.reportsToNext),
              style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: LinearProgressIndicator(
            value: level.progress,
            minHeight: 7,
            backgroundColor: AppColors.inkFaint.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(AppColors.saffron),
          ),
        ),
      ],
    );
  }
}

/// Earned badges in colour, unearned greyed with their progress.
///
/// Showing "3 of 5" on a locked badge rather than a flat grey square is the
/// difference between a goal and a scold.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.badges});

  final List<CitizenBadge> badges;

  static const _icons = <BadgeId, IconData>{
    BadgeId.firstReport: Icons.flag_rounded,
    BadgeId.weekStreak: Icons.local_fire_department_rounded,
    BadgeId.monthActive: Icons.calendar_month_rounded,
    BadgeId.multiTheme: Icons.category_rounded,
    BadgeId.resolvedTen: Icons.task_alt_rounded,
    BadgeId.photoReporter: Icons.photo_camera_rounded,
    BadgeId.voiceReporter: Icons.mic_rounded,
  };

  String _label(BadgeId id, AppLocalizations l10n) {
    switch (id) {
      case BadgeId.firstReport:
        return l10n.badgeFirstReport;
      case BadgeId.weekStreak:
        return l10n.badgeWeekStreak;
      case BadgeId.monthActive:
        return l10n.badgeMonthActive;
      case BadgeId.multiTheme:
        return l10n.badgeMultiTheme;
      case BadgeId.resolvedTen:
        return l10n.badgeResolvedTen;
      case BadgeId.photoReporter:
        return l10n.badgePhotoReporter;
      case BadgeId.voiceReporter:
        return l10n.badgeVoiceReporter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final badge in badges)
          Tooltip(
            message: badge.earned
                ? _label(badge.id, l10n)
                : '${_label(badge.id, l10n)} · ${l10n.badgeLockedHint}',
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: badge.earned
                          ? AppColors.indigo.withValues(alpha: 0.14)
                          : AppColors.inkFaint.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _icons[badge.id],
                      size: 20,
                      color: badge.earned
                          ? AppColors.indigo
                          : AppColors.inkFaint.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _label(badge.id, l10n),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      height: 1.2,
                      fontWeight: badge.earned ? FontWeight.w700 : FontWeight.w400,
                      color: badge.earned ? AppColors.ink : AppColors.inkFaint,
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
