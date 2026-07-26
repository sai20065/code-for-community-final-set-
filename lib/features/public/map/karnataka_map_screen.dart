import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/public_models.dart';
import '../../../core/services/karnataka_geo_service.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import 'area_reports_sheet.dart';

/// The statewide map: **every one of Karnataka's 30 districts and 227
/// taluks**, always drawn, whether or not anyone has reported anything
/// there.
///
/// This exists because the per-constituency map answers a different
/// question. That one shows the ~8 taluks of one Lok Sabha seat, which is
/// right for an MP's briefing but makes the other 219 taluks look like
/// missing data. Coverage is itself the point here: an area with no reports
/// renders in a neutral tint with a "no reports yet" label, which is
/// information, rather than being absent, which reads as a broken map.
///
/// Geometry comes from bundled simplified assets, not Firestore — see
/// [KarnatakaGeoService] for why, and for why nothing is ever *routed* from
/// these outlines.
class KarnatakaMapScreen extends ConsumerStatefulWidget {
  const KarnatakaMapScreen({super.key});

  @override
  ConsumerState<KarnatakaMapScreen> createState() => _KarnatakaMapScreenState();
}

final _karnatakaBounds = LatLngBounds(karnatakaSouthWest, karnatakaNorthEast);

class _KarnatakaMapScreenState extends ConsumerState<KarnatakaMapScreen> {
  final _mapController = MapController();
  late final Future<KarnatakaGeo> _geoFuture = KarnatakaGeoService.instance.load();

  /// Null = the whole state. Selecting a district swaps the district
  /// outlines for that district's taluks and frames the camera on it.
  String? _districtId;
  String _districtName = '';

  void _selectDistrict(KarnatakaArea district) {
    setState(() {
      _districtId = district.id;
      _districtName = district.name;
    });
    _fit(_boundsOf(district.rings));
  }

  void _backToState() {
    setState(() {
      _districtId = null;
      _districtName = '';
    });
    _fit(_karnatakaBounds);
  }

