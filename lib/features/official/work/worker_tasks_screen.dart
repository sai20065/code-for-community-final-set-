import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/work_providers.dart';
import '../../../app/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/work_service.dart';
import '../../../shared/widgets/google_maps_directions_button.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// A field worker's home: only the reports assigned to them. They can mark a
/// report in progress or fixed, and close one the citizen never answered
/// after 48 hours. They never see who reported it.
class WorkerTasksScreen extends ConsumerWidget {
  const WorkerTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(workerTasksProvider);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('My assigned reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(workerTasksProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Could not load your reports.')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('Nothing assigned to you yet.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final todo = list.where((t) => !t.isFixed).toList();
          final waiting = list.where((t) => t.status == 'resolved').toList();
          final closed = list.where((t) => t.isClosed).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(workerTasksProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _Heading('To do (${todo.length})'),
                for (final t in todo) _TaskCard(task: t),
                if (waiting.isNotEmpty) ...[
                  _Heading('Fixed, waiting for the citizen (${waiting.length})'),
                  for (final t in waiting) _TaskCard(task: t),
                ],
                if (closed.isNotEmpty) ...[
                  _Heading('Closed (${closed.length})'),
                  for (final t in closed) _TaskCard(task: t),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      );
}

class _TaskCard extends ConsumerStatefulWidget {
  const _TaskCard({required this.task});
  final WorkerTask task;

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _busy = false;

  Future<void> _run(
      Future<int> Function(WorkService s) action, String ok, String fail) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await action(ref.read(workServiceProvider));
      messenger.showSnackBar(SnackBar(content: Text(n > 0 ? ok : fail)));
      ref.invalidate(workerTasksProvider);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(fail)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final themeId = t.theme ?? 'more';
    final tint = categoryColor(themeId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(kThemeIcons[themeId], size: 18, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.tokenId,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: AppColors.indigo)),
          ),
          _StatusChip(status: t.status),
        ]),
        const SizedBox(height: 8),
        Text(t.summary.isEmpty ? 'Summary pending review' : t.summary,
            style: const TextStyle(fontSize: 13.5, height: 1.4)),
        if (t.area.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.place_outlined,
                size: 14, color: AppColors.inkFaint),
            const SizedBox(width: 4),
            Text(t.area,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
          ]),
        ],
        if (t.note != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.indigoMist,
                borderRadius: BorderRadius.circular(10)),
            child: Text('${t.assignedBy}: ${t.note}',
                style: const TextStyle(fontSize: 12.5)),
          ),
        ],
        if (t.reopened && !t.isFixed) ...[
          const SizedBox(height: 8),
          const Text('The citizen said this was not fixed. Please check it again.',
              style: TextStyle(
                  color: AppColors.vermilion,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (t.lat != null && t.lng != null)
                GoogleMapsDirectionsButton(
                    lat: t.lat!, lng: t.lng!, compact: true),
              if (t.status == 'new' || t.status == 'reviewed')
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run((s) => s.updateStatus([t.id], 'inProgress'),
                          'Marked in progress.', 'Could not update.'),
                  child: const Text('Start work'),
                ),
              if (t.status == 'new' ||
                  t.status == 'reviewed' ||
                  t.status == 'inProgress')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          (s) => s.updateStatus([t.id], 'resolved'),
                          'Marked fixed. The citizen has 48 hours to confirm.',
                          'Could not update.'),
                  child: const Text('Mark fixed'),
                ),
              if (t.closeState == 'awaiting_citizen' && t.fixedAt != null)
                Text(
                    'Citizen has ${answerWindowLeft(t.fixedAt!).inHours} h left to answer',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkFaint)),
              if (t.closeState == 'closeable')
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Close ticket'),
                  onPressed: _busy
                      ? null
                      : () => _run((s) => s.close([t.id]), 'Ticket closed.',
                          'Could not close. The citizen may have answered.'),
                ),
            ]),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'reviewed' => 'Assigned',
      'inProgress' => 'In progress',
      'resolved' => 'Fixed',
      'closed' => 'Closed',
      _ => 'New',
    };
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
