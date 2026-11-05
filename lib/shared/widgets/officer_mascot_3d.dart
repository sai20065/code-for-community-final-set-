import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A friendly officer who turns in, salutes, stamps the citizen's ticket
/// "approved" and promises it'll be handled — shown on the confirmation
/// screen so filing a report ends on reassurance, not a bare receipt.
///
/// Drawn entirely in code (no Lottie/3D asset to license or download):
/// gradient shading and a ground shadow give the figure volume, and a
/// perspective `Matrix4` turn + idle sway make it read as 3D. Respects
/// "reduce motion" by jumping straight to the final pose. Tap to replay
/// the salute.
class OfficerMascot3D extends StatefulWidget {
  const OfficerMascot3D({
    super.key,
    required this.message,
    this.ticketLabel,
    this.size = 180,
  });

  final String message;

  /// e.g. "Your ticket: PD-…" — shown under the message in the bubble.
  final String? ticketLabel;
  final double size;

  @override
  State<OfficerMascot3D> createState() => _OfficerMascot3DState();
}

class _OfficerMascot3DState extends State<OfficerMascot3D>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _replay() {
    if (MediaQuery.of(context).disableAnimations) return;
    _intro.forward(from: 0.25);
  }

  /// Maps the intro timeline onto a sub-interval, clamped to 0..1.
  double _seg(double start, double end, [Curve curve = Curves.linear]) {
    final t = ((_intro.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _idle]),
      builder: (context, _) {
        final enter = _seg(0.0, 0.25, Curves.easeOutBack);
        final raise = _seg(0.25, 0.42, Curves.easeOutCubic);
        final lower = _seg(0.62, 0.75, Curves.easeInOutCubic);
        final salute = raise * (1 - lower);
        final stamp = _seg(0.55, 0.68, Curves.easeOutBack);
        final confetti = _seg(0.58, 1.0);
        final bubble = _seg(0.70, 0.86, Curves.elasticOut);

        final idleT = _idle.value * 2 * pi;
        final bob = sin(idleT) * 3;
        final sway = sin(idleT) * 0.09;
        final blinkPhase = (_idle.value * 2) % 1.0; // blink twice per loop
        final blink = (blinkPhase > 0.47 && blinkPhase < 0.53)
            ? 1 - ((blinkPhase - 0.5).abs() / 0.03)
            : 0.0;

        final turn = (1 - enter) * 1.1 + sway;
        final size = widget.size;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _replay,
              child: SizedBox(
                width: size * 1.6,
                height: size * 1.3,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConfettiPainter(progress: confetti),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, (1 - enter) * 40 + bob),
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(turn)
                          ..scaleByDouble(
                              0.6 + 0.4 * enter, 0.6 + 0.4 * enter, 1, 1),
                        child: SizedBox(
                          width: size,
                          height: size * 1.3,
                          child: CustomPaint(
                            painter: _OfficerPainter(
                              salute: salute,
                              stamp: stamp,
                              blink: blink,
                              shade: turn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Transform.scale(
              scale: bubble,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: bubble.clamp(0.0, 1.0),
                child: _SpeechBubble(
                  message: widget.message,
                  ticketLabel: widget.ticketLabel,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.message, this.ticketLabel});

  final String message;
  final String? ticketLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(22, 10),
          painter: _BubbleTailPainter(),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.indigo, AppColors.indigoDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: appCardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              if (ticketLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  ticketLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.saffron,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1)
      ..lineTo(0, size.height + 1)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.indigo);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The officer, painted on a 200×260 design grid scaled to the canvas.
class _OfficerPainter extends CustomPainter {
  _OfficerPainter({
    required this.salute,
    required this.stamp,
    required this.blink,
    required this.shade,
  });

  /// 0 = arm at side, 1 = hand at the cap brim.
  final double salute;

  /// 0..1 (overshooting) — the ✓ stamp landing on the clipboard.
  final double stamp;

  /// 0 = eyes open, 1 = closed.
  final double blink;

  /// Current Y-rotation; shifts the light so the turn reads as 3D.
  final double shade;

  static const _khaki = Color(0xFFC9A66B);
  static const _khakiDark = Color(0xFF8E6F3E);
  static const _khakiLight = Color(0xFFE6CC97);
  static const _skin = Color(0xFFD99A6C);
  static const _skinDark = Color(0xFFAE7148);
  static const _navy = Color(0xFF1E2A55);
  static const _navyDark = Color(0xFF111833);
  static const _gold = Color(0xFFF2C14E);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 260);
    final light = Alignment(-0.6 - shade * 0.6, -0.7);

    _ground(canvas);
    _legs(canvas);
    _torso(canvas, light);
    _clipboardArm(canvas, light);
    _head(canvas, light);
    _cap(canvas, light);
    _saluteArm(canvas);
    canvas.restore();
  }

  void _ground(Canvas canvas) {
    final rect = Rect.fromCenter(center: const Offset(100, 250), width: 130, height: 18);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0),
        ]).createShader(rect),
    );
  }

  void _legs(Canvas canvas) {
    final trousers = Paint()
      ..shader = const LinearGradient(colors: [_navy, _navyDark])
          .createShader(const Rect.fromLTWH(70, 185, 60, 60));
    canvas.drawRRect(
        RRect.fromLTRBR(72, 185, 98, 242, const Radius.circular(10)), trousers);
    canvas.drawRRect(
        RRect.fromLTRBR(102, 185, 128, 242, const Radius.circular(10)), trousers);
    final shoe = Paint()..color = const Color(0xFF15110E);
    canvas.drawOval(const Rect.fromLTRB(66, 236, 100, 250), shoe);
    canvas.drawOval(const Rect.fromLTRB(100, 236, 134, 250), shoe);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawOval(const Rect.fromLTRB(72, 238, 84, 242), shine);
    canvas.drawOval(const Rect.fromLTRB(106, 238, 118, 242), shine);
  }

  void _torso(Canvas canvas, Alignment light) {
    const body = Rect.fromLTRB(54, 108, 146, 196);
    final rrect = RRect.fromRectAndCorners(
      body,
      topLeft: const Radius.circular(30),
      topRight: const Radius.circular(30),
      bottomLeft: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: light,
          radius: 1.2,
          colors: const [_khakiLight, _khaki, _khakiDark],
          stops: const [0, 0.55, 1],
        ).createShader(body),
    );
    // Placket + buttons
    canvas.drawLine(const Offset(100, 116), const Offset(100, 182),
        Paint()
          ..color = _khakiDark.withValues(alpha: 0.6)
          ..strokeWidth = 2);
    for (final y in [130.0, 148.0, 166.0]) {
      canvas.drawCircle(Offset(100, y), 2.6, Paint()..color = _gold);
    }
    // Collar
    final collar = Paint()..color = _khakiLight;
    canvas.drawPath(
        Path()
          ..moveTo(84, 108)
          ..lineTo(100, 124)
          ..lineTo(92, 108)
          ..close(),
        collar);
    canvas.drawPath(
        Path()
          ..moveTo(116, 108)
          ..lineTo(100, 124)
          ..lineTo(108, 108)
          ..close(),
        collar);
    // Epaulettes
    final epaulette = Paint()..color = _navy;
    canvas.drawRRect(
        RRect.fromLTRBR(58, 112, 82, 120, const Radius.circular(4)), epaulette);
    canvas.drawRRect(
        RRect.fromLTRBR(118, 112, 142, 120, const Radius.circular(4)), epaulette);
    canvas.drawCircle(const Offset(66, 116), 1.8, Paint()..color = _gold);
    canvas.drawCircle(const Offset(134, 116), 1.8, Paint()..color = _gold);
    // Badge (gold star on a navy shield)
    final shield = Path()
      ..moveTo(70, 134)
      ..lineTo(88, 134)
      ..lineTo(88, 146)
      ..quadraticBezierTo(79, 156, 79, 156)
      ..quadraticBezierTo(70, 150, 70, 146)
      ..close();
    canvas.drawPath(shield, Paint()..color = _navy);
    canvas.drawPath(_star(const Offset(79, 143), 6, 2.6), Paint()..color = _gold);
    // Belt
    canvas.drawRect(const Rect.fromLTRB(54, 180, 146, 190),
        Paint()..color = const Color(0xFF5B3A1E));
    canvas.drawRRect(RRect.fromLTRBR(93, 179, 107, 191, const Radius.circular(2)),
        Paint()..color = _gold);
    // Rim light on the lit edge
    canvas.drawRRect(
      rrect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
          stops: const [0, 0.35],
        ).createShader(body),
    );
  }

  void _clipboardArm(Canvas canvas, Alignment light) {
    final sleeve = Paint()
      ..color = _khaki
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round;
    // Upper arm down the side, forearm across to hold the board.
    canvas.drawLine(const Offset(140, 124), const Offset(150, 160), sleeve);
    canvas.drawLine(const Offset(150, 160), const Offset(132, 174),
        sleeve..color = _khakiDark);

    // Clipboard
    const board = Rect.fromLTRB(110, 142, 152, 194);
    canvas.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(5)),
        Paint()..color = const Color(0xFF8B5A2B));
    const paper = Rect.fromLTRB(114, 150, 148, 190);
    canvas.drawRect(paper, Paint()..color = Colors.white);
    canvas.drawRRect(RRect.fromLTRBR(123, 139, 139, 147, const Radius.circular(2)),
        Paint()..color = const Color(0xFF9AA0A6));
    final lines = Paint()
      ..color = const Color(0xFFCBD2D9)
      ..strokeWidth = 1.6;
    for (final y in [157.0, 163.0, 169.0]) {
      canvas.drawLine(Offset(118, y), Offset(144, y), lines);
    }

    // Hand gripping the board edge
    canvas.drawCircle(const Offset(130, 176), 7.5, Paint()..color = _skin);

    // The ✓ stamp
    if (stamp > 0) {
      final s = stamp.clamp(0.0, 1.3);
      const center = Offset(131, 177);
      final scale = 1 + (1 - s.clamp(0.0, 1.0)) * 1.4;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);
      final ink = AppColors.teal.withValues(alpha: s.clamp(0.0, 1.0));
      canvas.drawCircle(Offset.zero, 11,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4);
      canvas.drawPath(
        Path()
          ..moveTo(-5.5, 0)
          ..lineTo(-1.5, 4.5)
          ..lineTo(6, -5),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
      // Ink splash ring as it lands
      final ring = s.clamp(0.0, 1.0);
      if (ring > 0.4 && ring < 1) {
        canvas.drawCircle(
          center,
          11 + (ring - 0.4) * 30,
          Paint()
            ..color = AppColors.teal.withValues(alpha: (1 - ring) * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _head(Canvas canvas, Alignment light) {
    // Neck
    canvas.drawRect(const Rect.fromLTRB(91, 96, 109, 112), Paint()..color = _skinDark);
    // Ears
    final ear = Paint()..color = _skinDark;
    canvas.drawOval(Rect.fromCenter(center: const Offset(68, 80), width: 10, height: 15), ear);
    canvas.drawOval(Rect.fromCenter(center: const Offset(132, 80), width: 10, height: 15), ear);
    // Face
    final face = Rect.fromCircle(center: const Offset(100, 78), radius: 32);
    canvas.drawOval(
      face,
      Paint()
        ..shader = RadialGradient(
          center: light,
          radius: 1.1,
          colors: const [Color(0xFFF0BE92), _skin, _skinDark],
          stops: const [0, 0.6, 1],
        ).createShader(face),
    );
    // Cheeks
    final blush = Paint()..color = const Color(0xFFE57373).withValues(alpha: 0.28);
    canvas.drawCircle(const Offset(80, 90), 6, blush);
    canvas.drawCircle(const Offset(120, 90), 6, blush);
    // Eyes (blink squashes them)
    final eyeH = 8.0 * (1 - blink) + 1.2;
    final eye = Paint()..color = const Color(0xFF221A14);
    canvas.drawOval(Rect.fromCenter(center: const Offset(88, 78), width: 7.5, height: eyeH), eye);
    canvas.drawOval(Rect.fromCenter(center: const Offset(112, 78), width: 7.5, height: eyeH), eye);
    if (blink < 0.5) {
      final glint = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(89.5, 76), 1.4, glint);
      canvas.drawCircle(const Offset(113.5, 76), 1.4, glint);
    }
    // Brows
    final brow = Paint()
      ..color = const Color(0xFF3B2A1E)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(82, 69), const Offset(93, 67.5), brow);
    canvas.drawLine(const Offset(107, 67.5), const Offset(118, 69), brow);
    // Smile — widens a little during the salute
    final smileW = 10 + salute * 3;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(100, 90), width: smileW * 2, height: 12 + salute * 3),
      0.15,
      pi - 0.3,
      false,
      Paint()
        ..color = const Color(0xFF7A3B2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _cap(Canvas canvas, Alignment light) {
    // Crown
    final crown = Path()
      ..moveTo(64, 60)
      ..quadraticBezierTo(62, 34, 100, 30)
      ..quadraticBezierTo(140, 34, 136, 60)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = RadialGradient(
          center: light,
          radius: 1.2,
          colors: const [Color(0xFF34457F), _navy, _navyDark],
        ).createShader(const Rect.fromLTRB(62, 30, 138, 62)),
    );
    // Band
    canvas.drawRect(const Rect.fromLTRB(66, 54, 134, 62), Paint()..color = _navyDark);
    canvas.drawLine(const Offset(66, 57), const Offset(134, 57),
        Paint()
          ..color = _gold
          ..strokeWidth = 1.6);
    // Visor
    canvas.drawPath(
      Path()
        ..moveTo(66, 61)
        ..quadraticBezierTo(100, 74, 134, 61)
        ..quadraticBezierTo(100, 66, 66, 61)
        ..close(),
      Paint()..color = const Color(0xFF0B0F1E),
    );
    // Emblem
    canvas.drawCircle(const Offset(100, 46), 7.5, Paint()..color = _gold);
    canvas.drawPath(_star(const Offset(100, 46), 5, 2.2), Paint()..color = _navy);
    // Highlight on the crown
    canvas.drawOval(const Rect.fromLTRB(76, 36, 96, 42),
        Paint()..color = Colors.white.withValues(alpha: 0.18));
  }

  /// The saluting arm, drawn last so the hand sits over the cap brim.
  void _saluteArm(Canvas canvas) {
    const shoulder = Offset(60, 124);
    // Upper arm swings out and up; forearm folds back toward the brim.
    final a = _lerp(0.08, 2.1, salute);
    final b = _lerp(0.0, -2.33, salute);
    final elbow = shoulder + Offset(-sin(a), cos(a)) * 36;
    final hand = elbow + Offset(-sin(b), cos(b)) * 50;

    final sleeve = Paint()
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, elbow, sleeve..color = _khaki);
    canvas.drawLine(elbow, hand, sleeve..color = salute > 0.5 ? _khakiLight : _khaki);
    // Cuff
    final cuffAt = Offset.lerp(elbow, hand, 0.82)!;
    canvas.drawCircle(cuffAt, 8.5, Paint()..color = _khakiDark);

    // Flat palm when saluting, a relaxed fist at rest.
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(-b + pi / 2 * salute);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 12 + salute * 6, height: 15 - salute * 3),
        const Radius.circular(6),
      ),
      Paint()..color = _skin,
    );
    canvas.restore();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final angle = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(angle), sin(angle)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _OfficerPainter old) =>
      old.salute != salute ||
      old.stamp != stamp ||
      old.blink != blink ||
      old.shade != shade;
}

/// Brand-coloured confetti bursting from the stamp, falling with gravity.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = [
    AppColors.saffron,
    AppColors.teal,
    AppColors.indigo,
    AppColors.vermilion,
    Color(0xFFF2C14E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rnd = Random(7);
    final origin = Offset(size.width * 0.58, size.height * 0.62);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var i = 0; i < 28; i++) {
      final angle = -pi / 2 + (rnd.nextDouble() - 0.5) * pi * 1.4;
      final speed = 90 + rnd.nextDouble() * 110;
      final spin = rnd.nextDouble() * 6;
      final t = progress;
      final pos = origin +
          Offset(cos(angle) * speed * t, sin(angle) * speed * t + 160 * t * t);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(spin * t * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 4),
          const Radius.circular(1.5),
        ),
        Paint()..color = _colors[i % _colors.length].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
