import 'dart:convert';

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
import '../../../core/models/public_models.dart';
import '../../../core/models/taluk_model.dart';
import '../../../core/models/ward_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import '../booth/booth_detail_sheet.dart';

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
/// good enough to plant a hotspot marker roughly in the middle of a ward/
/// taluk polygon (same "close enough" tradeoff `seedWards.ts`'s own
/// centroid helper makes server-side).
LatLng _ringCenter(List<LatLng> ring) {
  final lat = ring.map((p) => p.latitude).reduce((a, b) => a + b) / ring.length;
  final lng = ring.map((p) => p.longitude).reduce((a, b) => a + b) / ring.length;
  return LatLng(lat, lng);
}

/// Booth-level demand map: dot size = submission volume, dot color = density
/// band (red = hotspot / amber = moderate / green = mostly resolved, from
/// `BoothModel.densityLevel`, i.e. `openIssueCount`) rather than theme, so
/// the map answers "where does this MP need to look first" at a glance.
/// Scoped to whichever constituency the public dashboard is currently
/// showing (`effectivePublicConstituencyProvider`) — the same map every
/// visitor sees, signed in or not. Tapping a booth highlights it and opens a
/// callout panel (submission count, dominant theme, local context) via the
/// shared `BoothDetailSheet`.
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

/// A flame-icon pin marking a cluster that has crossed the red-tier
/// priority threshold — see `hotspotThreshold` in `_BoothMapState.build`.
/// Badges the report count so the MP knows the scale, not just that
/// "somewhere in here" is bad. Tappable: a decorative marker on a map whose
/// whole purpose is triage is a wasted affordance.
Marker _hotspotMarker(
  LatLng point,
  int submissionCount, {
  VoidCallback? onTap,
}) {
  return Marker(
    point: point,
    width: 40,
    height: 40,
    child: GestureDetector(
      onTap: onTap,
      child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.vermilion,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: appCardShadow,
          ),
          child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
        ),
        if (submissionCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.indigoDeep,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                submissionCount > 99 ? '99+' : '$submissionCount',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Same red/amber/green hotspot language as booth markers, applied to
/// wards from their highest cluster `priorityScore` — so a ward with no
/// tracked issues yet reads as neutral, not alarmingly red or misleadingly
/// green. `null` (no cluster data for this ward) gets a plain neutral tint.
Color _wardColorForPriority(double? priority) {
  if (priority == null) return AppColors.inkFaint;
  if (priority >= 70) return AppColors.vermilion;
  if (priority >= 40) return AppColors.saffron;
  return AppColors.teal;
}

/// Where to plant a cluster's hotspot pin, in descending order of fidelity.
///
/// The old code only ever attempted step 3 — a ward or taluk polygon
/// centroid — and required the cluster to carry a matching `wardId`. Since
/// no seeded cluster had one, and clusters outside Bengaluru have no ward
/// geometry at all, `hotspotMarkers` was **always empty**: a map built to
/// show where the problems are, reliably showing none of them.
///
/// Returns null only when a cluster genuinely cannot be placed, which the
/// caller surfaces as an "N off-map" count rather than hiding.
LatLng? _hotspotPointFor(
  PublicClusterModel cluster, {
  required Map<String, WardModel> wardsById,
  required Map<String, TalukModel> taluksById,
  required Map<String, BoothModel> boothsById,
}) {
  // 1. Backend-maintained mean of the cluster's own tickets. The most
  //    faithful answer, and the one the backfill guarantees for legacy data.
  final centroid = cluster.centroid;
  if (centroid != null) return LatLng(centroid.lat, centroid.lng);

  // 2. The booth the cluster belongs to.
  final booth = cluster.boothId == null ? null : boothsById[cluster.boothId!];
  if (booth != null) return LatLng(booth.lat, booth.lng);

  // 3. Ward, then taluk polygon centre.
  final wardRings =
      _extractRings(wardsById[cluster.wardId ?? '']?.boundaryGeoJson);
  if (wardRings.isNotEmpty) return _ringCenter(wardRings.first);

  final talukRings =
      _extractRings(taluksById[cluster.talukId ?? '']?.boundaryGeoJson);
  if (talukRings.isNotEmpty) return _ringCenter(talukRings.first);

  return null;
}
/// Public since this was pivoted off `/official/map` — reads only
/// `PublicClusterModel` (from `publicClusters`) plus the reference-data
/// collections (`booths`/`wards`/`taluks`/`constituencies`), all readable
/// signed-out. No `submissions`, no `users`, no auth-scoped query anywhere
/// on this screen.
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/public/dashboard'),
        ),
        title: Text(l10n.boothDemandMap),
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
                    FilledButton(
                      onPressed: () => context.go('/public/constituency'),
                      child: Text(l10n.chooseConstituency),
                    ),
                  ],
                ),
              ),
            )
          : _BoothMap(constituencyId: constituencyId),
    );
  }
}

