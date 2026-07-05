import 'package:geocoding/geocoding.dart';

import 'pincode_lookup.dart';

/// Location = manual pincode entry + optional map pin drop only
/// (Section 2 — no ID document scanning of any kind is ever involved here).
class LocationService {
  const LocationService();

  /// Resolves a pincode to a human-readable area name using the static
  /// lookup table first, falling back to reverse geocoding of the pincode's
  /// approximate centroid if unknown.
  Future<String?> resolveAreaName(String pincode) async {
    final area = PincodeLookup.areaFor(pincode);
    if (area != null) return area;

    try {
      final locations = await locationFromAddress('$pincode, India');
      if (locations.isEmpty) return null;
      final placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      );
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return [p.locality, p.administrativeArea]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
    } catch (_) {
      return null;
    }
  }

  bool isValidPincode(String pincode) {
    return RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode);
  }

  /// Approximate lat/lng centroid for a pincode, used to center the "Confirm
  /// on map" draggable-pin view (Phase 2, Section 7 sub-step B). Falls back
  /// to New Delhi's centroid if geocoding is unavailable.
  Future<(double lat, double lng)> resolveCentroid(String pincode) async {
    try {
      final locations = await locationFromAddress('$pincode, India');
      if (locations.isNotEmpty) {
        return (locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {
      // fall through to default
    }
    return (28.6139, 77.2090);
  }
}
