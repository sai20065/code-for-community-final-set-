import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';

/// Step 1 of the submit flow: the citizen picks what kind of ticket this is
/// before describing it. Two large, unmistakably different tiles rather
/// than a toggle, since this choice governs the ticket's entire downstream
/// lifecycle (status stepper vs. supporter count — see `MyReportsScreen`).
/// Selecting a tile hands off to the text compose screen (step 2), which
/// itself lets the citizen switch to voice/photo without losing the
/// category (see `InputModeSwitcher`).
class CategoryPickerScreen extends StatelessWidget {
  const CategoryPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New submission')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'What would you like to do?',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _CategoryTile(
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.vermilion,
                        mist: AppColors.vermilionMist,
                        title: 'Report a problem',
                        subtitle: 'Something broken or unsafe near you',
                        onTap: () => context.go(
                          '/compose/text',
                          extra: SubmissionCategory.problem,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _CategoryTile(
                        icon: Icons.lightbulb_rounded,
                        color: AppColors.saffronDeep,
                        mist: AppColors.saffronMist,
                        title: 'Suggest a development work',
                        subtitle: 'Something new your area needs',
                        onTap: () => context.go(
                          '/compose/text',
                          extra: SubmissionCategory.feedback,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.color,
    required this.mist,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color mist;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: mist,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 30, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 28)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
