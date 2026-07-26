import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/agent_transcript_model.dart';
import '../models/constituency_model.dart';
import '../models/public_models.dart';
import '../models/solution_card_model.dart';

/// Dashboard-header stats, derived from `publicClusters` only.
class PublicConstituencyStats {
  final int trackedIssues;
  final int totalReports;
  final int resolvedReports;
  final int solutionCardsPublished;

  const PublicConstituencyStats({
    this.trackedIssues = 0,
    this.totalReports = 0,
    this.resolvedReports = 0,
    this.solutionCardsPublished = 0,
  });

  String get resolvedRateLabel =>
      totalReports == 0 ? '—' : '${((resolvedReports / totalReports) * 100).round()}%';
}

/// Reads the anonymised public projections behind the public dashboard.
///
/// **This class has no dependency on `AuthService` and never reads
/// `submissions` or `users`.** That is the point, not an accident: the
/// dashboard has to work for a visitor with no account at all, and the way
/// to guarantee it never exposes a citizen's identity is for the code path
/// that serves it to have no access to identity in the first place.
///
/// See `functions/src/public/projection.ts` for the field allowlist that
/// defines what these collections may contain.
class PublicDataService {
  PublicDataService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _tickets =>
      _db.collection('publicTickets');
  CollectionReference<Map<String, dynamic>> get _clusters =>
      _db.collection('publicClusters');
  CollectionReference<Map<String, dynamic>> get _cards =>
      _db.collection('solutionCards');
  CollectionReference<Map<String, dynamic>> get _constituencies =>
      _db.collection('constituencies');

  /// All tracked issue groups in a constituency, worst first.
  ///
  /// Sorted client-side rather than with `orderBy`, for the same reason as
  /// `FirestoreService.watchClustersForConstituency`: Firestore's `orderBy`
  /// silently excludes documents missing the ordered field, and a hotspot
  /// vanishing from the public map with no error is exactly the failure
  /// this codebase already had once.
  Stream<List<PublicClusterModel>> watchClusters(String constituencyId) {
    return _clusters
        .where('constituencyId', isEqualTo: constituencyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => PublicClusterModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
      return list;
    });
  }

  /// Every issue group tracked at one booth, worst first.
  Stream<List<PublicClusterModel>> watchClustersForBooth(String boothId) {
    return _clusters.where('boothId', isEqualTo: boothId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PublicClusterModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
      return list;
    });
  }

  /// The worst [limit] issues — the hotspot leaderboard.
  Stream<List<PublicClusterModel>> watchTopHotspots(
    String constituencyId, {
    int limit = 5,
  }) {
    return watchClusters(constituencyId)
        .map((all) => all.take(limit).toList());
  }

  /// Recent public tickets, newest first.
  Stream<List<PublicTicketModel>> watchRecentTickets(
    String constituencyId, {
    int limit = 30,
    String? theme,
  }) {
    Query<Map<String, dynamic>> query =
        _tickets.where('constituencyId', isEqualTo: constituencyId);
    if (theme != null) query = query.where('theme', isEqualTo: theme);
    return query
        .orderBy('createdDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PublicTicketModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Tickets belonging to one issue group.
  Stream<List<PublicTicketModel>> watchTicketsForCluster(String clusterId) {
    return _tickets
        .where('clusterId', isEqualTo: clusterId)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PublicTicketModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<SolutionCardModel?> watchSolutionCard(String clusterId) {
    return _cards.doc(clusterId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return SolutionCardModel.fromMap(doc.id, data);
    });
  }

  /// The most recently analysed issues that have a Solution Card.
  Stream<List<SolutionCardModel>> watchSolutionCards(
    String constituencyId, {
    int limit = 10,
  }) {
    return _cards
        .where('constituencyId', isEqualTo: constituencyId)
        .orderBy('priorityScore', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SolutionCardModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Reports filed since [since], for the "N reports near you this week"
  /// banner. Uses a count aggregation so a busy constituency doesn't ship
  /// every document to the device just to display one number.
  Future<int> countTicketsSince(String constituencyId, DateTime since) async {
    final dateKey = since.toIso8601String().substring(0, 10);
    final snapshot = await _tickets
        .where('constituencyId', isEqualTo: constituencyId)
        .where('createdDate', isGreaterThanOrEqualTo: dateKey)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Aggregate stat tiles for the dashboard header, derived entirely from
  /// `publicClusters` (never from `submissions`, which the public dashboard
  /// cannot read). `total`/`resolved` are sums across clusters — an
  /// approximation for the small number of tickets that never joined a
  /// cluster (unscoped or in-flight), but auth-free and cheap, which is the
  /// whole point of this collection.
  Stream<PublicConstituencyStats> watchStats(String constituencyId) {
    return watchClusters(constituencyId).map((clusters) {
      var total = 0;
      var resolved = 0;
      for (final c in clusters) {
        total += c.submissionCount;
        resolved += c.resolvedCount;
      }
      return PublicConstituencyStats(
        trackedIssues: clusters.length,
        totalReports: total,
        resolvedReports: resolved,
        solutionCardsPublished: clusters.where((c) => c.hasSolutionCard).length,
      );
    });
  }

  /// The most recent agent-chain transcript for a cluster.
  ///
  /// Officials only — the rules on this subcollection deny everyone else,
  /// because transcripts carry each agent's raw prompt and unfiltered reply,
  /// which quote ticket text the public card deliberately doesn't show.
  Future<AgentRunTranscript?> latestTranscript(String clusterId) async {
    final snap = await _cards
        .doc(clusterId)
        .collection('agentTranscripts')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AgentRunTranscript.fromMap(snap.docs.first.data());
  }

  /// Every constituency, for the signed-out chooser.
  Stream<List<ConstituencyModel>> watchConstituencies() {
    return _constituencies.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => ConstituencyModel.fromMap(d.id, d.data()))
        .toList());
  }

  Future<ConstituencyModel?> getConstituency(String constituencyId) async {
    final doc = await _constituencies.doc(constituencyId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return ConstituencyModel.fromMap(doc.id, data);
  }
}
