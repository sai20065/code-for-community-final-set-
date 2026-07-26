import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/current_user_profile_provider.dart'
    show constituencyProvider, firestoreServiceProvider;
import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/booth_model.dart';
import '../../../core/models/constituency_model.dart';
import '../../../core/models/public_models.dart';
import '../../../core/models/taluk_model.dart';
import '../../../core/models/ward_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import '../booth/booth_detail_sheet.dart';
import 'area_reports_sheet.dart';

// ---------------------------------------------------------------------------
// GeoJSON → LatLng
// ---------------------------------------------------------------------------

/// Extracts every polygon's outer ring (holes ignored — this is an outline
/// overlay for orientation, not an exact area render) as a list of
/// lat/lng rings, from a JSON-encoded GeoJSON geometry that may be a
/// `Polygon`, `MultiPolygon`, or `GeometryCollection` of either (a handful
/// of Bengaluru wards have disjoint parts and serialize as the latter).
List<List<LatLng>> _extractRings(String? geoJsonString) {
  if (geoJsonString == null) return [];
  // Defensive: one malformed/unexpected geometry (bad data, a shape this
  // parser doesn't handle yet) must never crash the whole map — skip just
  // that ring instead.
  try {
    final geometry = jsonDecode(geoJsonString) as Map<String, dynamic>;
    return _ringsFromGeometry(geometry);
  } catch (_) {
    return [];
  }
}

List<List<LatLng>> _ringsFromGeometry(Map<String, dynamic> geometry) {
  final type = geometry['type'] as String?;
  switch (type) {
    case 'Polygon':
      final coords = geometry['coordinates'] as List;
      final outerRing = coords.first as List;
      return [_ringToLatLng(outerRing)];
    case 'MultiPolygon':
      final coords = geometry['coordinates'] as List;
      return coords.map((polygon) {
        final outerRing = (polygon as List).first as List;
        return _ringToLatLng(outerRing);
      }).toList();
    case 'GeometryCollection':
      final geometries = geometry['geometries'] as List;
      return geometries
          .expand((g) => _ringsFromGeometry(g as Map<String, dynamic>))
          .toList();
    default:
      return [];
  }
}

List<LatLng> _ringToLatLng(List ring) {
  return ring.map((point) {
    final p = point as List;
    // Coordinates that happen to be whole numbers (e.g. 13.0) serialize as
    // a JSON integer, not a float — jsonDecode then hands back a Dart
    // `int`, and a plain `as double` throws. `num.toDouble()` handles both.
    return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
  }).toList();
}

LatLngBounds? _boundsFromRings(List<List<LatLng>> rings) {
  final points = rings.expand((r) => r).toList();
  if (points.isEmpty) return null;
  return LatLngBounds.fromPoints(points);
}

/// Average-of-vertices center of a ring — not a true area centroid, just
/// good enough to plant an indicator roughly in the middle of a ward/taluk
/// polygon (same "close enough" tradeoff `seedWards.ts`'s own centroid
/// helper makes server-side).
LatLng _ringCenter(List<LatLng> ring) {
  final lat = ring.map((p) => p.latitude).reduce((a, b) => a + b) / ring.length;
  final lng = ring.map((p) => p.longitude).reduce((a, b) => a + b) / ring.length;
  return LatLng(lat, lng);
}

// ---------------------------------------------------------------------------
// Colour language
// ---------------------------------------------------------------------------

/// Booth pins keep their own three-band scale, which comes from
/// `BoothModel.densityLevel` (a precomputed string) rather than a numeric
/// priority — same colours as [severityColor], different input.
Color _densityColor(String level) {
  switch (level) {
    case 'red':
      return AppColors.vermilion;
    case 'amber':
      return AppColors.saffron;
    default:
      return AppColors.teal;
  }
}

// ---------------------------------------------------------------------------
// Area rollup — one clickable indicator per ward/taluk
// ---------------------------------------------------------------------------

