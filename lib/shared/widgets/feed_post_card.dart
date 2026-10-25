import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/auth_state_provider.dart';
import '../../app/providers/feed_providers.dart';
import '../../app/theme.dart';
import '../../core/models/public_models.dart';
import '../../core/models/representative_models.dart';
import '../../l10n/app_localizations.dart';
import 'comments_sheet.dart';
import 'report_post_text.dart';
import 'share_actions.dart';
import 'theme_icon_chip.dart';

/// "Me too" on [ticketId]. Returns the new state, or null when it couldn't
/// be changed (signed out, own report, network) — the reason is shown.
Future<bool?> sayMeToo(BuildContext context, WidgetRef ref, String ticketId) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.maybeOf(context);
  void say(String text, {bool signIn = false}) => messenger.showSnackBar(SnackBar(
        content: Text(text),
        action: signIn && router != null
            ? SnackBarAction(label: l10n.signIn, onPressed: () => router.push('/signin'))
            : null,
      ));

  if (ref.read(authStateProvider).valueOrNull == null) {
    say(l10n.signInForMeToo, signIn: true);
    return null;
  }
  if (ref.read(myReportIdsProvider).valueOrNull?.contains(ticketId) ?? false) {
    say(l10n.ownReportNoMeToo);
    return null;
  }
  try {
    return await ref.read(feedServiceProvider).toggleSupport(ticketId);
  } on FirebaseFunctionsException catch (e) {
    say(e.code == 'failed-precondition' ? l10n.ownReportNoMeToo : l10n.somethingWentWrong);
  } catch (_) {
    say(l10n.somethingWentWrong);
  }
  return null;
}

/// One report as an Instagram-style post: header, photo (or a themed
/// cover), action row, summary, and the area's MLA and MP by name. The same
/// widget is the feed post and the top of the report card, so the two
/// always look alike.
class FeedPostCard extends ConsumerStatefulWidget {
  const FeedPostCard({
    super.key,
    required this.ticket,
    required this.reps,
    required this.place,
    this.showActions = true,
    this.showOpenCard = true,
    this.imageKey,
  });

  final PublicTicketModel ticket;
  final PublicReps reps;
  final String place;

  /// Off on the report card, which has its own labelled action bar.
  final bool showActions;
  final bool showOpenCard;

