import 'package:flutter/material.dart';

import '../../../core/models/booth_model.dart';

/// Section 5.3: cluster summaries (AI-written one-liners) listed first, raw
/// submissions expandable underneath, sorted by priority score.
class BoothDetailSheet extends StatelessWidget {
  const BoothDetailSheet({super.key, required this.booth});

  final BoothModel booth;

  @override
  Widget build(BuildContext context) {
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
            const _ClusterTile(
              summary: 'Repeated potholes reported along Lake Road stretch',
              count: 9,
            ),
            const _ClusterTile(
              summary: 'Intermittent power cuts near Market Square',
              count: 5,
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Raw submissions'),
              children: const [
                ListTile(title: Text('PD-2026-004821 — Roads')),
                ListTile(title: Text('PD-2026-004830 — Electricity')),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ClusterTile extends StatelessWidget {
  const _ClusterTile({required this.summary, required this.count});

  final String summary;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(summary),
        trailing: CircleAvatar(
          radius: 14,
          child: Text('$count', style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
