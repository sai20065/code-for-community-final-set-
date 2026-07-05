import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../core/models/submission_model.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Searchable/filterable ticket list, status update dropdown per ticket,
/// bulk status update. Scoped to the signed-in official's own constituency.
class TicketManagementScreen extends ConsumerWidget {
  const TicketManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Management')),
      body: profileAsync.when(
        data: (profile) {
          final constituencyId = profile?.constituencyId;
          if (constituencyId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Your account isn\'t linked to a constituency yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _TicketList(constituencyId: constituencyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your profile.')),
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
    final ticketsAsync =
        ref.watch(_constituencyTicketsProvider(widget.constituencyId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search by ticket ID',
            ),
          ),
        ),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${_selected.length} selected'),
                const Spacer(),
                TextButton(
                  onPressed: () => _bulkUpdate(SubmissionStatus.inProgress),
                  child: const Text('Mark In Progress'),
                ),
                TextButton(
                  onPressed: () => _bulkUpdate(SubmissionStatus.resolved),
                  child: const Text('Mark Resolved'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ticketsAsync.when(
            data: (tickets) {
              final filtered = tickets
                  .where((t) =>
                      t.tokenId.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No tickets yet.'));
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
                                  child: Text(SubmissionModel.statusToString(s)),
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
            error: (_, __) => const Center(child: Text('Could not load tickets.')),
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
