import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/selected_language_provider.dart';
import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

/// 10 languages, no header text beyond a universal globe icon (Phase 2,
/// Section 4). Tapping instantly highlights the selection (Marigold Orange
/// flash) then auto-navigates ~300ms later — no separate "Confirm" button,
/// since this choice is low-stakes and changeable later in Profile settings.
const List<(String code, String name, String native)> kSupportedLanguages = [
  ('hi', 'Hindi', 'हिन्दी'),
  ('ta', 'Tamil', 'தமிழ்'),
  ('te', 'Telugu', 'తెలుగు'),
  ('kn', 'Kannada', 'ಕನ್ನಡ'),
  ('bn', 'Bengali', 'বাংলা'),
  ('mr', 'Marathi', 'मराठी'),
  ('ml', 'Malayalam', 'മലയാളം'),
  ('gu', 'Gujarati', 'ગુજરાતી'),
  ('pa', 'Punjabi', 'ਪੰਜਾਬੀ'),
  ('en', 'English', 'English'),
];

class LanguageSelectScreen extends ConsumerStatefulWidget {
  const LanguageSelectScreen({super.key, this.fromSettings = false});

  /// True when opened from Profile's "change language" link — an
  /// already-onboarded citizen just changing a preference, who should land
  /// back on Profile afterward (and via the back button) rather than being
  /// dropped into the middle of the onboarding/signup flow.
  final bool fromSettings;

  @override
  ConsumerState<LanguageSelectScreen> createState() =>
      _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  String? _flashCode;

  Future<void> _select(String code) async {
    if (_flashCode != null) return;
    setState(() => _flashCode = code);
    await ref.read(selectedLanguageProvider.notifier).select(code);
    // Identity/sign-in now happens earlier, on the Welcome screen — by the
    // time a citizen reaches this screen they already have a `users/{uid}`
    // doc (created with a default 'en'), so sync the real choice onto it.
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      final existing = await _firestoreService.getUser(uid);
      if (existing != null) {
        await _firestoreService.upsertUser(
          existing.copyWith(preferredLanguage: code),
        );
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      context.go(widget.fromSettings ? '/profile' : '/signup/basic-info');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(widget.fromSettings ? '/profile' : '/signup'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.language_rounded,
                  size: 56, color: AppColors.trustBlue),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  itemCount: kSupportedLanguages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.6,
                  ),
                  itemBuilder: (context, index) {
                    final (code, name, native) = kSupportedLanguages[index];
                    final selected = _flashCode == code;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.marigoldOrange.withValues(alpha: 0.15)
                            : AppColors.warmOffWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? AppColors.marigoldOrange
                              : AppColors.trustBlue.withValues(alpha: 0.4),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _select(code),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  native,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