  /// Wraps the shareable part of the post, for the Share image.
  final GlobalKey? imageKey;

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard> with SingleTickerProviderStateMixin {
  late final GlobalKey _ownKey = GlobalKey();
  bool? _supported;
  int _countDelta = 0;
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  GlobalKey get _imageKey => widget.imageKey ?? _ownKey;

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Future<void> _toggle({bool onlyOn = false}) async {
    final current = _supported ?? ref.read(mySupportsProvider).valueOrNull?.contains(widget.ticket.id) ?? false;
    if (onlyOn && current) {
      _burst.forward(from: 0);
      return;
    }
    if (onlyOn) _burst.forward(from: 0);
    final result = await sayMeToo(context, ref, widget.ticket.id);
    if (result == null || !mounted) return;
    setState(() {
      if (result != current) _countDelta += result ? 1 : -1;
      _supported = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = widget.ticket;
    final supported = _supported ?? ref.watch(mySupportsProvider).valueOrNull?.contains(t.id) ?? false;
    final count = (t.supporterCount + _countDelta).clamp(0, 1 << 30);
    final color = categoryColor(t.theme ?? 'more');
    final post = reportSharePost(l10n, t, widget.reps, widget.place);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            key: _imageKey,
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(ticket: t, place: widget.place, color: color),
                  GestureDetector(
                    onDoubleTap: widget.showActions ? () => _toggle(onlyOn: true) : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FeedMedia(ticket: t),
                        _HeartBurst(controller: _burst),
                      ],
                    ),
                  ),
                  if (!widget.showActions) const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Text(t.publicSummary,
                        style: const TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    child: Row(children: [
                      const Icon(Icons.how_to_vote_outlined, size: 14, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(repsLine(l10n, t, widget.reps),
                            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showActions) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.meToo,
                    onPressed: _toggle,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Icon(
                        supported ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey(supported),
                        color: supported ? AppColors.vermilion : AppColors.ink,
                      ),
                    ),
                  ),
                  Text('$count', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: l10n.commentsTitle,
                    onPressed: () => showCommentsSheet(context, t.id),
                    icon: const Icon(Icons.mode_comment_outlined),
                  ),
                  Text('${t.commentCount}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Builder(
                    builder: (c) => IconButton(
                      tooltip: l10n.shareButton,
                      onPressed: () => shareWithImage(c, post, imageKey: _imageKey, subject: l10n.reportCardTitle),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.postOnSocial,
                    onPressed: () => showSocialPostSheet(context, post),
                    icon: const Icon(Icons.campaign_outlined),
                  ),
                  const Spacer(),
                  if (widget.showOpenCard)
                    TextButton(
                      onPressed: () => context.push('/public/report/${t.id}'),
                      child: Text(l10n.openCard),
                    ),
                ],
              ),
            ),
            if (t.commentCount > 0)
              InkWell(
                onTap: () => showCommentsSheet(context, t.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(l10n.viewAllComments(t.commentCount),
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket, required this.place, required this.color});

  final PublicTicketModel ticket;
  final String place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ticket;
    final sColor = statusColor(t.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: color,
            child: Icon(kThemeIcons[t.theme] ?? Icons.report_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text('${kThemeLabels[t.theme] ?? 'Civic issue'} · ${l10n.postedDaysAgo(daysSinceFiled(t))}',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: sColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel(l10n, t.status),
                style: TextStyle(color: sColor, fontWeight: FontWeight.w800, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

/// The post's picture: the blurred public photo when the reporter allowed
/// it, otherwise a themed cover carrying the summary — never the original.
class FeedMedia extends StatelessWidget {
  const FeedMedia({super.key, required this.ticket, this.compact = false});

  final PublicTicketModel ticket;

  /// The small square used in horizontal strips.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ticket;
    final days = t.daysOpen(DateTime.now());
    final badge = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: statusColor(t.status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        compact
            ? (t.isOpen ? l10n.openDaysShort(days) : l10n.statusResolved)
            : (t.isOpen ? l10n.openForDays(days) : l10n.fixedInDays(days)),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: compact ? 10.5 : 12.5),
      ),
    );

    final Widget picture;
    double ratio;
    if (t.hasPhoto) {
      final w = t.photoWidth ?? 4;
      final h = t.photoHeight ?? 5;
      ratio = compact ? 1 : (w / h).clamp(4 / 5, 1.91);
      picture = CachedNetworkImage(
        imageUrl: t.photoUrl!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => _ThemedCover(ticket: t, compact: compact, showText: false),
        errorWidget: (_, __, ___) => _ThemedCover(ticket: t, compact: compact),
      );
    } else {
      ratio = compact ? 1 : 4 / 3;
      picture = _ThemedCover(ticket: t, compact: compact);
    }
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          picture,
          Positioned(top: compact ? 6 : 10, right: compact ? 6 : 10, child: badge),
        ],
      ),
    );
  }
}

class _ThemedCover extends StatelessWidget {
  const _ThemedCover({required this.ticket, this.compact = false, this.showText = true});

  final PublicTicketModel ticket;
  final bool compact;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final base = categoryColor(ticket.theme ?? 'more');
    final dark = Color.lerp(base, Colors.black, 0.35)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, dark],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: compact ? -10 : -24,
            bottom: compact ? -10 : -24,
            child: Icon(kThemeIcons[ticket.theme] ?? Icons.report_rounded,
                size: compact ? 70 : 170, color: Colors.white.withValues(alpha: 0.16)),
          ),
          if (showText)
            Padding(
              padding: EdgeInsets.all(compact ? 10 : 22),
              child: Align(
                alignment: compact ? Alignment.bottomLeft : Alignment.centerLeft,
                child: Text(
                  ticket.publicSummary,
                  maxLines: compact ? 3 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 12 : 22,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final v = controller.value;
          if (v == 0 || v == 1) return const SizedBox.shrink();
          final scale = Curves.elasticOut.transform((v * 1.6).clamp(0, 1));
          final opacity = v < 0.7 ? 1.0 : (1 - (v - 0.7) / 0.3);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.4 + scale * 0.8,
              child: const Icon(Icons.favorite_rounded, size: 110, color: Colors.white,
                  shadows: [Shadow(blurRadius: 18, color: Colors.black38)]),
            ),
          );
        },
      ),
    );
  }
}

/// A small square post for horizontal strips (home "Reports near you",
/// "More reports nearby").
class FeedTile extends StatelessWidget {
  const FeedTile({super.key, required this.ticket, this.size = 136});

  final PublicTicketModel ticket;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/public/report/${ticket.id}'),
          child: FeedMedia(ticket: ticket, compact: true),
        ),
      ),
    );
  }
}
