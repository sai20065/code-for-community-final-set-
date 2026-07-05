import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Live waveform + pulsing ring shown while recording (Section 3.6).
/// Confirms the mic is actually capturing audio — silence/uncertainty is a
/// common trust gap that causes first-time voice-UI users to abandon.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({
    super.key,
    required this.isRecording,
    this.amplitudes = const [],
  });

  final bool isRecording;

  /// Recent amplitude samples in [0, 1]; empty renders a gentle idle pulse.
  final List<double> amplitudes;

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = widget.isRecording ? _controller.value : 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96 + pulse * 24,
              height: 96 + pulse * 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coralRed.withValues(alpha: 0.15 * (1 - pulse)),
              ),
            ),
            CustomPaint(
              size: const Size(160, 48),
              painter: _WaveformPainter(
                amplitudes: widget.amplitudes,
                animationValue: _controller.value,
                active: widget.isRecording,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.animationValue,
    required this.active,
  });

  final List<double> amplitudes;
  final double animationValue;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active ? AppColors.coralRed : Colors.grey.shade400
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const barCount = 24;
    final barWidth = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final amplitude = amplitudes.isNotEmpty
          ? amplitudes[i % amplitudes.length]
          : (0.3 + 0.3 * sin(animationValue * 2 * pi + i));
      final height = (amplitude.abs().clamp(0.05, 1.0)) * size.height;
      final x = i * barWidth + barWidth / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
