import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// One administrative area — a district or a taluk — with its outline ready
/// to draw.
class KarnatakaArea {
  KarnatakaArea({
    required this.id,
    required this.name,
    required this.rings,
    this.districtId,
    this.districtName,
    this.constituencyId,
  });

  final String id;
  final String name;
  final List<List<LatLng>> rings;
  final String? districtId;
  final String? districtName;
  final String? constituencyId;

  /// Mean of the outline's vertices. Not a true area centroid — good enough
  /// to plant a label or an indicator inside the shape, the same tradeoff
  /// `seedWards.ts` makes server-side.
  late final LatLng center = _meanOf(rings);

  static LatLng _meanOf(List<List<LatLng>> rings) {
    var lat = 0.0, lng = 0.0, n = 0;
    for (final ring in rings) {
      for (final p in ring) {
        lat += p.latitude;
        lng += p.longitude;
        n++;
      }
    }
    if (n == 0) return const LatLng(15.0, 76.0);
    return LatLng(lat / n, lng / n);
  }
}

/// Karnataka's full administrative tree, ready to draw.
class KarnatakaGeo {
  const KarnatakaGeo({required this.districts, required this.taluks});

  final List<KarnatakaArea> districts;
  final List<KarnatakaArea> taluks;

  List<KarnatakaArea> taluksIn(String districtId) =>
      taluks.where((t) => t.districtId == districtId).toList();
}

/// Loads Karnataka's 30 district and 227 taluk outlines from bundled assets.
///
/// **Why assets rather than Firestore.** The `districts`/`taluks` collections
/// hold the same boundaries at full precision — about 5.5 MB of coordinates.
/// Pulling every one of them over the wire to draw a statewide overview
/// would cost megabytes and several seconds before a single polygon
/// appeared, on a screen whose whole job is to render instantly and show
/// that every part of the state is covered.
///
/// So the statewide layer ships pre-simplified (Douglas-Peucker, ~400 m
/// tolerance for districts and ~200 m for taluks — see
/// `tool/simplify_karnataka_geo.py`), which is ~750 KB for the entire state
/// and renders offline. The full-precision Firestore geometry is still what
/// the per-constituency map draws, where the extra fidelity is visible and
/// only a handful of polygons are involved.
///
/// The simplified outlines are for **display only**. Nothing routes, scores
/// or assigns a citizen to an area from them — that is always
/// point-in-polygon against the full-precision data server-side (see
/// `functions/src/lib/talukGeo.ts`), because a boundary nudged 400 m to
/// simplify a drawing must never decide whose MP hears a complaint.
class KarnatakaGeoService {
  KarnatakaGeoService._();

  static final KarnatakaGeoService instance = KarnatakaGeoService._();

  Future<KarnatakaGeo>? _cached;

  /// Parsed once per app run and shared — the decode is a few hundred
  /// milliseconds of JSON, and re-doing it on every rebuild of a map screen
  /// would be visible as a stutter.
  Future<KarnatakaGeo> load() => _cached ??= _load();

  Future<KarnatakaGeo> _load() async {
    final results = await Future.wait([
      _loadFile('assets/geo/karnataka_districts.json',
          idKey: 'districtId', nameKey: 'name'),
      _loadFile('assets/geo/karnataka_taluks.json',
          idKey: 'talukId', nameKey: 'talukName'),
    ]);
    return KarnatakaGeo(districts: results[0], taluks: results[1]);
  }

  Future<List<KarnatakaArea>> _loadFile(
    String path, {
    required String idKey,
    required String nameKey,
  }) async {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    // Properties are stored as a positional array against a `keys` header
    // rather than one object per feature: repeating five key names across
    // 227 features costs more bytes than the geometry saved by a whole
    // simplification pass.
    final keys = (decoded['keys'] as List).cast<String>();
    final features = decoded['features'] as List;

    final areas = <KarnatakaArea>[];
    for (final feature in features) {
      final map = feature as Map<String, dynamic>;
      final props = map['p'] as List;
      String? prop(String key) {
        final index = keys.indexOf(key);
        if (index < 0 || index >= props.length) return null;
        return props[index] as String?;
      }

      final rings = _ringsOf(map['g'] as Map<String, dynamic>);
      if (rings.isEmpty) continue;

      final id = prop(idKey);
      if (id == null || id.isEmpty) continue;

      areas.add(KarnatakaArea(
        id: id,
        name: prop(nameKey) ?? id,
        rings: rings,
        // Districts carry no parent district of their own; only taluks do.
        districtId: idKey == 'districtId' ? null : prop('districtId'),
        districtName: prop('districtName'),
        constituencyId: prop('constituencyId'),
      ));
    }
    return areas;
  }

  List<List<LatLng>> _ringsOf(Map<String, dynamic> geometry) {
    final type = geometry['type'] as String?;
    final coords = geometry['coordinates'] as List;
    switch (type) {
      case 'Polygon':
        return [_ring(coords.first as List)];
      case 'MultiPolygon':
        return coords.map((poly) => _ring((poly as List).first as List)).toList();
      default:
        return const [];
    }
  }

  List<LatLng> _ring(List ring) => ring.map((point) {
        final p = point as List;
        // Whole-number coordinates serialize as JSON integers, so a plain
        // `as double` throws; `num.toDouble()` handles both.
        return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
      }).toList();
}

/// Karnataka's rough extent, for framing the statewide camera. Kept as two
/// corners rather than a `LatLngBounds` so this file stays free of any
/// flutter_map dependency — it is a data loader, not a widget.
const karnatakaSouthWest = LatLng(11.5, 74.0);
const karnatakaNorthEast = LatLng(18.5, 78.6);