/// Which sub-unit layer a constituency's map is drawn from.
///
/// Never both at once: Bengaluru Urban has real GBA ward geometry, and every
/// other constituency has taluks. Showing both would double-paint the same
/// ground.
enum _AreaLayer { ward, taluk }

/// One ward or taluk, with its geometry, its representatives and the tickets
/// rolled up inside it — the unit behind every circle indicator on the map.
class _MapArea {
  _MapArea({
    required this.layer,
    required this.id,
    required this.name,
    required this.rings,
    required this.center,
    this.assemblyConstituency,
    this.mlaName,
  });

  final _AreaLayer layer;
  final String id;
  final String name;
  final List<List<LatLng>> rings;
  final LatLng center;
  final String? assemblyConstituency;
  final String? mlaName;
  /// Mutated during the single roll-up pass in `_buildAreas`, which is the
  /// only writer.
  int reportCount = 0;
  double? priority;

  /// The `publicTickets` field this area is queried by. Ward and taluk ids
  /// live in different columns, so the indicator has to say which.
  String get ticketField => layer == _AreaLayer.ward ? 'wardId' : 'talukId';
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// The area map: district/taluk (or BBMP ward) boundaries, colour-coded by
/// how bad things are, with a tappable indicator on every area that has
/// reports.
///
/// Public since this was pivoted off `/official/map` — reads only
/// `PublicClusterModel`/`PublicTicketModel` (from `publicClusters` and
/// `publicTickets`) plus the reference-data collections
/// (`booths`/`wards`/`taluks`/`constituencies`), all readable signed-out. No
/// `submissions`, no `users`, no auth-scoped query anywhere on this screen.
class ConstituencyMapScreen extends ConsumerWidget {
  const ConstituencyMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final constituencyId = ref.watch(effectivePublicConstituencyProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/public/dashboard'),
        ),
        title: Text(l10n.boothDemandMap),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Change area',
            onPressed: () => context.go('/public/area'),
          ),
        ],
      ),
      body: constituencyId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.chooseConstituency, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/public/area'),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('Pick a district'),
                    ),
                  ],
                ),
              ),
            )
          : _AreaMap(constituencyId: constituencyId),
    );
  }
}

