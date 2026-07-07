import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/language_select_screen.dart';

/// Profile: home constituency/booth/pincode/language at a glance, a privacy
/// reminder (what's stored and why), and sign-out. Nothing here lets the
/// citizen see or edit an Aadhaar number — there isn't one stored.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authService = AuthService();
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: profileAsync.when(
        data: (profile) {
          final languageEntry = kSupportedLanguages.firstWhere(
            (l) => l.$1 == (profile?.preferredLanguage ?? 'en'),
            orElse: () => ('en', 'English', 'English'),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: appCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.name ?? l10n.citizenDefault,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.flag_rounded,
                      label: l10n.homeConstituency,
                      value: profile?.constituencyId ?? l10n.notYetMatched,
                    ),
                    const Divider(height: 22),
                    _InfoRow(
                      icon: Icons.place_rounded,
                      label: l10n.homeBooth,
                      value: profile?.homeBoothName ?? l10n.notYetMatched,
                    ),
                    const Divider(height: 22),
                    _InfoRow(
                      icon: Icons.pin_drop_rounded,
                      label: l10n.pincode,
                      value: profile?.pincodeHome ?? '—',
                    ),
                    const Divider(height: 22),
                    InkWell(
                      onTap: () => context.go('/language'),
                      borderRadius: BorderRadius.circular(10),
                      child: _InfoRow(
                        icon: Icons.language_rounded,
                        label: l10n.preferredLanguage,
                        value: '${languageEntry.$3} (${languageEntry.$2})',
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.indigoMist,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_rounded, size: 18, color: AppColors.indigoDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.privacyStoreAddress,
                        style: const TextStyle(fontSize: 12, color: AppColors.indigoDeep, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await authService.signOut();
                  await ref.read(onboardingProgressProvider.notifier).reset();
                  if (context.mounted) context.go('/language');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.vermilion,
                  side: const BorderSide(color: AppColors.vermilion),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.signOutClears),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkFaint),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
