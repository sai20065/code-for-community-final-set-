import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/constituency_model.dart';
import '../../core/models/public_models.dart';
import '../../core/models/solution_card_model.dart';
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

/// Reports filed in the last seven days — the "N reports near you this
/// week" banner.
final reportsThisWeekProvider =
    FutureProvider.family<int, String>((ref, constituencyId) {
  final since = DateTime.now().subtract(const Duration(days: 7));
  return ref
      .watch(publicDataServiceProvider)
      .countTicketsSince(constituencyId, since);
});
