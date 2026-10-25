import '../../core/models/public_models.dart';
import '../../core/models/representative_models.dart';
import '../../core/services/karnataka_geo_service.dart';
import '../../l10n/app_localizations.dart';
import 'share_actions.dart';

/// Ward (inside Bengaluru) or taluk, then district — whatever is known.
String placeLabel(PublicTicketModel t, PublicReps reps, KarnatakaGeo? geo) {
  String? nameOf(List<KarnatakaArea>? areas, String? id) {
    if (areas == null || id == null) return null;
    for (final a in areas) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  final ward = t.wardId == null ? null : reps.wardNames[t.wardId];
  final taluk = nameOf(geo?.taluks, t.talukId);
  final district = nameOf(geo?.districts, t.districtId);
  final parts = [ward ?? taluk, district].whereType<String>().toList();
  return parts.isEmpty ? (t.constituencyName ?? 'Karnataka') : parts.join(', ');
}

/// A representative's name, or a plain "Seat vacant" / "Not yet recorded".
/// Names only — the app never labels them as responsible for a report.
String repName(AppLocalizations l10n, RepresentativeEntry? r) =>
    r == null ? l10n.repNotRecorded : (r.vacant ? l10n.seatVacant : (r.name ?? l10n.repNotRecorded));

/// "MLA Name · MP Name" for a post.
String repsLine(AppLocalizations l10n, PublicTicketModel t, PublicReps reps) =>
    '${l10n.mlaLabel} ${repName(l10n, reps.mla[t.assemblyId])}  ·  '
    '${l10n.mpLabel} ${repName(l10n, reps.mp[t.constituencyId])}';

/// Days since the report was filed, whatever its status.
int daysSinceFiled(PublicTicketModel t, [DateTime? now]) {
  final created = DateTime.tryParse(t.createdDate);
  if (created == null) return 0;
  final today = now ?? DateTime.now();
  final d = DateTime(today.year, today.month, today.day).difference(created).inDays;
  return d < 0 ? 0 : d;
}

/// "Filed" / "Acknowledged" / "In progress" / "Resolved".
String statusLabel(AppLocalizations l10n, String status) => switch (status) {
      'reviewed' => l10n.statusAcknowledged,
      'inProgress' => l10n.statusInProgress,
      'resolved' => l10n.statusResolved,
      _ => l10n.statusFiled,
    };

/// The pre-written post for a report: public summary, place, days open and
/// both representatives' names — never the citizen's own words.
SharePost reportSharePost(AppLocalizations l10n, PublicTicketModel t, PublicReps reps, String place) {
  final days = t.daysOpen(DateTime.now());
  final mla = repName(l10n, reps.mla[t.assemblyId]);
  final mp = repName(l10n, reps.mp[t.constituencyId]);
  final text = t.isOpen
      ? l10n.shareReportOpen(t.publicSummary, place, days, mla, mp, t.tokenId)
      : l10n.shareReportFixed(t.publicSummary, place, days, mla, mp, t.tokenId);
  return SharePost(text: text, url: publicWebLink('/public/report/${t.id}'));
}
