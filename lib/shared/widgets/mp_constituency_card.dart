import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/current_user_profile_provider.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Shows the citizen which constituency their location has been matched to,
/// plus that constituency's MP name/photo — so they can see who represents
/// them before they even file a report. Falls back to a friendly "not
/// matched yet" state when `constituencyId` is null (home pincode isn't
/// covered by any seeded booth yet) rather than hiding silently.
class MpConstituencyCard extends ConsumerWidget {
  const MpConstituencyCard({super.key, required this.constituencyId});

  final String? constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (constituencyId == null) {
      return _Shell(
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.indigoMist,
              child: Icon(Icons.flag_outlined, color: AppColors.indigo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.notYetMatched,
                style: const TextStyle(color: AppColors.inkFaint, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    final constituencyAsync = ref.watch(constituencyProvider(constituencyId!));
    return constituencyAsync.when(
      data: (constituency) {
        if (constituency == null) {
          return _Shell(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.indigoMist,
                  child: Icon(Icons.flag_outlined, color: AppColors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.noMpAssignedYet,
                    style: const TextStyle(color: AppColors.inkFaint, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          );
        }
        final hasMpName = constituency.mpName != null && constituency.mpName!.isNotEmpty;
        return _Shell(
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.saffronMist,
                backgroundImage: (constituency.mpPhotoUrl != null &&
                        constituency.mpPhotoUrl!.isNotEmpty)
                    ? NetworkImage(constituency.mpPhotoUrl!)
                    : null,
                child: (constituency.mpPhotoUrl == null || constituency.mpPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person_rounded, color: AppColors.saffronDeep)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.yourConstituency(constituency.name),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasMpName ? '${l10n.yourMp}: ${constituency.mpName}' : l10n.noMpAssignedYet,
                      style: const TextStyle(color: AppColors.inkFaint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const _Shell(
        child: Row(
          children: [
            SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: child,
    );
  }
}
