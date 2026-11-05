import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// Google Maps directions deep link to [lat],[lng].
///
/// `origin` is deliberately omitted: Google Maps then starts from the
/// device's *current location* on its own, so this app never has to ask for
/// GPS permission or wait for a fix just to hand over a route. Uses the
/// documented cross-platform Maps URL (no API key) — it opens the Google
/// Maps app when installed, otherwise maps.google.com in the browser.
Uri googleMapsDirectionsUri(double lat, double lng) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
    'travelmode': 'driving',
  });
}

/// "Open in Google Maps" — directions from where the viewer is now to a
/// reported location. Renders nothing when there's no location to go to.
///
/// [approximate] is for public, privacy-snapped coordinates (a cluster's
/// centroid rounded to a grid cell, never a citizen's exact pin): the label
/// says so, so nobody expects to arrive at a precise doorstep.
class GoogleMapsDirectionsButton extends StatelessWidget {
  const GoogleMapsDirectionsButton({
    super.key,
    required this.lat,
    required this.lng,
    this.approximate = false,
    this.compact = false,
  });

  final double? lat;
  final double? lng;
  final bool approximate;

  /// Icon-only, for dense rows (ticket lists) where a full button won't fit.
  final bool compact;

  Future<void> _open(BuildContext context) async {
    final uri = googleMapsDirectionsUri(lat!, lng!);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).couldNotOpenMaps;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final label =
        approximate ? l10n.openInGoogleMapsApprox : l10n.openInGoogleMaps;
    if (compact) {
      return IconButton(
        tooltip: label,
        icon: const Icon(Icons.directions_rounded),
        color: const Color(0xFF1A73E8),
        onPressed: () => _open(context),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.directions_rounded, color: Color(0xFF1A73E8)),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: const Color(0xFF1A73E8),
        side: const BorderSide(color: Color(0xFF1A73E8)),
      ),
    );
  }
}
