import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/public_models.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/karnataka_geo_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import '../../../shared/widgets/map_area_palette.dart';
import '../../../shared/widgets/status_stepper.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import 'area_reports_sheet.dart';

/// Karnataka Live Report Map — **every published report in the state**,
/// streamed live from `publicTickets`, over all 30 districts.
///
/// Zoomed out, each district carries one bubble: report count, coloured by
/// how much of it is still unresolved. Zoom in (or tap a district) and the
/// bubbles give way to individual report pins — coloured by status, iconed
/// by category — that group into numbered clusters where they crowd.
///
/// Pins are never exact: the projection (`functions/src/public/projection.ts`)
/// snaps them to ~300 m, or places a lone report at its ward / taluk /
/// district centre, so no pin can point at a reporter's home.
///
/// Status, category and theme filters run on the device over one live
/// stream, so switching them is instant.
class KarnatakaMapScreen extends ConsumerStatefulWidget {
  const KarnatakaMapScreen({super.key});

  @override
  ConsumerState<KarnatakaMapScreen> createState() => _KarnatakaMapScreenState();
}

final _karnatakaBounds = LatLngBounds(karnatakaSouthWest, karnatakaNorthEast);

/// Below this zoom the map shows one bubble per district; above it,
/// individual report pins.
const _pinZoom = 8.2;

const _statusLabels = {
  'new': 'New',
  'reviewed': 'Acknowledged',
  'inProgress': 'In progress',
  'resolved': 'Resolved',
};

const _rangeLabels = {7: '7 days', 30: '30 days', 90: '90 days', 0: 'All time'};

/// Red when most of a group is still open, saffron when about half is,
/// green when it is mostly resolved.
Color openShareColor(int open, int total) {
  if (total == 0) return AppColors.indigoMist;
  final share = open / total;
  if (share > 0.6) return AppColors.vermilion;
  if (share > 0.3) return AppColors.saffronDeep;
  return AppColors.teal;
}

class _KarnatakaMapScreenState extends ConsumerState<KarnatakaMapScreen> {
  final _mapController = MapController();
  late final Future<KarnatakaGeo> _geoFuture = KarnatakaGeoService.instance.load();

  String? _districtId;
  String _districtName = '';
  LatLng? _me;
  double _zoom = 6.5;

  // Filters.
  int _days = 30;
  String? _status;
  String? _theme;
  String? _category; // null | 'problem' | 'feedback'

