import '../models/public_models.dart';

/// How an official's area is doing, from its anonymised `publicTickets`.
class OfficialPerformance {
  const OfficialPerformance({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.resolvedThisWeek,
    required this.avgDaysToResolve,
    required this.medianDaysToResolve,
    required this.overdueOpen,
    required this.weeklyResolved,
  });

  final int total;
  final int open;
  final int inProgress;
  final int resolved;
  final int resolvedThisWeek;

  /// Null until something has been resolved with both dates known.
  final double? avgDaysToResolve;
  final double? medianDaysToResolve;

  /// Open (not resolved) tickets older than 14 days.
  final int overdueOpen;

  /// Resolved per week, oldest first, last 8 weeks.
  final List<int> weeklyResolved;

  int get resolutionRate => total == 0 ? 0 : (resolved * 100 / total).round();
}

DateTime? _day(String? s) =>
    s == null || s.length < 10 ? null : DateTime.tryParse(s.substring(0, 10));

OfficialPerformance computePerformance(
  List<PublicTicketModel> tickets, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  var open = 0, inProgress = 0, resolved = 0, resolvedThisWeek = 0, overdue = 0;
  final durations = <int>[];
  final weekly = List<int>.filled(8, 0);

  for (final t in tickets) {
    final created = _day(t.createdDate);
    switch (t.status) {
      case 'resolved':
        resolved++;
        final done = _day(t.resolvedDate);
        if (done != null) {
          final ago = d0.difference(done).inDays;
          if (ago < 7) resolvedThisWeek++;
          final week = ago ~/ 7;
          if (week >= 0 && week < 8) weekly[7 - week]++;
          if (created != null) durations.add(done.difference(created).inDays.clamp(0, 3650));
        }
      case 'inProgress':
        inProgress++;
        if (created != null && d0.difference(created).inDays > 14) overdue++;
      default:
        open++;
        if (created != null && d0.difference(created).inDays > 14) overdue++;
    }
  }
  durations.sort();
  return OfficialPerformance(
    total: tickets.length,
    open: open,
    inProgress: inProgress,
    resolved: resolved,
    resolvedThisWeek: resolvedThisWeek,
    avgDaysToResolve: durations.isEmpty
        ? null
        : durations.reduce((a, b) => a + b) / durations.length,
    medianDaysToResolve:
        durations.isEmpty ? null : durations[durations.length ~/ 2].toDouble(),
    overdueOpen: overdue,
    weeklyResolved: weekly,
  );
}

/// Responsiveness badges an official can earn.
enum OfficialBadge { firstResolution, resolved10, resolved50, resolved100, quickResponder, zeroBacklog }

extension OfficialBadgeInfo on OfficialBadge {
  String get label => switch (this) {
        OfficialBadge.firstResolution => 'First resolution',
        OfficialBadge.resolved10 => '10 resolved',
        OfficialBadge.resolved50 => '50 resolved',
        OfficialBadge.resolved100 => '100 resolved',
        OfficialBadge.quickResponder => 'Quick responder',
        OfficialBadge.zeroBacklog => 'Zero backlog',
      };

  String get hint => switch (this) {
        OfficialBadge.firstResolution => 'Resolve your first report',
        OfficialBadge.resolved10 => 'Resolve 10 reports',
        OfficialBadge.resolved50 => 'Resolve 50 reports',
        OfficialBadge.resolved100 => 'Resolve 100 reports',
        OfficialBadge.quickResponder => 'Median under 3 days to resolve',
        OfficialBadge.zeroBacklog => 'No report open for over 14 days',
      };
}

/// (badge, earned, progress 0–1).
List<(OfficialBadge, bool, double)> officialBadges(OfficialPerformance p) {
  double prog(int have, int need) => (have / need).clamp(0.0, 1.0);
  final quick = p.medianDaysToResolve != null && p.medianDaysToResolve! < 3 && p.resolved >= 5;
  final noBacklog = p.total > 0 && p.overdueOpen == 0;
  return [
    (OfficialBadge.firstResolution, p.resolved >= 1, prog(p.resolved, 1)),
    (OfficialBadge.resolved10, p.resolved >= 10, prog(p.resolved, 10)),
    (OfficialBadge.resolved50, p.resolved >= 50, prog(p.resolved, 50)),
    (OfficialBadge.resolved100, p.resolved >= 100, prog(p.resolved, 100)),
    (OfficialBadge.quickResponder, quick, quick ? 1 : prog(p.resolved, 5) * 0.5),
    (OfficialBadge.zeroBacklog, noBacklog, noBacklog ? 1 : 0),
  ];
}
