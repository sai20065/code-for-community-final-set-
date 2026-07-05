import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Section 5.5: searchable/filterable list, status update dropdown per
/// ticket, bulk status update option.
class TicketManagementScreen extends StatefulWidget {
  const TicketManagementScreen({super.key});

  @override
  State<TicketManagementScreen> createState() => _TicketManagementScreenState();
}

class _TicketManagementScreenState extends State<TicketManagementScreen> {
  String _query = '';
  final Set<String> _selected = {};

  final _sample = [
    ('PP-2026-004821', 'roads', SubmissionStatus.newSubmission),
    ('PP-2026-004822', 'water', SubmissionStatus.inProgress),
    ('PP-2026-004823', 'electricity', SubmissionStatus.resolved),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _sample
        .where((t) => t.$1.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Management'),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Bulk update status',
              onPressed: () {},
            ),
        ],
      ),
      body: Column(
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final (tokenId, themeId, status) = filtered[index];
                final isSelected = _selected.contains(tokenId);
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
                            _selected.add(tokenId);
                          } else {
                            _selected.remove(tokenId);
                          }
                        });
                      },
                    ),
                    title: Text(tokenId,
                        style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: Row(
                      children: [
                        Icon(kThemeIcons[themeId], size: 16, color: categoryColor(themeId)),
                        const SizedBox(width: 6),
                        Text(themeId),
                      ],
                    ),
                    trailing: DropdownButton<SubmissionStatus>(
                      value: status,
                      items: SubmissionStatus.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(SubmissionModel.statusToString(s)),
                              ))
                          .toList(),
                      onChanged: (_) {},
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
