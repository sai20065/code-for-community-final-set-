import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Receipt-style confirmation shown right after submission (Section 3.4) —
/// mirrors the trust citizens already place in RTI/courier tracking numbers.
/// Never let a submission complete without this. The checkmark "draws" in
/// with a bounce (PhonePe-after-payment style) and a short two-note chime
/// plays alongside it — the goal is a submission feeling like a completed,
/// trustworthy transaction, not just a form closing.
class TicketReceiptCard extends StatefulWidget {
  const TicketReceiptCard({
    super.key,
    required this.tokenId,
    required this.createdAt,
  });

  final String tokenId;
  final DateTime createdAt;

  @override
  State<TicketReceiptCard> createState() => _TicketReceiptCardState();
}

class _TicketReceiptCardState extends State<TicketReceiptCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleScale;
  late final Animation<double> _tickDraw;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _circleScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack)));
    _tickDraw = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );
    HapticFeedback.mediumImpact();
    _player.play(AssetSource('sounds/success_chime.wav'), volume: 0.7).catchError((_) {
      // Silent device / no audio focus / asset hiccup — the visual
      // confirmation must never depend on sound actually playing.
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _circleScale.value,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _CheckmarkPainter(
                      progress: _tickDraw.value,
                      color: AppColors.leafGreen,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).receiptWeGotThis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            widget.tokenId,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.createdAt.day}/${widget.createdAt.month}/${widget.createdAt.year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Draws a filled green circle (medium-sized, radius matches the previous
/// static `CircleAvatar(radius: 32)`) with a white checkmark stroked in
/// progressively as `progress` goes 0→1, rather than appearing all at once.
class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, Paint()..color = color);

    if (progress <= 0) return;

    // Checkmark proportioned relative to the circle, same shape as the
    // Material `Icons.check` glyph: short down-stroke then long up-stroke.
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.43, size.height * 0.67)
      ..lineTo(size.width * 0.74, size.height * 0.33);

    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));

    canvas.drawPath(
      drawn,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
