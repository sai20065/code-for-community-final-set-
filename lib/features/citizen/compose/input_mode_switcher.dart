import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';

/// "Input mode toggle: Voice / Text / Photo" — since each mode already has
/// its own screen/route (voice recording needs a dedicated recorder,
/// photo needs a dedicated picker), this switches between those routes
/// directly rather than merging three screens into one, carrying the
/// current [category] (Suggest vs Report) forward so switching modes never
/// loses that choice.
class InputModeSwitcher extends StatelessWidget {
  const InputModeSwitcher({
    super.key,
    required this.current,
    required this.category,
  });

  final String current; // 'voice' | 'text' | 'photo'
  final SubmissionCategory category;

  static const _modes = [
    ('voice', Icons.mic_rounded, '/compose/voice'),
    ('text', Icons.edit_rounded, '/compose/text'),
    ('photo', Icons.camera_alt_rounded, '/compose/photo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: _modes.map((m) {
          final (id, icon, route) = m;
          final selected = id == current;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: selected ? null : () => context.go(route, extra: category),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.indigo : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: selected ? Colors.white : AppColors.inkFaint, size: 20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