  void _fit(LatLngBounds bounds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(28)),
      );
    });
  }

  static LatLngBounds _boundsOf(List<List<LatLng>> rings) {
    final points = rings.expand((r) => r).toList();
    return points.isEmpty
        ? _karnatakaBounds
        : LatLngBounds.fromPoints(points);
  }

  void _openTaluk(KarnatakaArea taluk, int reportCount, double? priority) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AreaReportsSheet(
        areaName: taluk.name,
        ticketField: 'talukId',
        areaId: taluk.id,
        reportCount: reportCount,
        priority: priority,
        subtitle: reportCount == 0
            ? 'No reports filed here yet · ${taluk.districtName ?? ""}'
            : '$reportCount report${reportCount == 1 ? "" : "s"} · '
                '${taluk.districtName ?? ""}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clustersAsync = ref.watch(allPublicClustersProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_districtId != null) {
              _backToState();
              return;
            }
            context.canPop() ? context.pop() : context.go('/public/dashboard');
          },
        ),
        title: Text(_districtId == null ? 'Karnataka' : _districtName),
        actions: [
          if (_districtId != null)
            TextButton.icon(
              onPressed: _backToState,
              icon: const Icon(Icons.zoom_out_map_rounded,
                  size: 17, color: Colors.white),
              label: const Text('Whole state',
                  style: TextStyle(color: Colors.white, fontSize: 12.5)),
            ),
        ],
      ),
      body: FutureBuilder<KarnatakaGeo>(
        future: _geoFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _GeoError();
          }
          final geo = snapshot.data;
          if (geo == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Report volume per taluk, rolled up to districts. Clusters with
          // no talukId (Bengaluru's are keyed by ward) simply don't
          // contribute — the statewide view is a taluk map by construction.
          final clusters =
              clustersAsync.valueOrNull ?? const <PublicClusterModel>[];
          final talukReports = <String, int>{};
          final talukPriority = <String, double>{};
          for (final c in clusters) {
            final id = c.talukId;
            if (id == null) continue;
            talukReports[id] = (talukReports[id] ?? 0) + c.submissionCount;
            final existing = talukPriority[id];
            if (existing == null || c.priorityScore > existing) {
              talukPriority[id] = c.priorityScore;
            }
          }
          final districtReports = <String, int>{};
          for (final t in geo.taluks) {
            final n = talukReports[t.id] ?? 0;
            if (n == 0) continue;
            final d = t.districtId;
            if (d == null) continue;
            districtReports[d] = (districtReports[d] ?? 0) + n;
          }

          final showingTaluks = _districtId != null;
          final areas = showingTaluks ? geo.taluksIn(_districtId!) : geo.districts;
          final counts = showingTaluks ? talukReports : districtReports;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: _karnatakaBounds,
                    padding: const EdgeInsets.all(28),
                  ),
                  minZoom: 5,
                  maxZoom: 16,
                ),
                children: [
                  appBaseTileLayer(context, style: AppMapStyle.positron),
                  PolygonLayer(
                    polygons: [
                      for (final area in areas)
                        for (final ring in area.rings)
                          Polygon(
                            points: ring,
                            color: _fillFor(
                              counts[area.id] ?? 0,
                              showingTaluks ? talukPriority[area.id] : null,
                            ),
                            borderColor: AppColors.indigoDeep
                                .withValues(alpha: 0.55),
                            borderStrokeWidth: showingTaluks ? 1.2 : 1.6,
                          ),
                    ],
                  ),
                  // The whole state stays visible as a faint outline while
                  // drilled into one district, so it never feels like the
                  // rest of Karnataka vanished.
                  if (showingTaluks)
                    PolygonLayer(
                      polygons: [
                        for (final d in geo.districts)
                          for (final ring in d.rings)
                            Polygon(
                              points: ring,
                              color: Colors.transparent,
                              borderColor:
                                  AppColors.inkFaint.withValues(alpha: 0.35),
                              borderStrokeWidth: 0.8,
                            ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final area in areas)
                        _marker(
                          area,
                          counts[area.id] ?? 0,
                          showingTaluks ? talukPriority[area.id] : null,
                          isTaluk: showingTaluks,
                        ),
                    ],
                  ),
                  appMapAttribution(),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: _CoverageBanner(
                  scopeLabel: showingTaluks ? _districtName : 'Karnataka',
                  areaCount: areas.length,
                  unitLabel: showingTaluks ? 'taluks' : 'districts',
                  withReports: areas.where((a) => (counts[a.id] ?? 0) > 0).length,
                  loading: clustersAsync.isLoading,
                ),
              ),
              const Positioned(left: 12, bottom: 12, child: _StateLegend()),
            ],
          );
        },
      ),
    );
  }

  /// Neutral indigo tint for "no reports yet" — deliberately *not* green.
  /// Green means "few open issues" everywhere else in this app, and an
  /// unreported area is not the same claim as a healthy one.
  Color _fillFor(int reports, double? priority) {
    if (reports == 0) return AppColors.indigoMist.withValues(alpha: 0.45);
    return severityColor(priority ?? 50).withValues(alpha: 0.34);
  }

  Marker _marker(
    KarnatakaArea area,
    int reports,
    double? priority, {
    required bool isTaluk,
  }) {
    final hasReports = reports > 0;
    final color =
        hasReports ? severityColor(priority ?? 50) : AppColors.indigo;
    final diameter = hasReports ? _diameter(reports) : 22.0;

    return Marker(
      point: area.center,
      width: diameter + 10,
      height: diameter + 10,
      child: GestureDetector(
        onTap: () {
          if (isTaluk) {
            _openTaluk(area, reports, priority);
          } else {
            _selectDistrict(area);
          }
        },
        child: Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasReports
                  ? color.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              border: Border.all(
                color: hasReports ? Colors.white : color.withValues(alpha: 0.5),
                width: hasReports ? 2.2 : 1.4,
              ),
              boxShadow: appCardShadow,
            ),
            alignment: Alignment.center,
            child: Text(
              hasReports ? (reports > 999 ? '999+' : '$reports') : '·',
              style: TextStyle(
                color: hasReports ? Colors.white : AppColors.indigo,
                fontSize: hasReports ? 11 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 28px at one report up to 58px at a hundred, on a log curve so a few
  /// busy districts can't swamp the state map while quiet ones stay
  /// tappable.
  double _diameter(int reports) {
    final scaled = math.log(reports + 1) / math.log(101);
    return 28 + (scaled.clamp(0.0, 1.0) * 30);
  }
}

class _CoverageBanner extends StatelessWidget {
  const _CoverageBanner({
    required this.scopeLabel,
    required this.areaCount,
    required this.unitLabel,
    required this.withReports,
    required this.loading,
  });

  final String scopeLabel;
  final int areaCount;
  final String unitLabel;
  final int withReports;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.public_rounded, size: 18, color: AppColors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scopeLabel,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text(
                  loading
                      ? 'All $areaCount $unitLabel mapped · loading reports…'
                      : 'All $areaCount $unitLabel mapped · '
                          '$withReports with reports',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateLegend extends StatelessWidget {
  const _StateLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      constraints: const BoxConstraints(maxWidth: 196),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('REPORT ACTIVITY',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkFaint,
                  letterSpacing: 0.4)),
          SizedBox(height: 6),
          _LegendRow(color: AppColors.vermilion, label: 'High priority'),
          _LegendRow(color: AppColors.saffron, label: 'Moderate'),
          _LegendRow(color: AppColors.teal, label: 'Mostly resolved'),
          _LegendRow(color: AppColors.indigoMist, label: 'No reports yet'),
          SizedBox(height: 7),
          Text(
            'Tap a district to open its taluks, then a taluk to read its '
            'reports.',
            style: TextStyle(
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

class _GeoError extends StatelessWidget {
  const _GeoError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_clear_rounded, size: 40, color: AppColors.inkFaint),
            SizedBox(height: 12),
            Text(
              'Could not load Karnataka boundary data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'The outlines ship with the app, so this usually means the '
              'build is missing its assets rather than a network problem.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.inkFaint, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