  @override
  void initState() {
    super.initState();
    fetchViewerLocation().then((me) {
      if (mounted && me != null) setState(() => _me = me);
    });
  }

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
    return points.isEmpty ? _karnatakaBounds : LatLngBounds.fromPoints(points);
  }

  List<PublicTicketModel> _applyFilters(List<PublicTicketModel> all) => [
        for (final t in all)
          if ((_status == null || t.status == _status) &&
              (_theme == null || t.theme == _theme) &&
              (_category == null || t.submissionCategory == _category))
            t,
      ];

  void _openTicket(PublicTicketModel t, KarnatakaGeo geo) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketSheet(ticket: t, geo: geo),
    );
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        days: _days,
        theme: _theme,
        category: _category,
        onChanged: (days, theme, category) => setState(() {
          _days = days;
          _theme = theme;
          _category = category;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(statewideTicketsProvider(_days));

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
        title: Text(_districtId == null ? 'Karnataka Live Report Map' : _districtName),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).leaderboardTitle,
            onPressed: () => context.push('/public/leaderboard'),
            icon: const Icon(Icons.leaderboard_rounded, color: Colors.white),
          ),
          if (_districtId != null)
            IconButton(
              tooltip: 'Whole state',
              onPressed: _backToState,
              icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white),
            ),
        ],
      ),
      body: FutureBuilder<KarnatakaGeo>(
        future: _geoFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _GeoError();
          final geo = snapshot.data;
          if (geo == null) return const Center(child: CircularProgressIndicator());

          final tickets = _applyFilters(ticketsAsync.valueOrNull ?? const []);
          final byId = {for (final t in tickets) t.id: t};

          // Per-district totals come straight from the tickets, so
          // Bengaluru (whose clusters carry ward ids, not taluk ids) counts
          // like every other district.
          final districtTotal = <String, int>{};
          final districtOpen = <String, int>{};
          for (final t in tickets) {
            final d = t.districtId;
            if (d == null) continue;
            districtTotal[d] = (districtTotal[d] ?? 0) + 1;
            if (t.isOpen) districtOpen[d] = (districtOpen[d] ?? 0) + 1;
          }

          final showingTaluks = _districtId != null;
          final areas = showingTaluks ? geo.taluksIn(_districtId!) : geo.districts;
          final areaColors = assignAreaColors({
            for (final a in areas) a.id: _boundsOf(a.rings),
          });
          final showPins = showingTaluks || _zoom >= _pinZoom;

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
                  maxZoom: 17,
                  onPositionChanged: (camera, _) {
                    final crossed = (camera.zoom >= _pinZoom) != (_zoom >= _pinZoom);
                    _zoom = camera.zoom;
                    if (crossed) setState(() {});
                  },
                ),
                children: [
                  appBaseTileLayer(context, style: AppMapStyle.positron),
                  PolygonLayer(
                    polygons: [
                      for (final area in areas)
                        for (final ring in area.rings)
                          Polygon(
                            points: ring,
                            color: (areaColors[area.id] ?? kAreaPalette.first)
                                .withValues(alpha: showPins ? 0.16 : 0.34),
                            borderColor: areaBorderColor(
                                areaColors[area.id] ?? kAreaPalette.first),
                            borderStrokeWidth: showingTaluks ? 1.2 : 1.5,
                          ),
                    ],
                  ),
                  if (showingTaluks)
                    PolygonLayer(
                      polygons: [
                        for (final d in geo.districts)
                          for (final ring in d.rings)
                            Polygon(
                              points: ring,
                              color: Colors.transparent,
                              borderColor: AppColors.inkFaint.withValues(alpha: 0.35),
                              borderStrokeWidth: 0.8,
                            ),
                      ],
                    ),
                  if (_me != null) MarkerLayer(markers: [youAreHereMarker(_me!)]),
                  if (!showPins)
                    MarkerLayer(
                      markers: [
                        for (final d in geo.districts)
                          _districtBubble(
                            d,
                            districtTotal[d.id] ?? 0,
                            districtOpen[d.id] ?? 0,
                          ),
                      ],
                    )
                  else
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 48,
                        size: const Size(44, 44),
                        disableClusteringAtZoom: 15,
                        showPolygon: false,
                        markers: [
                          for (final t in tickets)
                            if (t.geo != null)
                              Marker(
                                key: ValueKey(t.id),
                                point: LatLng(t.geo!.lat, t.geo!.lng),
                                width: 34,
                                height: 34,
                                child: _ReportPinIcon(ticket: t),
                              ),
                        ],
                        onMarkerTap: (m) {
                          final id = (m.key as ValueKey<String>?)?.value;
                          final t = id == null ? null : byId[id];
                          if (t != null) _openTicket(t, geo);
                        },
                        builder: (context, markers) {
                          var open = 0;
                          for (final m in markers) {
                            final id = (m.key as ValueKey<String>?)?.value;
                            if (byId[id]?.isOpen ?? false) open++;
                          }
                          return _CountBubble(
                            count: markers.length,
                            color: openShareColor(open, markers.length),
                            size: 44,
                          );
                        },
                      ),
                    ),
                  appMapAttribution(),
                ],
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: Column(
                  children: [
                    _StatsStrip(
                      tickets: tickets,
                      loading: ticketsAsync.isLoading,
                      error: ticketsAsync.hasError,
                      rangeLabel: _rangeLabels[_days] ?? '',
                    ),
                    const SizedBox(height: 8),
                    _StatusChips(
                      selected: _status,
                      activeFilters:
                          (_theme != null ? 1 : 0) + (_category != null ? 1 : 0) + (_days != 30 ? 1 : 0),
                      onStatus: (s) => setState(() => _status = s),
                      onMore: _openFilters,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: _Legend(showPins: showPins),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _districtBubble(KarnatakaArea d, int total, int open) {
    final size = total == 0 ? 24.0 : 30 + (math.log(total + 1) / math.log(301)).clamp(0.0, 1.0) * 30;
    return Marker(
      point: d.center,
      width: size + 8,
      height: size + 8,
      child: GestureDetector(
        onTap: () => _selectDistrict(d),
        child: Center(
          child: total == 0
              ? Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                    border: Border.all(color: AppColors.indigo.withValues(alpha: 0.4)),
                  ),
                  alignment: Alignment.center,
                  child: const Text('·',
                      style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w800)),
                )
              : _CountBubble(count: total, color: openShareColor(open, total), size: size),
        ),
      ),
    );
  }
}

