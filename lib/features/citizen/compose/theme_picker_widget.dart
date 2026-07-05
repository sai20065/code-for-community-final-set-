import 'package:flutter/material.dart';

import '../../../shared/widgets/theme_icon_chip.dart';

/// 2x2 icon grid, optional — AI also auto-classifies (Section 4, screen 7).
/// Never more than 4 choices on a decision screen (Section 3.2 / Hick's Law).
class ThemePickerWidget extends StatelessWidget {
  const ThemePickerWidget({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _options = ['roads', 'water', 'electricity', 'more'];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: _options.map((id) {
        return ThemeIconChip(
          themeId: id,
          selected: selected == id,
          onTap: () => onSelected(selected == id ? null : id),
        );
      }).toList(),
    );
  }
}
