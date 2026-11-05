import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';

/// Shows the photo privacy terms and returns true only when the citizen ticks
/// "I have read and agree" and continues. Anything else (closing the sheet,
/// going back) is a no, and the photo stays private.
Future<bool> showPhotoPrivacyTerms(BuildContext context) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const PhotoPrivacyTerms(),
  );
  return agreed == true;
}

class PhotoPrivacyTerms extends StatefulWidget {
  const PhotoPrivacyTerms({super.key});

  @override
  State<PhotoPrivacyTerms> createState() => _PhotoPrivacyTermsState();
}

class _PhotoPrivacyTermsState extends State<PhotoPrivacyTerms> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final points = [
      (Icons.public_rounded, l10n.photoTermsPoint1),
      (Icons.lock_outline_rounded, l10n.photoTermsPoint2),
      (Icons.verified_user_outlined, l10n.photoTermsPoint3),
      (Icons.blur_on_rounded, l10n.photoTermsPoint4),
      (Icons.report_gmailerrorred_rounded, l10n.photoTermsPoint5),
      (Icons.undo_rounded, l10n.photoTermsPoint6),
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.photoTermsTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in points)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(p.$1, size: 20, color: AppColors.indigo),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(p.$2, style: const TextStyle(fontSize: 14, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agree,
                onChanged: (v) => setState(() => _agree = v == true),
                title: Text(l10n.photoTermsAgree,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              FilledButton(
                onPressed: _agree ? () => Navigator.of(context).pop(true) : null,
                child: Text(l10n.photoTermsAgreeButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
