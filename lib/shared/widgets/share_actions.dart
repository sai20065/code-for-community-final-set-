import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Where shared links point. The web build uses hash routing, so a route is
/// `$kPublicWebOrigin/#/public/...`.
const kPublicWebOrigin = 'https://code-for-community-e2cf2.web.app';

String publicWebLink(String route) => '$kPublicWebOrigin/#$route';

/// A pre-written post and the link it points to. Built only from public,
/// already-anonymised fields — never a citizen's own words.
class SharePost {
  const SharePost({required this.text, required this.url});

  final String text;
  final String url;

  String get full => '$text\n$url';

  // Encoded by hand: Uri's queryParameters turns spaces into '+', which
  // some of these apps show literally.
  static String _q(Map<String, String> params) =>
      params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

  Uri get xUri => Uri.parse('https://x.com/intent/post?${_q({'text': text, 'url': url})}');
  Uri get whatsAppUri => Uri.parse('https://wa.me/?${_q({'text': full})}');
  Uri get facebookUri =>
      Uri.parse('https://www.facebook.com/sharer/sharer.php?${_q({'u': url, 'quote': text})}');
}

/// "Share" (the phone's share sheet, with an image of the card when
/// [imageKey] wraps a [RepaintBoundary]) and "Post on social media" (X,
/// WhatsApp, Facebook, or copy the text for anywhere else).
class ShareActions extends StatelessWidget {
  const ShareActions({super.key, required this.post, this.imageKey, this.subject});

  final SharePost post;
  final GlobalKey? imageKey;
  final String? subject;

  Future<Uint8List?> _captureCard() async {
    final boundary = imageKey?.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    Uint8List? png;
    try {
      png = await _captureCard();
    } catch (_) {
      png = null; // the text alone still shares fine
    }
    await SharePlus.instance.share(ShareParams(
      text: post.full,
      subject: subject,
      files: png == null ? null : [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: png == null ? null : ['prajadhwani-report.png'],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) await _copy(context);
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: post.full));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).postCopied)),
      );
    }
  }

  void _openSocialSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        Widget tile(Widget leading, String label, Future<void> Function() onTap) => ListTile(
              leading: leading,
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onTap();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(const _Badge(text: 'X', color: Colors.black), l10n.shareOnX,
                  () => _open(context, post.xUri)),
              tile(const _Badge(icon: Icons.chat_rounded, color: Color(0xFF25D366)), l10n.shareOnWhatsApp,
                  () => _open(context, post.whatsAppUri)),
              tile(const _Badge(icon: Icons.facebook_rounded, color: Color(0xFF1877F2)), l10n.shareOnFacebook,
                  () => _open(context, post.facebookUri)),
              tile(const _Badge(icon: Icons.copy_rounded, color: AppColors.inkSoft), l10n.copyPostText,
                  () => _copy(context)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: () => _share(buttonContext),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(l10n.shareButton),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openSocialSheet(context),
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: Text(l10n.postOnSocial, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, this.icon, this.text});

  final Color color;
  final IconData? icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: color,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 20)
          : Text(text ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}
