import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

Map<SubmissionStatus, String> _statusLabels(AppLocalizations l10n) => {
      SubmissionStatus.newSubmission: l10n.statusFiled,
      SubmissionStatus.reviewed: l10n.statusAcknowledged,
      SubmissionStatus.inProgress: l10n.statusInProgress,
      SubmissionStatus.resolved: l10n.statusResolved,
    };

/// Problem-reports queue: a standard triage list for citizen-reported civic
/// problems, separate from the development-suggestion ranking (see
/// `RankedWorksScreen`) — searchable, status update dropdown per report,
/// bulk status update. Scoped to the signed-in official's own constituency.
class TicketManagementScreen extends ConsumerWidget {
  const TicketManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/official/dashboard'),
        ),
        title: Text(l10n.problemReports),
      ),
      body: profileAsync.when(
        data: (profile) {
          final constituencyId = profile?.constituencyId;
          if (constituencyId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.notLinkedConstituency,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _TicketList(constituencyId: constituencyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
      ),
    );
  }
}

class _TicketList extends ConsumerStatefulWidget {
  const _TicketList({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_TicketList> createState() => _TicketListState();
}

class _TicketListState extends ConsumerState<_TicketList> {
  String _query = '';
  final Set<String> _selected = {};

  Future<void> _bulkUpdate(SubmissionStatus status) async {
    final service = ref.read(firestoreServiceProvider);
    await Future.wait(_selected.map((id) => service.updateSubmissionStatus(id, status)));
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusLabels = _statusLabels(l10n);
    final ticketsAsync =
        ref.watch(_constituencyTicketsProvider(widget.constituencyId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.searchByTicketId,
            ),
          ),
        ),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(l10n.selectedCount(_selected.length)),
                const Spacer(),
                TextButton(
                  onPressed: () => _bulkUpdate(SubmissionStatus.inProgress),
                  child: Text(l10n.markInProgress),
                ),
                TextButton(
                  onPressed: () => _bulkUpdate(SubmissionStatus.resolved),
                  child: Text(l10n.markResolved),
                ),
              ],
            ),
          ),
        Expanded(
          child: ticketsAsync.when(
            data: (tickets) {
              final filtered = tickets
                  .where((t) => t.category == SubmissionCategory.problem)
                  .where((t) =>
                      t.tokenId.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
              if (filtered.isEmpty) {
                return Center(child: Text(l10n.noProblemReports));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ticket = filtered[index];
                  final themeId = ticket.theme ?? 'more';
                  final isSelected = _selected.contains(ticket.id);
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(ticket.id);
                            } else {
                              _selected.remove(ticket.id);
                            }
                          });
                        },
                      ),
                      title: Text(ticket.tokenId,
                          style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: Row(
                        children: [
                          Icon(kThemeIcons[themeId], size: 16, color: categoryColor(themeId)),
                          const SizedBox(width: 6),
                          Text(themeId),
                        ],
                      ),
                      trailing: DropdownButton<SubmissionStatus>(
                        value: ticket.status,
                        items: SubmissionStatus.values
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(statusLabels[s] ?? SubmissionModel.statusToString(s)),
                                ))
                            .toList(),
                        onChanged: (status) {
                          if (status != null) {
                            ref
                                .read(firestoreServiceProvider)
                                .updateSubmissionStatus(ticket.id, status);
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(child: Text(l10n.couldNotLoadTickets)),
          ),
        ),
      ],
    );
  }
}

final _constituencyTicketsProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchConstituencySubmissions(constituencyId);
});