class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count, required this.color, required this.size});

  final int count;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.92),
        border: Border.all(color: Colors.white, width: 2.4),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 999 ? '999+' : '$count',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size > 40 ? 13 : 11,
        ),
      ),
    );
  }
}

/// One report: colour = status, icon = category. Suggestions are rounded
/// squares, problems are circles, so the two read apart at a glance.
class _ReportPinIcon extends StatelessWidget {
  const _ReportPinIcon({required this.ticket});

  final PublicTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(ticket.status);
    final isSuggestion = ticket.submissionCategory == 'feedback';
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: isSuggestion ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isSuggestion ? BorderRadius.circular(9) : null,
        border: Border.all(color: Colors.white, width: 2.2),
        boxShadow: appCardShadow,
      ),
      alignment: Alignment.center,
      child: Icon(
        kThemeIcons[ticket.theme] ?? Icons.report_rounded,
        size: 17,
        color: Colors.white,
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.tickets,
    required this.loading,
    required this.error,
    required this.rangeLabel,
  });

  final List<PublicTicketModel> tickets;
  final bool loading;
  final bool error;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final total = tickets.length;
    final open = tickets.where((t) => t.isOpen).length;
    final resolvedPct = total == 0 ? 0 : (((total - open) / total) * 100).round();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final newToday = tickets.where((t) => t.createdDate == today).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LiveDot(),
              const SizedBox(width: 6),
              Text(
                error
                    ? 'Live · could not load reports'
                    : loading
                        ? 'Live · loading reports…'
                        : 'Live · $rangeLabel · updates as reports come in',
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Stat(value: '$total', label: 'Reports', color: AppColors.indigo),
              _Stat(value: '$open', label: 'Open', color: AppColors.vermilion),
              _Stat(value: '$resolvedPct%', label: 'Resolved', color: AppColors.teal),
              _Stat(value: '$newToday', label: 'New today', color: AppColors.saffronDeep),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: AppColors.vermilion, shape: BoxShape.circle),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.selected,
    required this.activeFilters,
    required this.onStatus,
    required this.onMore,
  });

  final String? selected;
  final int activeFilters;
  final ValueChanged<String?> onStatus;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    Widget chip(String? value, String label, Color color) {
      final on = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          selected: on,
          onSelected: (_) => onStatus(value),
          label: Text(label),
          avatar: value == null
              ? null
              : CircleAvatar(backgroundColor: color, radius: 5),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : AppColors.ink,
          ),
          selectedColor: value == null ? AppColors.indigo : color,
          backgroundColor: Colors.white,
          showCheckmark: false,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              onPressed: onMore,
              avatar: const Icon(Icons.tune_rounded, size: 16, color: AppColors.indigo),
              label: Text(activeFilters == 0 ? 'Filters' : 'Filters · $activeFilters'),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.indigo),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.indigoMist),
              visualDensity: VisualDensity.compact,
            ),
          ),
          chip(null, 'All', AppColors.indigo),
          for (final e in _statusLabels.entries) chip(e.key, e.value, statusColor(e.key)),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.days,
    required this.theme,
    required this.category,
    required this.onChanged,
  });

  final int days;
  final String? theme;
  final String? category;
  final void Function(int days, String? theme, String? category) onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int _days = widget.days;
  late String? _theme = widget.theme;
  late String? _category = widget.category;

  void _apply() => widget.onChanged(_days, _theme, _category);

  @override
  Widget build(BuildContext context) {
    Widget group(String title, List<Widget> chips) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
            const SizedBox(height: 14),
          ],
        );
    ChoiceChip choice(String label, bool on, VoidCallback onTap, {IconData? icon}) => ChoiceChip(
          selected: on,
          onSelected: (_) {
            onTap();
            _apply();
          },
          avatar: icon == null ? null : Icon(icon, size: 16, color: on ? Colors.white : AppColors.indigo),
          label: Text(label),
          showCheckmark: false,
          selectedColor: AppColors.indigo,
          labelStyle: TextStyle(color: on ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
        );

    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: SizedBox(
              width: 40,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: AppColors.indigoMist, borderRadius: BorderRadius.all(Radius.circular(2))),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Filter reports',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          group('Time', [
            for (final e in _rangeLabels.entries)
              choice(e.value, _days == e.key, () => setState(() => _days = e.key)),
          ]),
          group('Type', [
            choice('All', _category == null, () => setState(() => _category = null)),
            choice('Problems', _category == 'problem', () => setState(() => _category = 'problem'),
                icon: Icons.warning_amber_rounded),
            choice('Suggestions', _category == 'feedback', () => setState(() => _category = 'feedback'),
                icon: Icons.lightbulb_rounded),
          ]),
          group('Category', [
            choice('All', _theme == null, () => setState(() => _theme = null)),
            for (final e in kThemeLabels.entries)
              choice(e.value, _theme == e.key, () => setState(() => _theme = e.key),
                  icon: kThemeIcons[e.key]),
          ]),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatefulWidget {
  const _Legend({required this.showPins});

  final bool showPins;

  @override
  State<_Legend> createState() => _LegendState();
}