class _BoothMap extends ConsumerStatefulWidget {
  const _BoothMap({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_BoothMap> createState() => _BoothMapState();
}

/// Bounds the initial camera to Karnataka's rough extent when no
/// constituency/ward/booth geometry is available yet at all (rather than
/// falling back to flutter_map's default world view) — a last-resort
/// fallback, not the normal path.
final _karnatakaFallbackBounds = LatLngBounds(
  const LatLng(11.5, 74.0),
  const LatLng(18.5, 78.6),
);

class _BoothMapState extends ConsumerState<_BoothMap> {
  String? _selectedBoothId;
  final _mapController = MapController();
  bool _hasFitBounds = false;

  /// Opens a cluster's detail from its hotspot pin. Booth markers already
  /// had this; hotspot pins — the markers flagging the *worst* problems on
  /// the map — were purely decorative.
  void _openClusterSheet(PublicClusterModel cluster) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HotspotClusterSheet(cluster: cluster),
    );
  }

  void _fitBoundsOnce(LatLngBounds bounds) {
    if (_hasFitBounds) return;
    _hasFitBounds = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final constituencyAsync = ref.watch(constituencyProvider(widget.constituencyId));
    final wardsAsync = ref.watch(_wardsProvider(widget.constituencyId));
    final taluksAsync = ref.watch(_taluksProvider(widget.constituencyId));
    final boothsAsync = ref.watch(_boothsProvider(widget.constituencyId));
    final clustersAsync = ref.watch(publicClustersProvider(widget.constituencyId));

    final l10n = AppLocalizations.of(context);

    // Every one of these four layers used to be read as
    // `valueOrNull ?? const []`, which turned a permission-denied or a
    // missing index into a perfectly normal-looking empty map. Surface the
    // failure instead: an empty map and a broken map must not look alike.
    final layers = [wardsAsync, taluksAsync, boothsAsync, clustersAsync];
    final failed = layers.where((a) => a.hasError).toList();
    if (failed.isNotEmpty) {
      for (final layer in failed) {
        debugPrint('Constituency map layer failed: ${layer.error}');
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
        final wards = wardsAsync.valueOrNull ?? const [];
        // Taluks are the ward-equivalent granular layer for every
        // constituency outside Bengaluru Urban, which has real ward data
        // instead — never show both on the same map.
        final taluks = wards.isEmpty ? (taluksAsync.valueOrNull ?? const []) : const <TalukModel>[];
        final booths = boothsAsync.valueOrNull ?? const [];
        final clusters = clustersAsync.valueOrNull ?? const [];

        // Highest priorityScore among a ward's/taluk's clusters — drives the
        // polygon fill colour below, same red/amber/green language as booth
        // markers. Marker report counts come straight off each cluster now,
        // so no per-unit count roll-up is needed here.
        final wardPriority = <String, double>{};
        final talukPriority = <String, double>{};
        for (final cluster in clusters) {
          final score = cluster.priorityScore;
          final wardId = cluster.wardId;
          if (wardId != null) {
            final existing = wardPriority[wardId];
            if (existing == null || score > existing) wardPriority[wardId] = score;
          }
          final talukId = cluster.talukId;
          if (talukId != null) {
            final existing = talukPriority[talukId];
            if (existing == null || score > existing) talukPriority[talukId] = score;
          }
        }
        // Explicit hotspot markers (flame icon + report count) for every
        // cluster crossing the same red-tier threshold as
        // `_wardColorForPriority` — the polygon tint alone is easy to miss
        // at a glance, especially before zooming in.
        //
        // Derived per *cluster*, via `_hotspotPointFor`'s fallback chain,
        // rather than per ward/taluk polygon. The old polygon-only approach
        // silently produced zero markers for any cluster without ward
        // geometry, which was all of them outside Bengaluru.
        const hotspotThreshold = 70.0;
        final wardsById = {for (final w in wards) w.id: w};
        final taluksById = {for (final t in taluks) t.id: t};
        final boothsById = {for (final b in booths) b.id: b};

        final hotspotClusters = clusters
            .where((c) => c.priorityScore >= hotspotThreshold)
            .toList();
        final placed = <(PublicClusterModel, LatLng)>[];
        var offMapCount = 0;
        for (final cluster in hotspotClusters) {
          final point = _hotspotPointFor(
            cluster,
            wardsById: wardsById,
            taluksById: taluksById,
            boothsById: boothsById,
          );
          if (point == null) {
            offMapCount++;
          } else {
            placed.add((cluster, point));
          }
        }
        final hotspotMarkers = placed
            .map((entry) => _hotspotMarker(
                  entry.$2,
                  entry.$1.submissionCount,
                  onTap: () => _openClusterSheet(entry.$1),
                ))
            .toList();

        final constituencyRings = _extractRings(constituency?.boundaryGeoJson);
        final wardPolygons = wards.expand((ward) {
          final color = _wardColorForPriority(wardPriority[ward.id]);
          return _extractRings(ward.boundaryGeoJson).map((ring) => Polygon(
                points: ring,
                color: color.withValues(alpha: 0.28),
                borderColor: color,
                borderStrokeWidth: 1.5,
              ));
        }).toList();
        final talukPolygons = taluks.expand((taluk) {
          final color = _wardColorForPriority(talukPriority[taluk.id]);
          return _extractRings(taluk.boundaryGeoJson).map((ring) => Polygon(
                points: ring,
                color: color.withValues(alpha: 0.28),
                borderColor: color,
                borderStrokeWidth: 1.5,
              ));
        }).toList();
        final subUnitRings = <List<LatLng>>[
          ...wards.expand((w) => _extractRings(w.boundaryGeoJson)),
          ...taluks.expand((t) => _extractRings(t.boundaryGeoJson)),
        ];
        final boothPoints = booths.map((b) => LatLng(b.lat, b.lng)).toList();

        final bounds = _boundsFromRings(constituencyRings) ??
            _boundsFromRings(subUnitRings) ??
            (boothPoints.isNotEmpty ? LatLngBounds.fromPoints(boothPoints) : null) ??
            _karnatakaFallbackBounds;
        _fitBoundsOnce(bounds);

        final maxVolume = booths
            .map((b) => b.submissionVolume)
            .fold<int>(1, (a, b) => b > a ? b : a);
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: bounds.center, initialZoom: 12),
              children: [
                // Positron rather than Voyager here: this map paints
                // coloured ward/taluk polygons and red hotspot markers on
                // top, and a near-greyscale basemap keeps those readable
                // instead of competing with them.
                appBaseTileLayer(context, style: AppMapStyle.positron),
                if (wardPolygons.isNotEmpty)
                  PolygonLayer(polygons: wardPolygons),
                if (talukPolygons.isNotEmpty)
                  PolygonLayer(polygons: talukPolygons),
                if (constituencyRings.isNotEmpty)
                  PolygonLayer(
                    polygons: constituencyRings
                        .map((ring) => Polygon(
                              points: ring,
                              color: Colors.transparent,
                              borderColor: AppColors.indigo,
                              borderStrokeWidth: 3,
                            ))
                        .toList(),
                  ),
                MarkerLayer(
                  markers: booths.map((booth) {
                    final color = _densityColor(booth.densityLevel);
                    final selected = booth.id == _selectedBoothId;
                    final size = 18.0 + (booth.submissionVolume / maxVolume) * 26.0;
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
                              color: selected ? AppColors.indigo : Colors.white,
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
                  }).toList(),
                ),
                if (hotspotMarkers.isNotEmpty)
                  MarkerLayer(markers: hotspotMarkers),
                appMapAttribution(),
              ],
            ),
            const Positioned(
              left: 16,
              bottom: 16,
              child: _Legend(),
            ),
            // Makes the hotspot layer's state legible. Without this, "no
            // hotspots" and "the hotspot layer is broken" render
            // identically — which is exactly how the empty-marker bug
            // survived unnoticed.
            Positioned(
              right: 12,
              top: 12,
              child: _LayerStatusChip(
                shown: hotspotMarkers.length,
                offMap: offMapCount,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(AppLocalizations.of(context).couldNotLoadBooths)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.openIssueDensity,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkFaint)),
          const SizedBox(height: 6),
          _LegendRow(color: AppColors.vermilion, label: l10n.densityHigh),
          _LegendRow(color: AppColors.saffron, label: l10n.densityModerate),
          _LegendRow(color: AppColors.teal, label: l10n.densityLow),
          const SizedBox(height: 6),
          Text(
            l10n.dotSizeVolume,
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkFaint, fontStyle: FontStyle.italic),
          ),
          Text(
            l10n.hotspotFlameNote,
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkFaint, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// "N hotspots · M off-map" badge.
///
/// Exists so the hotspot layer can never fail *quietly* again. A map that
/// shows nothing because there is nothing to show and a map that shows
/// nothing because its marker derivation is broken looked identical for the
/// entire life of this screen; this makes them distinguishable at a glance.
class _LayerStatusChip extends StatelessWidget {
  const _LayerStatusChip({required this.shown, required this.offMap});

  final int shown;
  final int offMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: appCardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: shown > 0 ? AppColors.vermilion : AppColors.inkFaint,
          ),
          const SizedBox(width: 5),
          Text(
            l10n.hotspotsShownCount(shown),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          if (offMap > 0) ...[
            const SizedBox(width: 6),
            Text(
              l10n.hotspotsOffMapCount(offMap),
              style: const TextStyle(fontSize: 10, color: AppColors.inkFaint),
            ),
          ],
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

/// Cluster detail reached by tapping a hotspot flame.
class _HotspotClusterSheet extends StatelessWidget {
  const _HotspotClusterSheet({required this.cluster});

  final PublicClusterModel cluster;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final priority = cluster.priorityScore;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: AppColors.vermilion, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.hotspotClusterSheetTitle,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkFaint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cluster.title ?? cluster.summaryText,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
            ),
            if (cluster.title != null && cluster.summaryText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(cluster.summaryText,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatPill(
                  icon: Icons.description_outlined,
                  label: '${cluster.submissionCount}',
                ),
                if (cluster.uniqueReporterCount > 0)
                  _StatPill(
                    icon: Icons.people_outline_rounded,
                    label: '${cluster.uniqueReporterCount}',
                  ),
                _StatPill(
                  icon: Icons.priority_high_rounded,
                  label: priority.toStringAsFixed(0),
                  color: AppColors.vermilion,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.indigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: tint)),
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

