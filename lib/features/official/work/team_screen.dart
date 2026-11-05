import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/work_providers.dart';
import '../../../app/theme.dart';
import '../../../core/services/work_service.dart';

/// "My team": the field workers a DC / MLA / MP can assign reports to.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(myWorkersProvider);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/gov/dashboard'),
        ),
        title: const Text('My team'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWorker(context, ref),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Add worker'),
      ),
      body: workers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Could not load your team.')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No workers yet. Add the people who go out and fix problems, '
                  'then assign reports to them from the Reports tab.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myWorkersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _WorkerTile(worker: list[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addWorker(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a worker'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Enter a name' : null,
            ),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Email (used to sign in)'),
              validator: (v) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Enter a valid email',
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      final password = await ref
          .read(workServiceProvider)
          .createWorker(name: name.text.trim(), email: email.text.trim());
      ref.invalidate(myWorkersProvider);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Worker created'),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign-in email: ${email.text.trim()}'),
                const SizedBox(height: 8),
                const Text('Temporary password (shown only once):'),
                const SizedBox(height: 4),
                SelectableText(password,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                    'Share it with them privately. They sign in from the Government login.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
              ]),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: password)),
              child: const Text('Copy'),
            ),
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final taken =
            '$e'.contains('already-exists') || '$e'.contains('already has');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(taken
              ? 'That email already has an account.'
              : 'Could not create the worker.'),
        ));
      }
    }
  }
}

class _WorkerTile extends ConsumerWidget {
  const _WorkerTile({required this.worker});

  final WorkerInfo worker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: AppColors.indigoMist,
          child: Text(worker.name.isEmpty ? '?' : worker.name[0].toUpperCase(),
              style: const TextStyle(
                  color: AppColors.indigo, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(worker.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(worker.email,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
            Text(
                worker.disabled
                    ? 'Switched off'
                    : '${worker.openTickets} open reports',
                style: TextStyle(
                    fontSize: 12,
                    color: worker.disabled
                        ? AppColors.vermilion
                        : AppColors.tealDeep,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        Switch(
          value: !worker.disabled,
          onChanged: (on) async {
            await ref.read(workServiceProvider).setWorkerActive(worker.uid, on);
            ref.invalidate(myWorkersProvider);
          },
        ),
      ]),
    );
  }
}
