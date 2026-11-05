import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/photo_visibility.dart';
import '../../../l10n/app_localizations.dart';
import 'photo_privacy_terms.dart';

/// Three choices for who sees a report's photo. Private is the default.
/// Picking a public option first asks the citizen to read and agree to the
/// privacy terms; if they don't agree, the choice stays as it was.
class PhotoVisibilityPicker extends StatelessWidget {
  const PhotoVisibilityPicker({
    super.key,
    required this.value,
    required this.consented,
    required this.onChanged,
  });

  final PhotoVisibility value;

  /// The citizen has already agreed to the current terms version.
  final bool consented;

  /// Called with the new choice, and `agreed: true` when the terms were just
  /// accepted.
  final void Function(PhotoVisibility choice, {bool agreed}) onChanged;

  Future<void> _pick(BuildContext context, PhotoVisibility choice) async {
    if (choice == value) return;
    if (choice.isPublic && !consented) {
      final ok = await showPhotoPrivacyTerms(context);
      if (!ok) return;
      onChanged(choice, agreed: true);
      return;
    }
    onChanged(choice, agreed: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = [
      (PhotoVisibility.private, Icons.lock_outline_rounded, l10n.photoVisPrivate, l10n.photoVisPrivateNote),
      (PhotoVisibility.publicFaces, Icons.face_retouching_off_rounded, l10n.photoVisFaces, l10n.photoVisFacesNote),
      (PhotoVisibility.publicFull, Icons.blur_on_rounded, l10n.photoVisFull, l10n.photoVisFullNote),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
          child: Text(l10n.photoVisTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: value == o.$1 ? AppColors.indigoMist : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: () => _pick(context, o.$1),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: value == o.$1 ? AppColors.indigo : AppColors.indigoMist,
                      width: value == o.$1 ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        value == o.$1
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: AppColors.indigo,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Icon(o.$2, size: 20, color: AppColors.inkSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.$3,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(o.$4,
                                style: const TextStyle(
                                    fontSize: 12, height: 1.35, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
