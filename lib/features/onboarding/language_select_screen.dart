import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/language_grid_button.dart';

const List<(String code, String name, String native)> kSupportedLanguages = [
  ('hi', 'Hindi', 'हिन्दी'),
  ('ta', 'Tamil', 'தமிழ்'),
  ('te', 'Telugu', 'తెలుగు'),
  ('kn', 'Kannada', 'ಕನ್ನಡ'),
  ('bn', 'Bengali', 'বাংলা'),
  ('mr', 'Marathi', 'मराठी'),
  ('en', 'English', 'English'),
];

/// First-launch screen (Section 3.7): the language choice itself is the
/// onboarding — no header text beyond a universal globe icon, no back button.
class LanguageSelectScreen extends StatelessWidget {
  const LanguageSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.language_rounded,
                  size: 56, color: AppColors.trustBlue),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  itemCount: kSupportedLanguages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.6,
                  ),
                  itemBuilder: (context, index) {
                    final (code, name, native) = kSupportedLanguages[index];
                    return LanguageGridButton(
                      languageName: name,
                      nativeLabel: native,
                      onTap: () => context.go('/signup/phone', extra: code),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
