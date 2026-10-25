import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/models/submission_model.dart';
import '../../l10n/app_localizations.dart';

/// "Suggested office to file the problem" — the line under a ticket id,
/// with links to the office's official website and email.
///
/// While [office] is still null (the backend writes it a few seconds after
/// submit) the full card shows a "finding the right office" placeholder;
/// the [compact] variant used on list cards shows nothing until it lands.
class SuggestedOfficeCard extends StatelessWidget {
  const SuggestedOfficeCard({
    super.key,
    required this.office,
    required this.tokenId,
    this.reportText,
    this.lat,
    this.lng,
    this.compact = false,
  });

  final SuggestedOffice? office;
  final String tokenId;

  /// The citizen's own words, pre-filled into the email so they only have
  /// to press send.
  final String? reportText;
  final double? lat;
  final double? lng;
  final bool compact;

  /// The pre-filled complaint email. In English on purpose — it is read by
  /// the office, not the citizen.
  static Uri mailtoFor(
    SuggestedOffice office, {
    required String tokenId,
    String? reportText,
    double? lat,
    double? lng,
  }) {
    final lines = [
      'Dear ${office.officerDesignation ?? 'Sir/Madam'},',
      '',
      'I would like to report the following civic problem '
          '(Prajadhwani ticket $tokenId):',
      '',
      if (reportText != null && reportText.trim().isNotEmpty) reportText.trim(),
      if (lat != null && lng != null) ...[
        '',
        'Location: https://maps.google.com/?q=$lat,$lng',
      ],
      '',
      'Kindly look into it. Thank you.',
    ];
    return Uri(
      scheme: 'mailto',
      path: office.email,
      // Built by hand: Uri's queryParameters encodes spaces as '+', which
      // mail apps show literally.
      query: 'subject=${Uri.encodeComponent('Civic complaint - Prajadhwani ticket $tokenId')}'
          '&body=${Uri.encodeComponent(lines.join('\n'))}',
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uri.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final o = office;
    if (o == null) {
      if (compact) return const SizedBox.shrink();
      return _Shell(
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.findingOffice,
                style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      );
    }

    if (compact) {
      return Row(
        children: [
          const Icon(Icons.account_balance_rounded, size: 13, color: AppColors.indigoDeep),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${l10n.suggestedOfficeTitle}: ${o.shortName ?? o.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.indigoDeep, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final website = o.websiteUrl == null ? null : Uri.tryParse(o.websiteUrl!);
    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.suggestedOfficeTitle,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.account_balance_rounded, size: 18, color: AppColors.indigoDeep),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    if (o.officerDesignation != null)
                      Text(
                        o.officerDesignation!,
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              if (website != null)
                _LinkButton(
                  icon: Icons.open_in_new_rounded,
                  label: l10n.officialWebsite,
                  onTap: () => _open(context, website),
                ),
              if (o.email != null)
                _LinkButton(
                  icon: Icons.mail_outline_rounded,
                  label: l10n.emailOffice,
                  onTap: () => _open(
                    context,
                    mailtoFor(o, tokenId: tokenId, reportText: reportText, lat: lat, lng: lng),
                  ),
                ),
              if (o.phone != null)
                _LinkButton(
                  icon: Icons.call_outlined,
                  label: l10n.callOffice(o.phone!),
                  onTap: () => _open(context, Uri(scheme: 'tel', path: o.phone)),
                ),
            ],
          ),
          Text(
            l10n.suggestedOfficeNote,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.indigoMist,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.indigoDeep,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
