import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers/feed_providers.dart';
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/public_models.dart';
import '../../../core/models/representative_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/comments_sheet.dart';
import '../../../shared/widgets/feed_post_card.dart';
import '../../../shared/widgets/report_post_text.dart';
import '../../../shared/widgets/share_actions.dart';

/// The public card for one report. Its top is the very same post the feed
/// shows ([FeedPostCard]); below it, the progress, the area and its elected
/// representatives (names only), the office to file with, comments and
/// nearby reports, with a sticky Me too / Comment / Share / Post bar.
///
/// Reads only public data, so it renders for a signed-out visitor opening a
/// shared link; photos appear only as the blurred copy the reporter allowed.
class PublicReportCardScreen extends ConsumerStatefulWidget {
  const PublicReportCardScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<PublicReportCardScreen> createState() => _PublicReportCardScreenState();
}

class _PublicReportCardScreenState extends ConsumerState<PublicReportCardScreen> {
  final _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ticketAsync = ref.watch(publicTicketProvider(widget.ticketId));
    final reps = ref.watch(publicRepsProvider).valueOrNull ?? PublicReps.empty;
    final geo = ref.watch(karnatakaGeoProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/feed'),
        ),
        title: Text(l10n.reportCardTitle),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
        data: (ticket) {
          if (ticket == null) return Center(child: Text(l10n.ticketNotFound));
          final place = placeLabel(ticket, reps, geo);
          return ReportCardBody(ticket: ticket, reps: reps, place: place, cardKey: _cardKey);
        },
      ),
      bottomNavigationBar: ticketAsync.valueOrNull == null
          ? null
          : _ActionBar(
              ticket: ticketAsync.value!,
              post: reportSharePost(l10n, ticketAsync.value!, reps, placeLabel(ticketAsync.value!, reps, geo)),
              cardKey: _cardKey,
            ),
    );
  }
}

/// Everything under the app bar — separate so it can be tested without
/// Firestore.
class ReportCardBody extends ConsumerWidget {
  const ReportCardBody({
    super.key,
    required this.ticket,
    required this.reps,
    required this.place,
    this.cardKey,
    this.showNearby = true,
  });

  final PublicTicketModel ticket;
  final PublicReps reps;
  final String place;
  final GlobalKey? cardKey;
  final bool showNearby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ticket;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        FeedPostCard(
          ticket: t,
          reps: reps,
          place: place,
          showActions: false,
          showOpenCard: false,
          imageKey: cardKey,
        ),
        const SizedBox(height: 12),
        if (t.submissionCategory != 'feedback')
          _Section(child: _ProgressTrack(status: t.status)),
        _Section(
          title: place,
          icon: Icons.place_rounded,
          child: Column(children: [
            _RepRow(role: l10n.mlaLabel, entry: reps.mla[t.assemblyId]),
            _RepRow(role: l10n.mpLabel, entry: reps.mp[t.constituencyId]),
            if (t.supporterCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.favorite_rounded, size: 16, color: AppColors.vermilion),
                  const SizedBox(width: 8),
                  Text(l10n.meTooCount(t.supporterCount),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
        if (t.suggestedOfficeName != null)
          _Section(
            title: l10n.suggestedOfficeTitle,
            icon: Icons.account_balance_rounded,
            child: Row(children: [
              Expanded(
                child: Text(t.suggestedOfficeName!,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
              if (t.suggestedOfficeUrl != null)
                FilledButton.tonalIcon(
                  onPressed: () => launchUrl(Uri.parse(t.suggestedOfficeUrl!),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(l10n.visitWebsite),
                ),
            ]),
          ),
        _CommentsPreview(ticketId: t.id, count: t.commentCount),
        if (t.clusterId != null)
          _LinkTile(
            icon: Icons.lightbulb_outline_rounded,
            color: AppColors.saffronDeep,
            label: l10n.seeAreaSolution,
            onTap: () => context.push('/public/cluster/${t.clusterId}'),
          ),
        _LinkTile(
          icon: Icons.leaderboard_rounded,
          color: AppColors.indigo,
          label: l10n.leaderboardTitle,
          onTap: () => context.push('/public/leaderboard'),
        ),
        if (showNearby) _Nearby(ticket: t),
        if (reps.rosterAsOf != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(l10n.rosterAsOf(reps.rosterAsOf!),
                style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title, this.icon});

  final Widget child;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(title!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
              ),
            ]),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// Reported → Acknowledged → In progress → Fixed, as one compact track.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const order = ['new', 'reviewed', 'inProgress', 'resolved'];
    final labels = [l10n.statusFiled, l10n.statusAcknowledged, l10n.statusInProgress, l10n.statusResolved];
    final at = order.indexOf(status).clamp(0, 3);
    final color = statusColor(status);
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: i <= at ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: i < at || (i == at && status == 'resolved')
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
          if (i < 3)
            Expanded(
              child: Container(height: 3, color: i < at ? color : Colors.grey.shade300),
            ),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Text(
              labels[i],
              textAlign: i == 0 ? TextAlign.start : (i == 3 ? TextAlign.end : TextAlign.center),
              style: TextStyle(
                fontSize: 11,
                fontWeight: i == at ? FontWeight.w800 : FontWeight.w500,
                color: i <= at ? AppColors.ink : AppColors.inkFaint,
              ),
            ),
          ),
      ]),
    ]);
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
    final known = e != null && !e.vacant && e.name != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
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
                text: repName(l10n, e),
                style: TextStyle(fontWeight: FontWeight.w700, color: known ? AppColors.ink : AppColors.inkFaint),
              ),
              if (e != null) TextSpan(text: '  ·  ${e.seat}', style: const TextStyle(color: AppColors.inkSoft)),
            ])),
          ),
        ],
      ),
    );
  }
}