class _AreaMap extends ConsumerStatefulWidget {
  const _AreaMap({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_AreaMap> createState() => _AreaMapState();
}

/// Bounds the initial camera to Karnataka's rough extent when no
/// constituency/ward/booth geometry is available yet at all (rather than
/// falling back to flutter_map's default world view) — a last-resort
/// fallback, not the normal path.
final _karnatakaFallbackBounds = LatLngBounds(
  const LatLng(11.5, 74.0),
  const LatLng(18.5, 78.6),
);

/// The category chips across the top of the map, in the order they appear.
/// Same ids as `kThemeLabels` so the chip, the marker and the report row all
/// take their colour and icon from one place.
const _kMapThemes = [
  'roads',
  'water',
  'electricity',
  'sanitation',
  'health',
  'education',
  'skilling',
];

class _AreaMapState extends ConsumerState<_AreaMap> {
  final _mapController = MapController();
  String? _selectedBoothId;
  String? _fittedKey;
  bool _showBoothPins = true;

  /// Null means "every category". Filtering narrows which clusters roll up
  /// into each area, so both the polygon tint and the indicator count answer
  /// the same question the chip asks.
  String? _themeFilter;

  /// Frames the camera once per distinct target, so switching area in the
  /// picker re-frames but a rebuild from a stream tick does not yank the map
  /// out from under someone who has panned away.
  void _fitBoundsOnce(String key, LatLngBounds bounds) {
    if (_fittedKey == key) return;
    _fittedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36)),
      );
    });
  }

  void _openAreaSheet(_MapArea area) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AreaReportsSheet(
        areaName: area.name,
        ticketField: area.ticketField,
        areaId: area.id,
        reportCount: area.reportCount,
        priority: area.priority,
        icon: area.layer == _AreaLayer.ward
            ? Icons.holiday_village_rounded
            : Icons.location_city_rounded,
        representativeLine: [
          if ((area.mlaName ?? '').isNotEmpty) area.mlaName!,
          if ((area.assemblyConstituency ?? '').isNotEmpty)
            area.assemblyConstituency!,
        ].join(' · '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final constituencyAsync =
        ref.watch(constituencyProvider(widget.constituencyId));
    final wardsAsync = ref.watch(_wardsProvider(widget.constituencyId));
    final taluksAsync = ref.watch(_taluksProvider(widget.constituencyId));
    final boothsAsync = ref.watch(_boothsProvider(widget.constituencyId));
    final clustersAsync = ref.watch(publicClustersProvider(widget.constituencyId));
    final selectedArea = ref.watch(selectedAreaProvider);

    final l10n = AppLocalizations.of(context);

    // Every one of these four layers used to be read as
    // `valueOrNull ?? const []`, which turned a permission-denied or a
    // missing index into a perfectly normal-looking empty map. Surface the
    // failure instead: an empty map and a broken map must not look alike.
    final layers = [wardsAsync, taluksAsync, boothsAsync, clustersAsync];
    final failed = layers.where((a) => a.hasError).toList();
    if (failed.isNotEmpty) {
      for (final layer in failed) {
        debugPrint('Area map layer failed: ${layer.error}');
      }
      return _MapErrorState(
        message: l10n.mapLayerFailed,
        retryLabel: l10n.mapRetry,
        onRetry: () {
          ref.invalidate(_wardsProvider(widget.constituencyId));
          ref.invalidate(_taluksProvider(widget.constituencyId));
          ref.invalidate(_boothsProvider(widget.constituencyId));
          ref.invalidate(publicClustersProvider(widget.constituencyId));
        },
      );
    }

    return constituencyAsync.when(
      data: (constituency) {
        final wards = wardsAsync.valueOrNull ?? const <WardModel>[];
        // Taluks are the ward-equivalent granular layer for every
        // constituency outside Bengaluru Urban, which has real ward data
        // instead — never show both on the same map.
        final taluks = wards.isEmpty
            ? (taluksAsync.valueOrNull ?? const <TalukModel>[])
            : const <TalukModel>[];
        final booths = boothsAsync.valueOrNull ?? const <BoothModel>[];
        final allClusters =
            clustersAsync.valueOrNull ?? const <PublicClusterModel>[];
        final clusters = _themeFilter == null
            ? allClusters
            : allClusters.where((c) => c.theme == _themeFilter).toList();

        final areas = _buildAreas(wards: wards, taluks: taluks, clusters: clusters);
        final areasById = {for (final a in areas) a.id: a};

        final constituencyRings = _extractRings(constituency?.boundaryGeoJson);
        final highlighted =
            selectedArea == null ? null : areasById[selectedArea.id];

        // Frame on the chosen ward/taluk if there is one, else the whole
        // constituency, else whatever geometry exists at all.
        final focusBounds = (highlighted == null
                ? null
                : _boundsFromRings(highlighted.rings)) ??
            _boundsFromRings(constituencyRings) ??
            _boundsFromRings([for (final a in areas) ...a.rings]) ??
            (booths.isNotEmpty
                ? LatLngBounds.fromPoints(
                    booths.map((b) => LatLng(b.lat, b.lng)).toList())
                : null) ??
            _karnatakaFallbackBounds;
        _fitBoundsOnce(
          '${widget.constituencyId}|${highlighted?.id ?? ''}',
          focusBounds,
        );

        final maxVolume = booths
            .map((b) => b.submissionVolume)
            .fold<int>(1, (a, b) => b > a ? b : a);

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: focusBounds.center,
                initialZoom: 11,
                // Tapping bare map dismisses the booth highlight, so a
                // selection is never stuck on.
                onTap: (_, __) {
                  if (_selectedBoothId != null) {
                    setState(() => _selectedBoothId = null);
                  }
                },
              ),
              children: [
                // Voyager rather than the near-greyscale Positron: the
                // polygon fills below are translucent, so a basemap with
                // real green parks, blue water and legible road colour reads
                // as a map of a place rather than a chart.
                appBaseTileLayer(context, style: AppMapStyle.voyager),
                if (areas.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      for (final area in areas)
                        for (final ring in area.rings)
                          Polygon(
                            points: ring,
                            color: severityColor(area.priority)
                                .withValues(alpha: 0.22),
                            borderColor: severityColor(area.priority)
                                .withValues(alpha: 0.85),
                            borderStrokeWidth: 1.4,
                          ),
                    ],
                  ),
                if (highlighted != null)
                  PolygonLayer(
                    polygons: [
                      for (final ring in highlighted.rings)
                        Polygon(
                          points: ring,
                          color: AppColors.saffron.withValues(alpha: 0.18),
                          borderColor: AppColors.saffronDeep,
                          borderStrokeWidth: 3.5,
                        ),
                    ],
                  ),
                if (constituencyRings.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      for (final ring in constituencyRings)
                        Polygon(
                          points: ring,
                          color: Colors.transparent,
                          borderColor: AppColors.indigoDeep,
                          borderStrokeWidth: 3,
                        ),
                    ],
                  ),
                if (_showBoothPins)
                  MarkerLayer(
                    markers: [
                      for (final booth in booths)
                        _boothMarker(booth, maxVolume),
                    ],
                  ),
                // Area indicators sit above everything else: they are the
                // primary affordance on this screen and must never end up
                // underneath a booth pin.
                MarkerLayer(
                  markers: [
                    for (final area in areas.where((a) => a.reportCount > 0))
                      _areaIndicator(area),
                  ],
                ),
                appMapAttribution(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 12,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _RepresentativesBanner(
                      constituency: constituency,
                      area: highlighted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ThemeFilterBar(
                    selected: _themeFilter,
                    counts: _clusterCountsByTheme(allClusters),
                    onSelect: (theme) => setState(
                      () => _themeFilter = _themeFilter == theme ? null : theme,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: _Legend(
                areaCount: areas.where((a) => a.reportCount > 0).length,
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                children: [
                  _MapChipButton(
                    icon: _showBoothPins
                        ? Icons.location_on_rounded
                        : Icons.location_off_rounded,
                    tooltip: 'Toggle booth pins',
                    active: _showBoothPins,
                    onTap: () =>
                        setState(() => _showBoothPins = !_showBoothPins),
                  ),
                  const SizedBox(height: 8),
                  _MapChipButton(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: 'Recentre',
                    active: false,
                    onTap: () => _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: focusBounds,
                        padding: const EdgeInsets.all(36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          Center(child: Text(AppLocalizations.of(context).couldNotLoadBooths)),
    );
  }

  /// Report totals per category, for the chip badges. Always computed from
  /// the *unfiltered* clusters — a chip that showed zero the moment you
  /// selected a different one would be useless for deciding what to look at
  /// next.
  Map<String, int> _clusterCountsByTheme(List<PublicClusterModel> clusters) {
    final counts = <String, int>{};
    for (final c in clusters) {
      counts[c.theme] = (counts[c.theme] ?? 0) + c.submissionCount;
    }
    return counts;
  }

  /// Rolls ward/taluk geometry together with the clusters sitting inside it,
  /// so one pass produces both the polygon colour and the indicator badge.
  List<_MapArea> _buildAreas({
    required List<WardModel> wards,
    required List<TalukModel> taluks,
    required List<PublicClusterModel> clusters,
  }) {
    final areas = <_MapArea>[];

    for (final ward in wards) {
      final rings = _extractRings(ward.boundaryGeoJson);
      if (rings.isEmpty) continue;
      areas.add(_MapArea(
        layer: _AreaLayer.ward,
        id: ward.id,
        name: ward.wardName,
        rings: rings,
        center: _ringCenter(rings.first),
        assemblyConstituency: ward.assemblyConstituency,
        mlaName: ward.mlaName,
      ));
    }
    for (final taluk in taluks) {
      final rings = _extractRings(taluk.boundaryGeoJson);
      if (rings.isEmpty) continue;
      areas.add(_MapArea(
        layer: _AreaLayer.taluk,
        id: taluk.id,
        name: taluk.talukName,
        rings: rings,
        center: _ringCenter(rings.first),
        assemblyConstituency: taluk.assemblyConstituency,
        mlaName: taluk.mlaName,
      ));
    }

    final byId = {for (final a in areas) a.id: a};
    for (final cluster in clusters) {
      final area = byId[cluster.wardId] ?? byId[cluster.talukId];
      if (area == null) continue;
      area.reportCount += cluster.submissionCount;
      final current = area.priority;
      if (current == null || cluster.priorityScore > current) {
        area.priority = cluster.priorityScore;
      }
    }
    return areas;
  }

  Marker _boothMarker(BoothModel booth, int maxVolume) {
    final color = _densityColor(booth.densityLevel);
    final selected = booth.id == _selectedBoothId;
    final size = 16.0 + (booth.submissionVolume / maxVolume) * 20.0;
    return Marker(
      point: LatLng(booth.lat, booth.lng),
      width: size + 8,
      height: size + 8,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedBoothId = booth.id);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => BoothDetailSheet(booth: booth),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.indigoDeep : Colors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: appCardShadow,
          ),
          alignment: Alignment.center,
          child: selected
              ? Text(
                  '${booth.openIssueCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// The circle indicator sitting in the middle of a ward/taluk. Diameter
  /// grows with report volume so a glance ranks areas without reading a
  /// single number, and the ring colour is the same severity ramp as the
  /// polygon underneath it.
  Marker _areaIndicator(_MapArea area) {
    // Severity normally, but the selected category's own colour while a
    // filter is on — so a filtered map reads as "this is the water map"
    // rather than looking identical to the unfiltered one.
    final color = _themeFilter == null
        ? severityColor(area.priority)
        : categoryColor(_themeFilter!);
    final diameter = _indicatorDiameter(area.reportCount);
    return Marker(
      point: area.center,
      width: diameter + 12,
      height: diameter + 12,
      child: GestureDetector(
        onTap: () => _openAreaSheet(area),
        child: Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.95),
                  color.withValues(alpha: 0.7),
                ],
              ),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: appCardShadow,
            ),
            alignment: Alignment.center,
            child: Text(
              area.reportCount > 999 ? '999+' : '${area.reportCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 30px at one report up to 62px at a hundred, on a log curve so a handful
/// of huge areas can't swamp the map while small ones stay tappable.
double _indicatorDiameter(int reportCount) {
  final scaled = math.log(reportCount + 1) / math.log(101);
  return 30 + (scaled.clamp(0.0, 1.0) * 32);
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

/// Who represents the area currently in view — MP for the constituency, MLA
/// for the highlighted ward/taluk.
class _RepresentativesBanner extends StatelessWidget {
  const _RepresentativesBanner({required this.constituency, required this.area});

  final ConstituencyModel? constituency;
  final _MapArea? area;

  @override
  Widget build(BuildContext context) {
    if (constituency == null && area == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (constituency != null)
            _RepRow(
              tint: AppColors.indigo,
              badge: 'MP',
              area: constituency!.name,
              person: constituency!.mpName,
            ),
          if (constituency != null && area != null)
            const Divider(height: 14, thickness: 0.6),
          if (area != null)
            _RepRow(
              tint: AppColors.saffronDeep,
              badge: 'MLA',
              area: (area!.assemblyConstituency ?? '').isEmpty
                  ? area!.name
                  : '${area!.name} · ${area!.assemblyConstituency}',
              person: area!.mlaName,
            ),
        ],
      ),
    );
  }
}

class _RepRow extends StatelessWidget {
  const _RepRow({
    required this.tint,
    required this.badge,
    required this.area,
    required this.person,
  });

  final Color tint;
  final String badge;
  final String area;
  final String? person;

  @override
  Widget build(BuildContext context) {
    final name = (person ?? '').trim();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: tint,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                area,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              Text(
                // An unseeded roster shows "Not yet recorded" rather than a
                // blank line that reads like a rendering bug.
                name.isEmpty ? 'Representative not yet recorded' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: name.isEmpty ? AppColors.inkFaint : AppColors.inkSoft,
                  fontStyle: name.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontally scrolling category chips across the top of the map.
///
/// Borrowed from Namma KASA's complaint map, where the category filter sits
/// on the map itself rather than behind a menu — on a civic map the first
/// question is almost always "show me the water problems", and making that
/// one tap is worth the strip of screen it costs.
class _ThemeFilterBar extends StatelessWidget {
  const _ThemeFilterBar({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final String? selected;
  final Map<String, int> counts;
  final void Function(String theme) onSelect;

  @override
  Widget build(BuildContext context) {
    // Categories with nothing filed are dropped rather than shown greyed:
    // a chip that can only ever return an empty map is noise.
    final visible = _kMapThemes.where((t) => (counts[t] ?? 0) > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final theme = visible[i];
          final tint = categoryColor(theme);
          final isSelected = selected == theme;
          return Material(
            color: isSelected ? tint : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSelect(theme),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(kThemeIcons[theme],
                        size: 14, color: isSelected ? Colors.white : tint),
                    const SizedBox(width: 6),
                    Text(
                      kThemeLabels[theme] ?? theme,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${counts[theme]}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white70
                            : tint.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapChipButton extends StatelessWidget {
  const _MapChipButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.indigo : Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon,
                size: 19, color: active ? Colors.white : AppColors.inkSoft),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.areaCount});

  final int areaCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      constraints: const BoxConstraints(maxWidth: 190),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.openIssueDensity,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkFaint,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          _LegendRow(color: AppColors.vermilion, label: l10n.densityHigh),
          _LegendRow(color: AppColors.saffron, label: l10n.densityModerate),
          _LegendRow(color: AppColors.teal, label: l10n.densityLow),
          const SizedBox(height: 7),
          Text(
            // Makes the indicator layer's state legible. Without this, "no
            // areas have reports" and "the indicator layer is broken" render
            // identically — which is how an empty-marker bug survived
            // unnoticed on this screen once already.
            areaCount == 0
                ? 'No areas with reports yet'
                : 'Tap a circle to read the $areaCount '
                    'area${areaCount == 1 ? "" : "s"} with reports',
            style: const TextStyle(
                fontSize: 9.5, color: AppColors.inkFaint, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Shown when any map layer's stream errors, instead of degrading to a
/// blank map. Most likely cause in practice: the `clusters` read rule
/// requires the reader's own `constituencyId` to equal the cluster's, so an
/// official whose profile constituency doesn't match sees permission-denied
/// on every cluster — previously indistinguishable from "no data yet".
class _MapErrorState extends StatelessWidget {
  const _MapErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_clear_rounded,
                size: 40, color: AppColors.inkFaint),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _boothsProvider =
    StreamProvider.family<List<BoothModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchBoothsForConstituency(constituencyId);
});

final _wardsProvider =
    StreamProvider.family<List<WardModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchWardsForConstituency(constituencyId);
});

final _taluksProvider =
    StreamProvider.family<List<TalukModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchTaluksForConstituency(constituencyId);
});
