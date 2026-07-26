import 'package:flutter/material.dart';

/// The UN's official Sustainable Development Goal colours.
///
/// This is the one place in the app where stepping outside `AppColors` is
/// correct rather than sloppy: these are prescribed brand values from the
/// UN's own SDG communications guidelines, and an SDG 6 badge rendered in
/// the app's indigo instead of the official cyan simply isn't an SDG badge —
/// the colour is how the goal is recognised.
const Map<int, Color> kSdgColors = {
  1: Color(0xFFE5243B),
  2: Color(0xFFDDA63A),
  3: Color(0xFF4C9F38),
  4: Color(0xFFC5192D),
  5: Color(0xFFFF3A21),
  6: Color(0xFF26BDE2),
  7: Color(0xFFFCC30B),
  8: Color(0xFFA21942),
  9: Color(0xFFFD6925),
  10: Color(0xFFDD1367),
  11: Color(0xFFFD9D24),
  12: Color(0xFFBF8B2E),
  13: Color(0xFF3F7E44),
  14: Color(0xFF0A97D9),
  15: Color(0xFF56C02B),
  16: Color(0xFF00689D),
  17: Color(0xFF19486A),
};

/// A single SDG goal chip — the goal number in its official colour.
class SdgBadge extends StatelessWidget {
  const SdgBadge({
    super.key,
    required this.goal,
    this.label,
    this.size = 30,
  });

  final int goal;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = kSdgColors[goal] ?? Colors.grey;
    final square = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$goal',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );

    if (label == null) {
      // Still announce the goal to screen readers — a bare number in a
      // coloured square is meaningless without the goal's name.
      return Semantics(label: 'SDG $goal', child: square);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        square,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// A horizontal run of SDG badges.
class SdgBadgeRow extends StatelessWidget {
  const SdgBadgeRow({super.key, required this.goals, this.size = 28});

  final List<int> goals;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final g in goals) SdgBadge(goal: g, size: size)],
    );
  }
}
