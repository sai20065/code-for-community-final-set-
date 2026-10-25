import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/public_models.dart';
import '../../../core/models/representative_models.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/karnataka_geo_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/share_actions.dart';
import '../../../shared/widgets/status_stepper.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// The public card for one report, NammaKasa-style: what the problem is,
/// how long it has been open, and the MLA and MP whose area it is in — plus
/// Share / Post buttons so residents can put it in front of them.
///
/// Reads only `publicTickets` and `publicReps`, so it renders for a
/// signed-out visitor opening a shared link, and carries no photo and no
/// citizen's own words (see functions/src/public/projection.ts).
class PublicReportCardScreen extends ConsumerStatefulWidget {
  const PublicReportCardScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<PublicReportCardScreen> createState() => _PublicReportCardScreenState();
}

class _PublicReportCardScreenState extends ConsumerState<PublicReportCardScreen> {
  final _cardKey = GlobalKey();
  late final Future<KarnatakaGeo> _geo = KarnatakaGeoService.instance.load();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ticketAsync = ref.watch(publicTicketProvider(widget.ticketId));
    final reps = ref.watch(publicRepsProvider).valueOrNull ?? PublicReps.empty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/public/karnataka'),
        ),
        title: Text(l10n.reportCardTitle),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
        data: (ticket) {
          if (ticket == null) return Center(child: Text(l10n.ticketNotFound));
          return FutureBuilder<KarnatakaGeo>(
            future: _geo,
            builder: (context, geoSnap) {
              final place = placeLabel(ticket, reps, geoSnap.data);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  RepaintBoundary(
                    key: _cardKey,
                    child: PublicReportCard(ticket: ticket, reps: reps, place: place),
                  ),
                  const SizedBox(height: 14),
                  ShareActions(
                    post: reportSharePost(l10n, ticket, reps, place),
                    imageKey: _cardKey,
                    subject: l10n.reportCardTitle,
                  ),
                  const SizedBox(height: 18),
                  if (ticket.submissionCategory != 'feedback') ...[
                    StatusStepper(status: SubmissionModel.statusFromString(ticket.status)),
                    const SizedBox(height: 16),
                  ],
                  if (ticket.suggestedOfficeName != null)
                    _OfficeTile(name: ticket.suggestedOfficeName!, url: ticket.suggestedOfficeUrl),
                  if (ticket.clusterId != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.saffronDeep),
                      title: Text(l10n.seeAreaSolution),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/public/cluster/${ticket.clusterId}'),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.leaderboard_rounded, color: AppColors.indigo),
                    title: Text(l10n.leaderboardTitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/public/leaderboard'),
                  ),
                  if (reps.rosterAsOf != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(l10n.rosterAsOf(reps.rosterAsOf!),
                          style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

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

String _repName(AppLocalizations l10n, RepresentativeEntry? r) =>
    r == null ? l10n.repNotRecorded : (r.vacant ? l10n.seatVacant : (r.name ?? l10n.repNotRecorded));

/// The pre-written post for a report: public summary, place, days open and
/// both representatives — never the citizen's own words.
SharePost reportSharePost(AppLocalizations l10n, PublicTicketModel t, PublicReps reps, String place) {
  final days = t.daysOpen(DateTime.now());
  final mla = _repName(l10n, reps.mla[t.assemblyId]);
  final mp = _repName(l10n, reps.mp[t.constituencyId]);
  final text = t.isOpen
      ? l10n.shareReportOpen(t.publicSummary, place, days, mla, mp, t.tokenId)
      : l10n.shareReportFixed(t.publicSummary, place, days, mla, mp, t.tokenId);
  return SharePost(text: text, url: publicWebLink('/public/report/${t.id}'));
}

/// The shareable card itself — also what the Share button renders to an
/// image, so it is self-contained and branded.
class PublicReportCard extends StatelessWidget {
  const PublicReportCard({super.key, required this.ticket, required this.reps, required this.place});

  final PublicTicketModel ticket;
  final PublicReps reps;
  final String place;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ticket;
    final color = statusColor(t.status);
    final days = t.daysOpen(DateTime.now());
    final mla = reps.mla[t.assemblyId];
    final mp = reps.mp[t.constituencyId];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(kThemeIcons[t.theme] ?? Icons.report_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kThemeLabels[t.theme] ?? 'Civic issue',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  t.isOpen ? l10n.openForDays(days) : l10n.fixedInDays(days),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.publicSummary, style: const TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.place_rounded, size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Expanded(child: Text(place, style: const TextStyle(color: AppColors.inkSoft))),
                ]),
                if (t.supporterCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.groups_rounded, size: 16, color: AppColors.inkSoft),
                    const SizedBox(width: 6),
                    Text(l10n.peopleReportedSame(t.supporterCount + 1),
                        style: const TextStyle(color: AppColors.inkSoft)),
                  ]),
                ],
                const SizedBox(height: 14),
                Text(l10n.whosResponsible.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                _RepRow(role: l10n.mlaLabel, entry: mla),
                _RepRow(role: l10n.mpLabel, entry: mp),
              ],
            ),
          ),
          Container(
            color: AppColors.paper,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, size: 15, color: AppColors.indigoDeep),
                const SizedBox(width: 6),
                const Text('Prajadhwani',
                    style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.indigoDeep)),
                const Spacer(),
                Text('${t.tokenId} · ${t.createdDate}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepRow extends StatelessWidget {
  const _RepRow({required this.role, required this.entry});

  final String role;
  final RepresentativeEntry? entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final e = entry;
    final name = _repName(l10n, e);
    final known = e != null && !e.vacant && e.name != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: AppColors.indigoMist, borderRadius: BorderRadius.circular(6)),
            child: Text(role,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.indigoDeep)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: known ? AppColors.ink : AppColors.inkFaint,
                ),
              ),
              if (e != null) TextSpan(text: '  ·  ${e.seat}', style: const TextStyle(color: AppColors.inkSoft)),
            ])),
          ),
        ],
      ),
    );
  }
}

class _OfficeTile extends StatelessWidget {
  const _OfficeTile({required this.name, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uri = url == null ? null : Uri.tryParse(url!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_balance_rounded, color: AppColors.indigoDeep),
      title: Text(l10n.suggestedOfficeTitle, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
      subtitle: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
      trailing: uri == null ? null : const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: uri == null ? null : () => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
  }
}
