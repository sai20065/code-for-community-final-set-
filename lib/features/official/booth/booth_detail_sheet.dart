import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../core/models/booth_model.dart';
import '../../../core/models/cluster_model.dart';

/// Cluster summaries (AI-written one-liners, from the Gemini pipeline in
/// `functions/src/submissions/onSubmissionCreated.ts`) listed first, sorted
/// by priority score; raw sample ticket ids expandable underneath.
class BoothDetailSheet extends ConsumerWidget {
  const BoothDetailSheet({super.key, required this.booth});

  final BoothModel booth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clustersAsync = ref.watch(_boothClustersProvider(booth.id));
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(booth.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${booth.openIssueCount} open issues',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Text('Cluster summaries', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            clustersAsync.when(
              data: (clusters) {
                if (clusters.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No recurring themes clustered here yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(
                  children: clusters
                      .map((c) => _ClusterTile(cluster: c))
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const Text('Could not load clusters.'),
            ),
            const SizedBox(height: 16),
            clustersAsync.maybeWhen(
              data: (clusters) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Sample tickets'),
                children: [
                  for (final c in clusters)
                    for (final id in c.sampleSubmissionIds)
                      ListTile(title: Text('$id — ${c.theme}')),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

final _boothClustersProvider =
    StreamProvider.family<List<ClusterModel>, String>((ref, boothId) {
  return ref.watch(firestoreServiceProvider).watchClustersForBooth(boothId);
});

class _ClusterTile extends StatelessWidget {
  const _ClusterTile({required this.cluster});

  final ClusterModel cluster;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(cluster.summaryText.isEmpty
            ? '${cluster.theme} tickets in this booth'
            : cluster.summaryText),
        subtitle: cluster.priorityScore != null
            ? Text('Priority ${cluster.priorityScore!.toStringAsFixed(1)}')
            : null,
        trailing: CircleAvatar(
          radius: 14,
          child: Text('${cluster.submissionCount}',
              style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
