import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/work_providers.dart';
import '../../../app/theme.dart';

/// Pick one of your workers and hand them [ticketIds]. Returns true when at
/// least one ticket was assigned.
Future<bool> showAssignSheet(
  BuildContext context, {
  required List<String> ticketIds,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AssignSheet(ticketIds: ticketIds),
  );
  return done == true;
}

class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet({required this.ticketIds});

  final List<String> ticketIds;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  String? _workerUid;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    final uid = _workerUid;
    if (uid == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final n = await ref
          .read(workServiceProvider)
          .assign(widget.ticketIds, uid, note: _note.text);
      messenger.showSnackBar(SnackBar(
        content: Text(n == widget.ticketIds.length
            ? 'Assigned $n ${n == 1 ? 'report' : 'reports'}.'
            : 'Assigned $n of ${widget.ticketIds.length}. The rest are outside your area or already closed.'),
      ));
      nav.pop(n > 0);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not assign. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = ref.watch(myWorkersProvider);
    final n = widget.ticketIds.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign $n ${n == 1 ? 'report' : 'reports'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Choose who should go and fix it.',
                style: TextStyle(color: AppColors.inkFaint, fontSize: 13)),
            const SizedBox(height: 12),
            workers.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text('Could not load your team.'),
              data: (list) {
                final active = list.where((w) => !w.disabled).toList();
                if (active.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You have no workers yet. Add one first.'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text('Add a worker'),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                          context.push('/official/team');
                        },
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    for (final w in active)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _workerUid == w.uid
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: AppColors.indigo,
                        ),
                        title: Text(w.name),
                        subtitle: Text('${w.openTickets} open now'),
                        onTap: () => setState(() => _workerUid = w.uid),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLength: 280,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note for the worker (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _workerUid == null || _busy ? null : _assign,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Assign'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
