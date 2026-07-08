import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/booth_model.dart';
import '../../../core/models/cluster_model.dart';
import '../../../core/models/taluk_model.dart';
import '../../../core/models/ward_model.dart';
import '../../../l10n/app_localizations.dart';
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

/// Booth-level demand map: dot size = submission volume, dot color = density
/// band (red = hotspot / amber = moderate / green = mostly resolved, from
/// `BoothModel.densityLevel`, i.e. `openIssueCount`) rather than theme, so
/// the map answers "where does this MP need to look first" at a glance.
/// Every official only ever sees their OWN constituency here, scoped via
/// `currentUserProfileProvider`. Tapping a booth highlights it and opens a
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
class ConstituencyMapScreen extends ConsumerWidget {
  const ConstituencyMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/official/dashboard'),
        ),
        title: Text(l10n.boothDemandMap),
      ),
      body: profileAsync.when(
        data: (profile) {
          final constituencyId = profile?.constituencyId;
          if (constituencyId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.notLinkedConstituency,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _BoothMap(constituencyId: constituencyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
      ),
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
    final clustersAsync = ref.watch(_clustersProvider(widget.constituencyId));

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
        // fill color below, same red/amber/green language as booth markers.
        final wardPriority = <String, double>{};
        final talukPriority = <String, double>{};
        for (final cluster in clusters) {
          final score = cluster.priorityScore;
          if (score == null) continue;
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
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.prajadhvani.app',
                ),
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
              ],
            ),
            const Positioned(
              left: 16,
              bottom: 16,
              child: _Legend(),
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

final _clustersProvider =
    StreamProvider.family<List<ClusterModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchClustersForConstituency(constituencyId);
});
