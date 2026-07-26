import 'package:cloud_functions/cloud_functions.dart';

/// Result of resolving a lat/lng against the real constituency boundary
/// dataset — null fields mean the point fell outside all 543 constituencies
/// (bad GPS fix, offshore, etc.), which callers must treat as "unresolved."
class ResolvedConstituency {
  final String constituencyId;
  final String constituencyName;
  final String state;

  /// The finer administrative layers the same lookup resolves, so a
  /// citizen's profile records which district, taluk and ward they live in
  /// rather than only their Lok Sabha seat. Null outside Karnataka (taluk /
  /// district) or outside Bengaluru (ward), which is the normal case, not an
  /// error.
  final String? districtId;
  final String? districtName;
  final String? talukId;
  final String? talukName;
  final String? wardId;
  final String? wardName;

  const ResolvedConstituency({
    required this.constituencyId,
    required this.constituencyName,
    required this.state,
    this.districtId,
    this.districtName,
    this.talukId,
    this.talukName,
    this.wardId,
    this.wardName,
  });
}

/// Calls the `resolveConstituencyForLocation` Cloud Function (see
/// `functions/src/constituencies/resolveConstituencyForLocation.ts`), which
/// does a real point-in-polygon lookup against India's 543 Lok Sabha
/// constituency boundaries. Replaces the old pincode/booth-array heuristic
/// (`LocationService.resolveConstituency`), which only ever covered the
/// handful of pincodes manually seeded into `booths` — this works for any
/// citizen anywhere in India, without needing per-pincode seed data.
class ConstituencyResolutionService {
  ConstituencyResolutionService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<ResolvedConstituency?> resolve({
    required double lat,
    required double lng,
  }) async {
    final callable = _functions.httpsCallable('resolveConstituencyForLocation');
    final response = await callable.call<Map<String, dynamic>>({
      'lat': lat,
      'lng': lng,
    });
    final data = response.data;
    final constituencyId = data['constituencyId'] as String?;
    final constituencyName = data['constituencyName'] as String?;
    final state = data['state'] as String?;
    if (constituencyId == null || constituencyName == null || state == null) {
      return null;
    }
    return ResolvedConstituency(
      constituencyId: constituencyId,
      constituencyName: constituencyName,
      state: state,
      districtId: data['districtId'] as String?,
      districtName: data['districtName'] as String?,
      talukId: data['talukId'] as String?,
      talukName: data['talukName'] as String?,
      wardId: data['wardId'] as String?,
      wardName: data['wardName'] as String?,
    );
  }
}