class _LegendState extends State<_Legend> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 210),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          boxShadow: appCardShadow,
        ),
        child: !_open
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.indigo),
                SizedBox(width: 5),
                Text('Legend', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.showPins ? 'REPORT STATUS' : 'DISTRICT BUBBLES',
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkFaint,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  if (widget.showPins) ...[
                    for (final e in _statusLabels.entries)
                      _LegendRow(color: statusColor(e.key), label: e.value),
                    const SizedBox(height: 4),
                    const Text('● problem   ■ suggestion · icon = category',
                        style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                  ] else ...[
                    const _LegendRow(color: AppColors.vermilion, label: 'Mostly unresolved'),
                    const _LegendRow(color: AppColors.saffronDeep, label: 'Partly resolved'),
                    const _LegendRow(color: AppColors.teal, label: 'Mostly resolved'),
                    const SizedBox(height: 4),
                    const Text('Number = reports. Zoom in or tap a district for pins.',
                        style: TextStyle(fontSize: 10, color: AppColors.inkSoft, height: 1.3)),
                  ],
                  const SizedBox(height: 4),
                  const Text('Locations are approximate to protect reporters.',
                      style: TextStyle(fontSize: 9.5, color: AppColors.inkFaint, height: 1.3)),
                ],
              ),
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
      padding: const EdgeInsets.only(top: 3),
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

/// Details of one report, from its public (anonymised) projection only.
class _TicketSheet extends StatelessWidget {
  const _TicketSheet({required this.ticket, required this.geo});

  final PublicTicketModel ticket;
  final KarnatakaGeo geo;

  String get _precisionNote => switch (ticket.geoPrecision) {
        'approx-300m' => 'Location approximate (within ~300 m)',
        'ward' => 'Shown at the centre of its ward',
        'taluk' => 'Shown at the centre of its taluk',
        'district' => 'Shown at the centre of its district',
        _ => 'Location not published',
      };

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    KarnatakaArea? taluk;
    KarnatakaArea? district;
    for (final a in geo.taluks) {
      if (a.id == t.talukId) taluk = a;
    }
    for (final a in geo.districts) {
      if (a.id == t.districtId) district = a;
    }
    final place = [
      if (taluk != null) taluk.name,
      if (district != null) district.name,
      if (t.constituencyName != null) t.constituencyName!,
    ].join(' · ');
    final color = statusColor(t.status);
    final isSuggestion = t.submissionCategory == 'feedback';

    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: isSuggestion ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isSuggestion ? BorderRadius.circular(10) : null,
                ),
                child: Icon(kThemeIcons[t.theme] ?? Icons.report_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isSuggestion ? "Suggestion" : "Problem"} · ${kThemeLabels[t.theme] ?? "General"}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text('${t.tokenId} · filed ${t.createdDate}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabels[t.status] ?? t.status,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t.publicSummary, style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 12),
          if (!isSuggestion) ...[
            StatusStepper(status: SubmissionModel.statusFromString(t.status), compact: true),
            const SizedBox(height: 12),
          ],
          if (place.isNotEmpty)
            Row(children: [
              const Icon(Icons.place_rounded, size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(child: Text(place, style: const TextStyle(fontSize: 12.5))),
            ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.shield_outlined, size: 16, color: AppColors.inkFaint),
            const SizedBox(width: 6),
            Text(_precisionNote, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push('/public/report/${t.id}');
              },
              icon: const Icon(Icons.badge_rounded, size: 18),
              label: Text(AppLocalizations.of(context).openReportCard),
            ),
          ),
          if (taluk != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final area = taluk!;
                  Navigator.of(context).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AreaReportsSheet(
                      areaName: area.name,
                      ticketField: 'talukId',
                      areaId: area.id,
                      reportCount: 0,
                      subtitle: area.districtName,
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text('All reports in ${taluk.name}'),
              ),
            ),
          ],
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
              style: TextStyle(fontSize: 12, color: AppColors.inkFaint, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
