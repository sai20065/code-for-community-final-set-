import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/storage_service.dart';
import '../../l10n/app_localizations.dart';

/// The citizen's photo bytes, loaded through the SDK so owner-only
/// `storage.rules` apply. Keyed by path; invalidate after an upload.
final avatarBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, path) async {
  try {
    return await StorageService().loadAvatar(path);
  } catch (_) {
    return null; // fall back to initials
  }
});

const _initialsColors = [
  Color(0xFF2E1F8F), // indigo
  Color(0xFF0B8A6C), // teal
  Color(0xFFC97914), // saffron deep
  Color(0xFFE0384A), // vermilion
  Color(0xFF6A3FB5), // violet
  Color(0xFF1A73E8), // blue
];

String initialsFor(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Localized title for a citizen level (1–5).
String levelTitle(int level, AppLocalizations l10n) {
  return switch (level) {
    1 => l10n.levelTitle1,
    2 => l10n.levelTitle2,
    3 => l10n.levelTitle3,
    4 => l10n.levelTitle4,
    _ => l10n.levelTitle5,
  };
}

/// Round avatar — photo if the citizen added one, otherwise coloured
/// initials — wrapped in a saffron ring showing progress to the next level.
class CitizenAvatar extends ConsumerWidget {
  const CitizenAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.levelProgress,
    this.size = 96,
    this.seed = '',
  });

  final String? name;
  final String? photoPath;

  /// 0–1; null hides the ring.
  final double? levelProgress;
  final double size;

  /// Picks a stable initials colour (e.g. the uid).
  final String seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = photoPath == null
        ? null
        : ref.watch(avatarBytesProvider(photoPath!)).valueOrNull;
    final colour = _initialsColors[
        seed.codeUnits.fold<int>(0, (a, b) => a + b) % _initialsColors.length];
    final inner = size - 12;

    final face = Container(
      width: inner,
      height: inner,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colour,
        border: Border.all(color: Colors.white, width: 3),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: bytes != null
          ? null
          : Text(
              initialsFor(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: inner * 0.36,
              ),
            ),
    );

    if (levelProgress == null) return SizedBox.square(dimension: size, child: Center(child: face));
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(levelProgress!.clamp(0.0, 1.0)),
        child: Center(child: face),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final fill = Paint()
      ..color = AppColors.saffron
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final r = rect.deflate(2);
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
