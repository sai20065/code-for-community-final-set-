import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/services/location_service.dart';

/// Pastel categorical palette for ward / taluk / district fills — the same
/// "every area its own colour" look as BBMP's printed Zones-and-Wards map.
/// Soft enough that the basemap's roads stay readable under a 35% fill.
const kAreaPalette = <Color>[
  Color(0xFF7FB3F5), // sky
  Color(0xFFF7A8C4), // rose
  Color(0xFF9FDDB0), // mint
  Color(0xFFFFCB80), // apricot
  Color(0xFFC3A6F2), // lavender
  Color(0xFF8ED8D8), // aqua
  Color(0xFFF2E27E), // butter
  Color(0xFFF5A88E), // coral
  Color(0xFFB5D88A), // lime
  Color(0xFFA6B8F2), // periwinkle
  Color(0xFFE7B8E8), // orchid
  Color(0xFFD9C3A0), // sand
];

/// A darker shade of a palette colour, for the area's border line.
Color areaBorderColor(Color fill) {
  final hsl = HSLColor.fromColor(fill);
  return hsl
      .withLightness((hsl.lightness - 0.28).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
      .toColor();
}

/// Gives every area a palette colour such that **neighbouring areas never
/// share one** — greedy graph colouring where two areas count as neighbours
/// when their bounding boxes touch or overlap.
///
/// Bounding-box adjacency over-approximates (two diagonal wards can count
/// as neighbours without sharing an edge), which only ever makes the result
/// *more* varied, never less correct. With 12 colours and Bengaluru's
/// wards having at most ~10 bbox-neighbours, a colour is always available.
///
/// Areas are processed in id order, so a ward keeps the same colour every
/// time the map opens (and on every device).
Map<String, Color> assignAreaColors(Map<String, LatLngBounds> boundsById) {
  final ids = boundsById.keys.toList()..sort();
  // ~100 m of slack so wards that share an edge but whose boxes are a
  // floating-point hair apart still count as touching.
  const slack = 0.001;
  bool touches(LatLngBounds a, LatLngBounds b) =>
      a.west <= b.east + slack &&
      b.west <= a.east + slack &&
      a.south <= b.north + slack &&
      b.south <= a.north + slack;

  final assigned = <String, int>{};
  for (final id in ids) {
    final box = boundsById[id]!;
    final used = <int>{
      for (final other in assigned.entries)
        if (touches(box, boundsById[other.key]!)) other.value,
    };
    var colour = 0;
    while (used.contains(colour) && colour < kAreaPalette.length - 1) {
      colour++;
    }
    assigned[id] = colour;
  }
  return {
    for (final e in assigned.entries) e.key: kAreaPalette[e.value],
  };
}

/// Pulsing blue "you are here" dot, Google-Maps style.
class YouAreHereMarker extends StatefulWidget {
  const YouAreHereMarker({super.key});

  @override
  State<YouAreHereMarker> createState() => _YouAreHereMarkerState();
}

class _YouAreHereMarkerState extends State<YouAreHereMarker>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A73E8);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 16 + 28 * t,
              height: 16 + 28 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withValues(alpha: 0.35 * (1 - t)),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: appCardShadow,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Marker for the viewer's own position. Size matches the pulse's max.
Marker youAreHereMarker(LatLng point) => Marker(
      point: point,
      width: 48,
      height: 48,
      child: const IgnorePointer(child: YouAreHereMarker()),
    );

/// Asks for the device location once (with the usual permission prompt).
/// Returns null when the viewer says no or there's no fix — the map then
/// just doesn't show the dot.
Future<LatLng?> fetchViewerLocation() async {
  try {
    final fix = await LocationService().getCurrentLatLng();
    if (fix == null) return null;
    return LatLng(fix.$1, fix.$2);
  } catch (_) {
    return null;
  }
}

/// A teardrop map pin with an icon, for individual report locations.
class ReportPin extends StatelessWidget {
  const ReportPin({
    super.key,
    required this.color,
    required this.icon,
    this.count,
  });

  final Color color;
  final IconData icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Icon(Icons.location_on, size: 42, color: color, shadows: const [
          Shadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2)),
        ]),
        Positioned(
          top: 8,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
        ),
        if ((count ?? 0) > 1)
          Positioned(
            top: -2,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}
