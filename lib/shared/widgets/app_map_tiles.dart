import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Which basemap a given screen wants.
enum AppMapStyle {
  /// Muted colour basemap. Roads and landmarks stay legible, which matters
  /// on the picker maps where the citizen is orienting themselves.
  voyager,

  /// Near-greyscale. Used under the constituency map's coloured ward and
  /// taluk polygons, where a colourful basemap competes with the data
  /// rather than supporting it.
  positron,
}

/// The app's single basemap definition.
///
/// CARTO raster tiles rather than raw `tile.openstreetmap.org`: they're
/// free, need no API key, and serve retina (`@2x`) tiles — but crucially
/// they're *quieter*. The default OSM style renders every road classification
/// in saturated colour, which fights the indigo/saffron/vermilion overlays
/// this app paints on top and makes a red hotspot hard to pick out.
///
/// Both OSM (map data, ODbL) and CARTO (tile rendering) require attribution.
/// [appMapAttribution] provides it; every `FlutterMap` using this layer must
/// include one of the attribution widgets below.
TileLayer appBaseTileLayer(
  BuildContext context, {
  AppMapStyle style = AppMapStyle.voyager,
}) {
  final slug = switch (style) {
    AppMapStyle.voyager => 'voyager',
    AppMapStyle.positron => 'light_all',
  };
  return TileLayer(
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/rastertiles/$slug/{z}/{x}/{y}{r}.png',
    subdomains: const ['a', 'b', 'c', 'd'],
    retinaMode: RetinaMode.isHighDensity(context),
    maxNativeZoom: 20,
    userAgentPackageName: 'com.prajadhvani.app',
  );
}

/// Full attribution for map screens with room for it.
///
/// Text-only, not tappable: linking out would mean adding `url_launcher` as
/// a dependency, and neither licence requires a clickable link — only that
/// the credit is visible.
Widget appMapAttribution() {
  return const RichAttributionWidget(
    alignment: AttributionAlignment.bottomRight,
    showFlutterMapAttribution: false,
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      TextSourceAttribution('CARTO'),
    ],
  );
}

/// Compact attribution for the small inline picker maps, where the expanding
/// `RichAttributionWidget` would cover most of the map. Still satisfies both
/// licences — attribution has to be visible, not large.
Widget appMapAttributionCompact() {
  return const SimpleAttributionWidget(
    source: Text('© OpenStreetMap · CARTO', style: TextStyle(fontSize: 9)),
    backgroundColor: Color(0xCCFFFFFF),
  );
}