class _CommentsPreview extends ConsumerWidget {
  const _CommentsPreview({required this.ticketId, required this.count});

  final String ticketId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final latest = (ref.watch(feedCommentsProvider(ticketId)).valueOrNull ?? const []).take(2).toList();
    return _Section(
      title: l10n.commentsTitle,
      icon: Icons.mode_comment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest.isEmpty)
            Text(l10n.noCommentsYet, style: const TextStyle(color: AppColors.inkSoft)),
          for (final c in latest)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '@${c.username}  ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: c.text),
              ])),
            ),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => showCommentsSheet(context, ticketId),
            child: Text(count > 0 ? l10n.viewAllComments(count) : l10n.addComment),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Material, not a decorated box: ListTile paints its ripple on the
      // nearest Material, which a coloured box would cover.
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Nearby extends ConsumerWidget {
  const _Nearby({required this.ticket});

  final PublicTicketModel ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final posts = (ref.watch(homeFeedPreviewProvider(ticket.districtId)).valueOrNull ?? const [])
        .where((p) => p.id != ticket.id)
        .toList();
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(l10n.moreNearby, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => FeedTile(ticket: posts[i]),
          ),
        ),
      ],
    );
  }
}

/// Me too · Comment · Share · Post — always within thumb reach.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.ticket, required this.post, required this.cardKey});

  final PublicTicketModel ticket;
  final SharePost post;
  final GlobalKey cardKey;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool? _supported;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supported = _supported ?? ref.watch(mySupportsProvider).valueOrNull?.contains(widget.ticket.id) ?? false;
    Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color ?? AppColors.ink),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Row(children: [
          action(
            supported ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            l10n.meToo,
            () async {
              final r = await sayMeToo(context, ref, widget.ticket.id);
              if (r != null && mounted) setState(() => _supported = r);
            },
            color: supported ? AppColors.vermilion : null,
          ),
          action(Icons.mode_comment_outlined, l10n.commentsTitle,
              () => showCommentsSheet(context, widget.ticket.id)),
          Expanded(
            child: Builder(
              builder: (c) => InkWell(
                onTap: () => shareWithImage(c, widget.post, imageKey: widget.cardKey, subject: l10n.reportCardTitle),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.send_rounded),
                    const SizedBox(height: 2),
                    Text(l10n.shareButton, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
          action(Icons.campaign_outlined, l10n.postShort, () => showSocialPostSheet(context, widget.post)),
        ]),
      ),
    );
  }
}
