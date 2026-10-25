import 'package:cloud_firestore/cloud_firestore.dart';

/// One elected representative's seat, from `publicReps/karnataka`.
class RepresentativeEntry {
  final String id;
  final String seat;

  /// Null when the seat is vacant or the roster has no name for it.
  final String? name;
  final bool vacant;

  const RepresentativeEntry({
    required this.id,
    required this.seat,
    this.name,
    this.vacant = false,
  });

  factory RepresentativeEntry.fromMap(String id, Map<String, dynamic> map) => RepresentativeEntry(
        id: id,
        seat: map['seat'] as String? ?? id,
        name: (map['name'] as String?)?.trim().isEmpty ?? true ? null : map['name'] as String,
        vacant: map['vacant'] == true,
      );
}

/// Who represents each Karnataka seat, plus GBA ward names — one small doc
/// (`publicReps/karnataka`, written by `seedMlaRoster.ts`) read once per
/// session instead of the polygon-heavy `assemblies/*` docs.
class PublicReps {
  final String? rosterAsOf;
  final Map<String, RepresentativeEntry> mla;
  final Map<String, RepresentativeEntry> mp;
  final Map<String, String> wardNames;

  const PublicReps({
    this.rosterAsOf,
    this.mla = const {},
    this.mp = const {},
    this.wardNames = const {},
  });

  static const empty = PublicReps();

  factory PublicReps.fromMap(Map<String, dynamic> map) {
    Map<String, RepresentativeEntry> index(Object? raw) => {
          for (final e in ((raw as Map?)?.cast<String, dynamic>() ?? const {}).entries)
            e.key: RepresentativeEntry.fromMap(e.key, (e.value as Map).cast<String, dynamic>()),
        };
    return PublicReps(
      rosterAsOf: map['rosterAsOf'] as String?,
      mla: index(map['mla']),
      mp: index(map['mp']),
      wardNames: ((map['wardNames'] as Map?)?.cast<String, dynamic>() ?? const {})
          .map((k, v) => MapEntry(k, '$v')),
    );
  }
}

/// One representative's row on the leaderboard (`publicLeaderboards/*`).
class LeaderboardRow {
  final String repId;
  final String? name;
  final String seat;
  final bool vacant;
  final int reports;
  final int open;
  final int fixed;
  final double fixedPct;
  final int? medianDaysToFix;
  final int? oldestOpenDays;

  /// Null: not ranked (too few reports, or a vacant seat).
  final int? rank;

  const LeaderboardRow({
    required this.repId,
    required this.seat,
    required this.reports,
    required this.open,
    required this.fixed,
    required this.fixedPct,
    this.name,
    this.vacant = false,
    this.medianDaysToFix,
    this.oldestOpenDays,
    this.rank,
  });

  factory LeaderboardRow.fromMap(Map<String, dynamic> map) => LeaderboardRow(
        repId: map['repId'] as String? ?? '',
        name: map['name'] as String?,
        seat: map['seat'] as String? ?? '',
        vacant: map['vacant'] == true,
        reports: (map['reports'] as num?)?.toInt() ?? 0,
        open: (map['open'] as num?)?.toInt() ?? 0,
        fixed: (map['fixed'] as num?)?.toInt() ?? 0,
        fixedPct: (map['fixedPct'] as num?)?.toDouble() ?? 0,
        medianDaysToFix: (map['medianDaysToFix'] as num?)?.toInt(),
        oldestOpenDays: (map['oldestOpenDays'] as num?)?.toInt(),
        rank: (map['rank'] as num?)?.toInt(),
      );
}

class RepresentativeLeaderboard {
  final List<LeaderboardRow> rows;
  final DateTime? computedAt;
  final int windowDays;
  final int minReports;

  const RepresentativeLeaderboard({
    this.rows = const [],
    this.computedAt,
    this.windowDays = 90,
    this.minReports = 5,
  });

  List<LeaderboardRow> get ranked => rows.where((r) => r.rank != null).toList();
  List<LeaderboardRow> get unranked => rows.where((r) => r.rank == null).toList();

  factory RepresentativeLeaderboard.fromMap(Map<String, dynamic> map) => RepresentativeLeaderboard(
        rows: ((map['rows'] as List?) ?? const [])
            .map((r) => LeaderboardRow.fromMap((r as Map).cast<String, dynamic>()))
            .toList(),
        computedAt: (map['computedAt'] as Timestamp?)?.toDate(),
        windowDays: (map['windowDays'] as num?)?.toInt() ?? 90,
        minReports: (map['minReports'] as num?)?.toInt() ?? 5,
      );
}
