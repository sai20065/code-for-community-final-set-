import 'package:flutter/material.dart';

import '../../app/theme.dart';

const Map<String, IconData> kThemeIcons = {
  'roads': Icons.add_road_rounded,
  'water': Icons.water_drop_rounded,
  'electricity': Icons.bolt_rounded,
  'health': Icons.local_hospital_rounded,
  'sanitation': Icons.cleaning_services_rounded,
  'education': Icons.school_rounded,
  'skilling': Icons.workspace_premium_rounded,
  'more': Icons.more_horiz_rounded,
};

const Map<String, String> kThemeLabels = {
  'roads': 'Roads',
  'water': 'Water',
  'electricity': 'Electricity',
  'health': 'Health',
  'sanitation': 'Sanitation',
  'education': 'Education',
  'skilling': 'Skilling',
  'more': 'More',
};

/// Color-coded, icon-first category chip (Section 3.1 / 3.3) — filled,
/// rounded glyph style reads friendlier and parses faster at small sizes
/// than a thin outline icon.
class ThemeIconChip extends StatelessWidget {
  const ThemeIconChip({
    super.key,
    required this.themeId,
    this.selected = false,
    this.onTap,
  });

  final String themeId;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(themeId);
    final icon = kThemeIcons[themeId] ?? Icons.help_outline_rounded;
    final label = kThemeLabels[themeId] ?? themeId;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color,
              radius: 22,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
