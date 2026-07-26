import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/public_models.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Red / amber / teal severity ramp, used identically for polygon fills,
/// area indicators and legends across both map screens so one colour never
/// means two things.
Color severityColor(double? priority) {
  if (priority == null) return AppColors.indigoMist;
  if (priority >= 70) return AppColors.vermilion;
  if (priority >= 40) return AppColors.saffron;
  return AppColors.teal;
}

/// Every report filed inside one ward/taluk, opened by tapping that area's
/// circle indicator on either map.
///
/// Reads `publicTickets` — the anonymised projection — so this list carries
/// a token number, an AI-written summary and an area, and structurally
/// cannot carry a name, a phone number or an exact address. That holds for
/// officials too: this is the same sheet they get.
class AreaReportsSheet extends ConsumerWidget {
  const AreaReportsSheet({
    super.key,
    required this.areaName,
    required this.ticketField,
    required this.areaId,
    required this.reportCount,
    this.priority,
    this.icon = Icons.location_city_rounded,
    this.subtitle,
    this.representativeLine,
  });

  final String areaName;

  /// `wardId` inside Bengaluru, `talukId` everywhere else — ward and taluk
  /// ids live in different columns on `publicTickets`, so the caller has to
  /// say which layer its indicator came from.
  final String ticketField;
  final String areaId;
  final int reportCount;
  final double? priority;
  final IconData icon;
  final String? subtitle;
  final String? representativeLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync =
        ref.watch(publicTicketsForAreaProvider('$ticketField:$areaId'));
    final tint = severityColor(priority);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tint.withValues(alpha: 0.16), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.inkFaint.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: tint, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(areaName,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            Text(
                              subtitle ??
                                  '$reportCount report'
                                      '${reportCount == 1 ? "" : "s"} tracked here',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((representativeLine ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MapPill(
                        icon: Icons.how_to_vote_rounded,
                        label: representativeLine!,
                        tint: AppColors.saffronDeep,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ticketsAsync.when(
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const _SheetEmpty(
                      message:
                          'No individual reports published for this area yet.',
                      hint: 'Reports appear here once enough have been filed '
                          'that publishing them cannot identify anyone.',
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _TicketRow(ticket: tickets[i], areaName: areaName),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _SheetEmpty(
                  message: 'Could not load reports for this area.',
                  hint: 'Check your connection and try again.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One anonymised report row: token number, the problem, its area, status.
/// Deliberately the whole of what anyone — citizen or official — may see
/// about a report from a map.
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.areaName});

  final PublicTicketModel ticket;
  final String areaName;

  @override
  Widget build(BuildContext context) {
    final themeId = ticket.theme ?? 'more';
    final tint = categoryColor(themeId);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kThemeIcons[themeId], size: 15, color: tint),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  ticket.tokenId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigo,
                  ),
                ),
              ),
              _StatusChip(status: ticket.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket.publicSummary.isEmpty
                ? 'Summary pending review'
                : ticket.publicSummary,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              MapPill(
                icon: Icons.place_outlined,
                label: areaName,
                tint: AppColors.teal,
              ),
              if (ticket.createdDate.isNotEmpty)
                MapPill(
                  icon: Icons.calendar_today_rounded,
                  label: ticket.createdDate,
                  tint: AppColors.inkFaint,
                ),
              if (ticket.supporterCount > 0)
                MapPill(
                  icon: Icons.people_outline_rounded,
                  label: '${ticket.supporterCount} supporting',
                  tint: AppColors.saffronDeep,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, tint) = switch (status) {
      'resolved' => ('Resolved', AppColors.teal),
      'inProgress' => ('In progress', AppColors.saffronDeep),
      'reviewed' => ('Reviewed', AppColors.indigo),
      _ => ('New', AppColors.inkFaint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: tint),
      ),
    );
  }
}

class MapPill extends StatelessWidget {
  const MapPill({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: tint)),
          ),
        ],
      ),
    );
  }
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                size: 38, color: AppColors.indigoMist),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkFaint, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
