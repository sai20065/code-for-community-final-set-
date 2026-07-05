import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';

/// Section 3.8 / 5.2: lead with a single glanceable number per stat before
/// any chart — "can a busy person understand value in 5 minutes" test.
class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Constituency Dashboard'),
        bottom: const TricolorTrustStrip(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    label: 'New this week',
                    value: '42',
                    color: AppColors.coralRed,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Resolved rate',
                    value: '68%',
                    color: AppColors.leafGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _StatCard(
              label: 'Avg response time',
              value: '2.3 days',
              color: AppColors.trustBlue,
              fullWidth: true,
            ),
            const SizedBox(height: 20),
            Text('Constituency Map', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: Material(
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go('/official/map'),
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded, size: 48, color: AppColors.trustBlue),
                        SizedBox(height: 8),
                        Text('Open constituency map'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/official/themes'),
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Themes Overview'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/official/tickets'),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Ticket Management'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
