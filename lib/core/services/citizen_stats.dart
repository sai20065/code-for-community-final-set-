/// Personal reporting statistics, derived entirely from a citizen's own
/// submissions.
///
/// Pure functions with no Firestore and no Flutter imports, so they're
/// trivially unit-testable and can be computed from the stream the home
/// screen already watches — no extra reads, no stats document to keep in
/// sync, and it works offline from Firestore's cache.
library;

import '../models/submission_model.dart';

/// A GitHub-style contribution grid.
class ContributionGrid {
  /// Sunday of the first week shown.
  final DateTime startDate;
  final int weeks;

  /// Date-only keys → number of reports that day.
  final Map<DateTime, int> countsByDay;
  final int maxDailyCount;

  const ContributionGrid({
    required this.startDate,
    required this.weeks,
    required this.countsByDay,
    required this.maxDailyCount,
  });

  int countFor(DateTime day) =>
      countsByDay[DateTime(day.year, day.month, day.day)] ?? 0;

  /// Intensity bucket 0–4 for a day's cell.
  int levelFor(DateTime day) {
    final count = countFor(day);
    if (count == 0) return 0;
    if (maxDailyCount <= 1) return 4;
    final ratio = count / maxDailyCount;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  bool get isEmpty => countsByDay.isEmpty;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Start of the ISO week (Monday) containing [d].
DateTime _weekStart(DateTime d) {
  final date = _dateOnly(d);
  return date.subtract(Duration(days: date.weekday - 1));
}

ContributionGrid buildContributionGrid(
  List<SubmissionModel> submissions, {
  int weeks = 26,
  DateTime? today,
}) {
  final now = _dateOnly(today ?? DateTime.now());
  final start = _weekStart(now).subtract(Duration(days: (weeks - 1) * 7));

  final counts = <DateTime, int>{};
  var max = 0;
  for (final s in submissions) {
    final day = _dateOnly(s.createdAt);
    if (day.isBefore(start) || day.isAfter(now)) continue;
    final next = (counts[day] ?? 0) + 1;
    counts[day] = next;
    if (next > max) max = next;
  }

  return ContributionGrid(
    startDate: start,
    weeks: weeks,
    countsByDay: counts,
    maxDailyCount: max,
  );
}

/// Reporting consistency.
///
/// **Streaks are measured in weeks, not days, deliberately.** A streak that
/// resets unless you report *today* rewards filing something — anything —
/// every day, and the predictable result is junk tickets that make the data
/// worse for everyone. Weekly is a genuine signal of an engaged resident and
/// carries no incentive to invent problems. The contribution grid still
/// shows daily dots, because that's the visual people recognise; the number
/// anyone optimises is the weekly one.
class StreakStats {
  final int currentWeeks;
  final int longestWeeks;
  final int activeWeeks;
  final int totalReports;

  const StreakStats({
    this.currentWeeks = 0,
    this.longestWeeks = 0,
    this.activeWeeks = 0,
    this.totalReports = 0,
  });
}

StreakStats computeStreaks(
  List<SubmissionModel> submissions, {
  DateTime? today,
}) {
  final now = _dateOnly(today ?? DateTime.now());
  final weeksWithReports = <DateTime>{};
  for (final s in submissions) {
    weeksWithReports.add(_weekStart(s.createdAt));
  }
  if (weeksWithReports.isEmpty) {
    return StreakStats(totalReports: submissions.length);
  }

  final sorted = weeksWithReports.toList()..sort();

  var longest = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]).inDays;
    if (gap == 7) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }

  // The current streak counts back from this week — or from last week, so
  // that someone who simply hasn't reported yet on a Monday morning doesn't
  // watch their streak evaporate.
  final thisWeek = _weekStart(now);
  final lastWeek = thisWeek.subtract(const Duration(days: 7));
  var cursor = weeksWithReports.contains(thisWeek)
      ? thisWeek
      : (weeksWithReports.contains(lastWeek) ? lastWeek : null);

  var current = 0;
  while (cursor != null && weeksWithReports.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 7));
  }

  return StreakStats(
    currentWeeks: current,
    longestWeeks: longest,
    activeWeeks: weeksWithReports.length,
    totalReports: submissions.length,
  );
}

/// A personal milestone, deliberately **not** a competitive ranking.
///
/// Levels compare a citizen to their own past, never to their neighbours. A
/// leaderboard of who reports most would reward volume over substance in a
/// system where each report is meant to cost the filer some thought.
class CitizenLevel {
  final int level;

  /// l10n key suffix, e.g. `levelName2`.
  final int reportsToNext;
  final double progress;
  final int totalReports;

  const CitizenLevel({
    required this.level,
    required this.reportsToNext,
    required this.progress,
    required this.totalReports,
  });

  bool get isMaxLevel => reportsToNext == 0;
}

const _levelThresholds = [1, 5, 15, 40, 100];

CitizenLevel computeLevel(int totalReports) {
  var level = 0;
  for (final threshold in _levelThresholds) {
    if (totalReports >= threshold) level++;
  }
  level = level.clamp(1, _levelThresholds.length);

  if (level >= _levelThresholds.length) {
    return CitizenLevel(
      level: level,
      reportsToNext: 0,
      progress: 1,
      totalReports: totalReports,
    );
  }

  final currentFloor = _levelThresholds[level - 1];
  final nextFloor = _levelThresholds[level];
  final span = nextFloor - currentFloor;
  final into = (totalReports - currentFloor).clamp(0, span);

  return CitizenLevel(
    level: level,
    reportsToNext: nextFloor - totalReports,
    progress: span == 0 ? 1 : into / span,
    totalReports: totalReports,
  );
}

/// Badge ids. Every one is derivable from the citizen's own submissions —
/// no server trigger, no extra collection, nothing to go stale.
enum BadgeId {
  firstReport,
  weekStreak,
  monthActive,
  multiTheme,
  resolvedTen,
  photoReporter,
  voiceReporter,
}

class CitizenBadge {
  final BadgeId id;
  final bool earned;

  /// How far along the citizen is, 0–1. Lets the UI show "3 of 5" progress
  /// on a locked badge instead of a flat grey square.
  final double progress;

  const CitizenBadge({
    required this.id,
    required this.earned,
    this.progress = 0,
  });
}

List<CitizenBadge> computeBadges(
  List<SubmissionModel> submissions, {
  DateTime? today,
}) {
  final streaks = computeStreaks(submissions, today: today);
  final total = submissions.length;

  final distinctThemes =
      submissions.map((s) => s.theme).whereType<String>().toSet().length;
  final resolved = submissions
      .where((s) => s.status == SubmissionStatus.resolved)
      .length;
  final photos =
      submissions.where((s) => s.type == SubmissionType.photo).length;
  final voices =
      submissions.where((s) => s.type == SubmissionType.voice).length;

  CitizenBadge make(BadgeId id, int have, int need) => CitizenBadge(
        id: id,
        earned: have >= need,
        progress: need == 0 ? 1 : (have / need).clamp(0.0, 1.0),
      );

  return [
    make(BadgeId.firstReport, total, 1),
    make(BadgeId.weekStreak, streaks.longestWeeks, 2),
    make(BadgeId.monthActive, streaks.longestWeeks, 4),
    make(BadgeId.multiTheme, distinctThemes, 3),
    make(BadgeId.resolvedTen, resolved, 10),
    make(BadgeId.photoReporter, photos, 5),
    make(BadgeId.voiceReporter, voices, 5),
  ];
}
