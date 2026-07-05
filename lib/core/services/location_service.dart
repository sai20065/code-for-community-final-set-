import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'pincode_lookup.dart';

/// Location = pincode entry + optional map pin drop only. Uses OpenStreetMap's
/// free Nominatim geocoding service (no API key) instead of a platform
/// geocoder, so no Google Maps billing is required anywhere in this app.
///
/// Nominatim's usage policy caps public-instance traffic at roughly 1
/// request/second and requires a descriptive `User-Agent` — callers must
/// debounce pincode-change lookups (not fire on every keystroke) to stay
/// within that policy. At real production scale this should move to a
/// self-hosted Nominatim instance.
class LocationService {
  LocationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _userAgent = 'PrajaDhvani/1.0 (contact: saikavitha1975@gmail.com)';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';

  /// Resolves a pincode to a human-readable area name using the static
  /// lookup table first, falling back to Nominatim if unknown.
  Future<String?> resolveAreaName(String pincode) async {
    final area = PincodeLookup.areaFor(pincode);
    if (area != null) return area;

    try {
      final uri = Uri.parse(
        '$_nominatimBase/search?postalcode=$pincode&country=India&format=json&addressdetails=1&limit=1',
      );
      final response = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body) as List;
      if (results.isEmpty) return null;
      final address = results.first['address'] as Map<String, dynamic>?;
      if (address == null) return null;
      final locality = address['county'] ?? address['city'] ?? address['town'];
      final state = address['state'];
      return [locality, state]
          .where((s) => s != null && (s as String).isNotEmpty)
          .join(', ');
    } catch (_) {
      return null;
    }
  }

  bool isValidPincode(String pincode) {
    return RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode);
  }

  /// Approximate lat/lng centroid for a pincode, used to center the "Confirm
  /// on map" pin-drop view. Falls back to New Delhi's centroid if geocoding
  /// is unavailable.
  Future<(double lat, double lng)> resolveCentroid(String pincode) async {
    try {
      final uri = Uri.parse(
        '$_nominatimBase/search?postalcode=$pincode&country=India&format=json&limit=1',
      );
      final response = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        if (results.isNotEmpty) {
          final lat = double.tryParse(results.first['lat'] as String);
          final lng = double.tryParse(results.first['lon'] as String);
          if (lat != null && lng != null) return (lat, lng);
        }
      }
    } catch (_) {
      // fall through to default
    }
    return (28.6139, 77.2090);
  }

  /// Looks up which MP constituency covers a pincode, by scanning `booths`
  /// for one whose `pincodesCovered` array contains it. Pure client-side
  /// Firestore query — no Cloud Function needed, since `booths` is
  /// already public-read reference data. Returns null if no booth in
  /// Firestore covers this pincode yet (reference data not seeded, or an
  /// out-of-coverage pincode) — callers must treat that as "unmapped for
  /// now," not an error.
  Future<String?> resolveConstituency(String pincode) async {
    try {
      final snapshot = await _db
          .collection('booths')
          .where('pincodesCovered', arrayContains: pincode)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data()['constituencyId'] as String?;
    } catch (_) {
      return null;
    }
  }
}
