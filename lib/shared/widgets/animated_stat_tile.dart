import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A stat that counts up from zero when it first appears.
///
/// Respects the OS "reduce motion" setting via
/// `MediaQuery.disableAnimationsOf`. Animated counters are a genuine
/// vestibular trigger for some people, and honouring the system preference
/// costs two lines — there's no version of this worth shipping that ignores
/// it.
class AnimatedStatTile extends StatelessWidget {
  const AnimatedStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.suffix = '',
    this.deltaLabel,
    this.icon,
    this.fullWidth = false,
  });

  final int value;
  final String label;
  final Color color;
  final String suffix;

  /// Optional "+12 this week" chip. Pass null when there's no real delta —
  /// never a fabricated one.
  final String? deltaLabel;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: reduceMotion
                    ? Text('$value$suffix', style: _valueStyle)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: value.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, animated, _) => Text(
                          '${animated.round()}$suffix',
                          style: _valueStyle,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (deltaLabel != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                deltaLabel!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _valueStyle =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
}

/// A small pulsing dot next to "live" labels.
///
/// Static when the OS asks for reduced motion — a repeating animation is
/// exactly the kind of thing that setting exists to stop.
class LivePulseDot extends StatefulWidget {
  const LivePulseDot({super.key, this.color = AppColors.teal, this.size = 8});

  final Color color;
  final double size;

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );

    if (MediaQuery.disableAnimationsOf(context)) return dot;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: dot,
    );
  }
}
