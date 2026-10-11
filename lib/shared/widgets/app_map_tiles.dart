import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// Which basemap a given screen wants.
enum AppMapStyle {
  /// Full-colour street map. Roads and landmarks stay legible, which matters
  /// on the picker maps where the citizen is orienting themselves.
  voyager,

  /// Near-greyscale. Used under the coloured ward and taluk polygons, where
  /// a colourful basemap competes with the data rather than supporting it.
  positron,
}

/// The app's single basemap definition.
///
/// **OpenFreeMap** vector tiles (https://openfreemap.org): free, no API key,
/// no usage cap, commercial use allowed. This replaced CARTO, whose tile
/// servers began answering every request with an "API KEY REQUIRED" image.
///
/// Web, and any device where the vector style fails to load, falls back to
/// the standard OpenStreetMap raster tiles — also free and keyless — so a
/// map is never blank. (`vector_map_tiles` keeps its tile cache on disk via
/// `dart:io`, which the web build doesn't have.)
///
/// OpenFreeMap, OpenMapTiles and OpenStreetMap all require visible
/// attribution; every `FlutterMap` using this layer must include
/// [appMapAttribution] or [appMapAttributionCompact].
Widget appBaseTileLayer(
  BuildContext context, {
  AppMapStyle style = AppMapStyle.voyager,
}) {
  if (kIsWeb) return _osmRasterLayer();
  return _OpenFreeMapLayer(style: style);
}

const _styleUrls = {
  AppMapStyle.voyager: 'https://tiles.openfreemap.org/styles/liberty',
  AppMapStyle.positron: 'https://tiles.openfreemap.org/styles/positron',
};

/// Style JSON is fetched once per app run, not once per map screen.
final _styleCache = <AppMapStyle, Future<Style>>{};

Future<Style> _loadStyle(AppMapStyle style) {
  return _styleCache.putIfAbsent(style, () {
    final future = StyleReader(uri: _styleUrls[style]!).read();
    // A failed load must not stay cached, or one flaky request would pin
    // the raster fallback for the rest of the session.
    future.then<void>((_) {}, onError: (Object _) => _styleCache.remove(style));
    return future;
  });
}

TileLayer _osmRasterLayer() {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    maxNativeZoom: 19,
    userAgentPackageName: 'com.prajadhvani.app',
  );
}

class _OpenFreeMapLayer extends StatelessWidget {
  const _OpenFreeMapLayer({required this.style});

  final AppMapStyle style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Style>(
      future: _loadStyle(style),
      builder: (context, snapshot) {
        final loaded = snapshot.data;
        if (loaded == null) {
          if (snapshot.hasError) {
            debugPrint('OpenFreeMap style failed, using OSM raster: '
                '${snapshot.error}');
          }
          // Still loading, or failed: the raster layer shows immediately.
          return _osmRasterLayer();
        }
        return VectorTileLayer(
          tileProviders: loaded.providers,
          theme: loaded.theme,
          sprites: loaded.sprites,
          tileOffset: TileOffset.mapbox,
          maximumZoom: 20,
        );
      },
    );
  }
}

/// Full attribution for map screens with room for it.
///
/// Text-only, not tappable: none of the licences require a clickable link,
/// only that the credit is visible.
Widget appMapAttribution() {
  return const RichAttributionWidget(
    alignment: AttributionAlignment.bottomRight,
    showFlutterMapAttribution: false,
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      TextSourceAttribution('OpenFreeMap · OpenMapTiles'),
      TextSourceAttribution('Ward boundaries: BBMP via DataMeet (CC BY-SA)'),
    ],
  );
}

/// Compact attribution for the small inline picker maps, where the expanding
/// `RichAttributionWidget` would cover most of the map. Still satisfies the
/// licences — attribution has to be visible, not large.
Widget appMapAttributionCompact() {
  return const SimpleAttributionWidget(
    source: Text('© OpenStreetMap · OpenFreeMap',
        style: TextStyle(fontSize: 9)),
    backgroundColor: Color(0xCCFFFFFF),
  );
}
