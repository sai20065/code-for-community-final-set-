import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/constituency_model.dart';
import '../../core/models/district_model.dart';
import '../../core/models/public_models.dart';
import '../../core/models/solution_card_model.dart';
import '../../core/models/taluk_model.dart';
import '../../core/models/ward_model.dart';
import '../../core/services/public_data_service.dart';
export '../../core/services/public_data_service.dart' show PublicConstituencyStats;
import 'current_user_profile_provider.dart';

const kPublicConstituencyKey = 'public_constituency';

/// Which constituency the public dashboard is showing.
///
/// Resolution order, most explicit first:
///   1. a `?c=` query parameter on a shared link,
///   2. the visitor's last choice, persisted across restarts,
///   3. the signed-in user's own constituency, if there is one,
///   4. null — show the chooser.
///
/// Mirrors [SelectedLanguageNotifier]'s pattern, including the `ready`
/// future, so router redirects never act on the initial null before the
/// disk read completes and bounce a returning visitor to the chooser.
class PublicConstituencyNotifier extends StateNotifier<String?> {
  PublicConstituencyNotifier() : super(null) {
    _load();
  }

  final Completer<void> _readyCompleter = Completer<void>();

  Future<void> get ready => _readyCompleter.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(kPublicConstituencyKey);
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  Future<void> select(String constituencyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPublicConstituencyKey, constituencyId);
    state = constituencyId;
  }

  /// Adopts a constituency from a shared link without overwriting an
  /// explicit earlier choice on disk until the visitor actually browses.
  void adoptFromLink(String constituencyId) {
    if (state != constituencyId) state = constituencyId;
  }
}

final publicConstituencyProvider =
    StateNotifierProvider<PublicConstituencyNotifier, String?>(
  (ref) => PublicConstituencyNotifier(),
);

/// The constituency the public dashboard should actually render, falling
/// back to the signed-in user's own. Separate from the notifier so a
/// signed-in citizen lands on their own area without a stored preference.
final effectivePublicConstituencyProvider = Provider<String?>((ref) {
  final explicit = ref.watch(publicConstituencyProvider);
  if (explicit != null) return explicit;
  return ref.watch(currentUserProfileProvider).valueOrNull?.constituencyId;
});

final publicDataServiceProvider = Provider<PublicDataService>(
  (ref) => PublicDataService(),
);

final publicClustersProvider =
    StreamProvider.family<List<PublicClusterModel>, String>(
  (ref, constituencyId) =>
      ref.watch(publicDataServiceProvider).watchClusters(constituencyId),
);

final publicConstituencyStatsProvider =
    StreamProvider.family<PublicConstituencyStats, String>(
  (ref, constituencyId) =>
      ref.watch(publicDataServiceProvider).watchStats(constituencyId),
);

final publicTopHotspotsProvider =
    StreamProvider.family<List<PublicClusterModel>, String>(
  (ref, constituencyId) =>
      ref.watch(publicDataServiceProvider).watchTopHotspots(constituencyId),
);

final publicRecentTicketsProvider =
    StreamProvider.family<List<PublicTicketModel>, String>(
  (ref, constituencyId) => ref
      .watch(publicDataServiceProvider)
      .watchRecentTickets(constituencyId),
);

/// Every public ticket inside one ward/taluk — the list a map area indicator
/// opens. Keyed by `"wardId:blr-1"` / `"talukId:2903"` so one family covers
/// both layers without a second provider.
final publicTicketsForAreaProvider =
    StreamProvider.family<List<PublicTicketModel>, String>((ref, key) {
  final separator = key.indexOf(':');
  final field = key.substring(0, separator);
  final areaId = key.substring(separator + 1);
  return ref
      .watch(publicDataServiceProvider)
      .watchTicketsForArea(field: field, areaId: areaId);
});

/// The full anonymised ticket queue behind the government dashboard's
/// Reports tab. Capped at 300 — a triage queue nobody scrolls past is not
/// worth the reads, and the search box narrows it anyway.
final publicAllTicketsProvider =
    StreamProvider.family<List<PublicTicketModel>, String>(
  (ref, constituencyId) => ref
      .watch(publicDataServiceProvider)
      .watchRecentTickets(constituencyId, limit: 300),
);

final publicClustersForBoothProvider =
    StreamProvider.family<List<PublicClusterModel>, String>(
  (ref, boothId) =>
      ref.watch(publicDataServiceProvider).watchClustersForBooth(boothId),
);

final publicSolutionCardsProvider =
    StreamProvider.family<List<SolutionCardModel>, String>(
  (ref, constituencyId) =>
      ref.watch(publicDataServiceProvider).watchSolutionCards(constituencyId),
);

final solutionCardProvider =
    StreamProvider.family<SolutionCardModel?, String>(
  (ref, clusterId) =>
      ref.watch(publicDataServiceProvider).watchSolutionCard(clusterId),
);

final allConstituenciesProvider =
    StreamProvider<List<ConstituencyModel>>(
  (ref) => ref.watch(publicDataServiceProvider).watchConstituencies(),
);

/// The finer-grained area a visitor drilled into from the District → Taluk
/// picker, if any.
///
/// The map and dashboards stay scoped by `constituencyId` — that is the unit
/// every ticket, cluster and official account is keyed on. This is purely a
/// *view* refinement layered on top: which sub-unit polygon to highlight and
/// frame the camera on. Null means "show the whole constituency", which is
/// what every entry point other than the area picker produces.
enum AreaKind { district, taluk, ward }

class SelectedArea {
  const SelectedArea({
    required this.kind,
    required this.id,
    required this.name,
    this.districtName,
    this.constituencyId,
  });

  final AreaKind kind;
  final String id;
  final String name;
  final String? districtName;
  final String? constituencyId;

  String get label =>
      districtName == null || districtName!.isEmpty ? name : '$name, $districtName';
}

final selectedAreaProvider = StateProvider<SelectedArea?>((ref) => null);

final allDistrictsProvider = StreamProvider<List<DistrictModel>>(
  (ref) => ref.watch(firestoreServiceProvider).watchDistricts(),
);

final taluksForDistrictProvider =
    StreamProvider.family<List<TalukModel>, String>(
  (ref, districtId) =>
      ref.watch(firestoreServiceProvider).watchTaluksForDistrict(districtId),
);

/// The wards of one GBA corporation — `Central`, `East`, `North`, `South` or
/// `West` (the `corporation` column in `gba_wards.json`, NOT the literal
/// string "GBA"). Bengaluru Urban's 369 wards are the picker's finest level
/// inside the city, where a taluk covers far too much ground to be a useful
/// area choice, and they are fetched a corporation at a time because each
/// ward document carries its whole boundary polygon.
final wardsForCorporationProvider =
    StreamProvider.family<List<WardModel>, String>(
  (ref, corporation) =>
      ref.watch(firestoreServiceProvider).watchWardsForCorporation(corporation),
);

/// Reports filed in the last seven days — the "N reports near you this
/// week" banner.
final reportsThisWeekProvider =
    FutureProvider.family<int, String>((ref, constituencyId) {
  final since = DateTime.now().subtract(const Duration(days: 7));
  return ref
      .watch(publicDataServiceProvider)
      .countTicketsSince(constituencyId, since);
});
