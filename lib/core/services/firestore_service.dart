import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booth_model.dart';
import '../models/cluster_model.dart';
import '../models/constituency_model.dart';
import '../models/submission_model.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _submissions =>
      _db.collection('submissions');
  CollectionReference<Map<String, dynamic>> get _booths =>
      _db.collection('booths');
  CollectionReference<Map<String, dynamic>> get _clusters =>
      _db.collection('clusters');
  CollectionReference<Map<String, dynamic>> get _counters =>
      _db.collection('counters');
  CollectionReference<Map<String, dynamic>> get _constituencies =>
      _db.collection('constituencies');
  CollectionReference<Map<String, dynamic>> get _wards =>
      _db.collection('wards');

  Future<void> upsertUser(UserModel user) {
    return _users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(
        (doc) => doc.exists ? UserModel.fromMap(doc.id, doc.data()!) : null);
  }

  /// Creates `users/{uid}` the moment anonymous sign-in succeeds, if it
  /// doesn't already exist, so the document is never missing even if the
  /// citizen quits before finishing the rest of onboarding. Any fields
  /// already extracted from Aadhaar OCR (name/pincode/address) land in this
  /// very first write.
  Future<UserModel> getOrCreateUser({
    required String uid,
    required String preferredLanguage,
    String? name,
    String? pincodeHome,
    String? addressHome,
  }) async {
    final existing = await getUser(uid);
    if (existing != null) return existing;
    final user = UserModel(
      uid: uid,
      role: UserRole.citizen,
      preferredLanguage: preferredLanguage,
      name: name,
      pincodeHome: pincodeHome,
      addressHome: addressHome,
      createdAt: DateTime.now(),
    );
    await upsertUser(user);
    return user;
  }

  /// Derives the token's constituency code from a `constituencyId` like
  /// `blr-north` → `BLRN`: strip separators, uppercase, take the first 4
  /// letters (padded if shorter). Falls back to `GENL` when a submission
  /// hasn't been resolved to a constituency yet.
  String _constituencyCode(String? constituencyId) {
    if (constituencyId == null || constituencyId.isEmpty) return 'GENL';
    final letters = constituencyId.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.isEmpty) return 'GENL';
    return letters.length >= 4 ? letters.substring(0, 4) : letters.padRight(4, 'X');
  }

  /// Generates the citizen-facing ticket id as a structured, decodable
  /// pattern: `PD-<CONSTITUENCY_CODE>-<CATEGORY_CODE>-<YYMMDD>-<SEQ4>`, e.g.
  /// `PD-BLRN-PRB-260706-0007` — constituency, problem-or-suggestion, day,
  /// and a same-day sequence number, all readable at a glance without a
  /// database lookup. The `SEQ4` is an atomic per-constituency-per-day
  /// counter (`counters/{constituencyId}_{yyMMdd}`, via
  /// `FieldValue.increment` in a transaction), replacing the old random
  /// 6-digit suffix so tokens are unique and sortable instead of merely
  /// collision-unlikely. Must be produced and persisted at document-creation
  /// time — before any AI/Cloud Function processing runs — so a citizen
  /// never loses their receipt even if the downstream pipeline fails.
  Future<String> generateTokenId({
    required String? constituencyId,
    required SubmissionCategory category,
  }) async {
    final now = DateTime.now();
    final yyMMdd =
        '${(now.year % 100).toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final counterId = '${constituencyId ?? 'unresolved'}_$yyMMdd';
    final counterRef = _counters.doc(counterId);
    final seq = await _db.runTransaction<int>((tx) async {
      final snapshot = await tx.get(counterRef);
      final next = ((snapshot.data()?['count'] as int?) ?? 0) + 1;
      tx.set(counterRef, {'count': next}, SetOptions(merge: true));
      return next;
    });
    final categoryCode =
        category == SubmissionCategory.feedback ? 'SUG' : 'PRB';
    final seq4 = seq.toString().padLeft(4, '0');
    return 'PD-${_constituencyCode(constituencyId)}-$categoryCode-$yyMMdd-$seq4';
  }

  Future<SubmissionModel> createSubmission(SubmissionModel draft) async {
    final tokenId = draft.tokenId.isNotEmpty
        ? draft.tokenId
        : await generateTokenId(
            constituencyId: draft.location.constituencyId,
            category: draft.category,
          );
    final data = draft.toMap()..['tokenId'] = tokenId;
    final docRef = await _submissions.add(data);
    return SubmissionModel.fromMap(docRef.id, data);
  }

  Stream<List<SubmissionModel>> watchUserSubmissions(String userId) {
    return _submissions
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SubmissionModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<SubmissionModel?> getSubmission(String id) async {
    final doc = await _submissions.doc(id).get();
    if (!doc.exists) return null;
    return SubmissionModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateSubmissionStatus(String id, SubmissionStatus status) {
    final data = <String, dynamic>{
      'status': SubmissionModel.statusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == SubmissionStatus.resolved) {
      data['resolvedAt'] = FieldValue.serverTimestamp();
    }
    return _submissions.doc(id).update(data);
  }

  Stream<List<SubmissionModel>> watchConstituencySubmissions(
      String constituencyId) {
    return _submissions
        .where('location.constituencyId', isEqualTo: constituencyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SubmissionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Average resolution time (createdAt → resolvedAt) over the most
  /// recently resolved tickets. Firestore aggregation queries can only
  /// count/sum/average a single field, not diff two timestamps, so this
  /// fetches a small recent sample and computes the average client-side.
  Future<Duration?> averageResolutionTime(String constituencyId, {int sampleSize = 30}) async {
    final snapshot = await _submissions
        .where('location.constituencyId', isEqualTo: constituencyId)
        .where('status', isEqualTo: SubmissionModel.statusToString(SubmissionStatus.resolved))
        .orderBy('resolvedAt', descending: true)
        .limit(sampleSize)
        .get();
    final durations = snapshot.docs
        .map((d) => SubmissionModel.fromMap(d.id, d.data()))
        .where((s) => s.resolvedAt != null)
        .map((s) => s.resolvedAt!.difference(s.createdAt))
        .toList();
    if (durations.isEmpty) return null;
    final totalMicroseconds =
        durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ durations.length);
  }

  /// New-tickets count for a constituency since [since] — powers the
  /// official dashboard's "New this week" stat card via a native Firestore
  /// aggregation query (no Cloud Function needed).
  Future<int> countSubmissionsSince(String constituencyId, DateTime since) async {
    final query = _submissions
        .where('location.constituencyId', isEqualTo: constituencyId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  Future<int> countResolvedSubmissions(String constituencyId) async {
    final query = _submissions
        .where('location.constituencyId', isEqualTo: constituencyId)
        .where('status', isEqualTo: SubmissionModel.statusToString(SubmissionStatus.resolved));
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  Future<int> countAllSubmissions(String constituencyId) async {
    final query =
        _submissions.where('location.constituencyId', isEqualTo: constituencyId);
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  Future<ConstituencyModel?> getConstituency(String constituencyId) async {
    final doc = await _constituencies.doc(constituencyId).get();
    if (!doc.exists) return null;
    return ConstituencyModel.fromMap(doc.id, doc.data()!);
  }

  Stream<ConstituencyModel?> watchConstituency(String constituencyId) {
    return _constituencies.doc(constituencyId).snapshots().map(
        (doc) => doc.exists ? ConstituencyModel.fromMap(doc.id, doc.data()!) : null);
  }

  Stream<List<BoothModel>> watchBoothsForConstituency(String constituencyId) {
    return _booths
        .where('constituencyId', isEqualTo: constituencyId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BoothModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<WardModel>> watchWardsForConstituency(String constituencyId) {
    return _wards
        .where('constituencyId', isEqualTo: constituencyId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => WardModel.fromMap(d.id, d.data())).toList());
  }

  Future<WardModel?> getWard(String wardId) async {
    final doc = await _wards.doc(wardId).get();
    if (!doc.exists) return null;
    return WardModel.fromMap(doc.id, doc.data()!);
  }

  Stream<List<ClusterModel>> watchClustersForConstituency(
      String constituencyId) {
    return _clusters
        .where('constituencyId', isEqualTo: constituencyId)
        .orderBy('priorityScore', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClusterModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<ClusterModel>> watchClustersForBooth(String boothId) {
    return _clusters
        .where('boothId', isEqualTo: boothId)
        .orderBy('priorityScore', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClusterModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// "Trending near you" feed: development-suggestion tickets in the
  /// citizen's own constituency, ranked by supporter count. Citizens only
  /// ever see their own area's suggestions (Section: own-area enforcement).
  Stream<List<SubmissionModel>> watchTrendingSuggestions(
    String constituencyId, {
    int limit = 20,
  }) {
    return _submissions
        .where('location.constituencyId', isEqualTo: constituencyId)
        .where('submissionCategory', isEqualTo: 'feedback')
        .orderBy('supporterCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SubmissionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Toggles whether [uid] supports [submissionId] ("I support this"),
  /// keeping `supporterCount` consistent with `supporterIds` via a
  /// transaction so a citizen can't inflate the count by tapping repeatedly.
  /// Returns true if the citizen now supports it, false if support was
  /// just withdrawn.
  Future<bool> toggleSupport(String submissionId, String uid) {
    final ref = _submissions.doc(submissionId);
    return _db.runTransaction<bool>((tx) async {
      final snapshot = await tx.get(ref);
      final ids =
          (snapshot.data()?['supporterIds'] as List?)?.cast<String>() ?? [];
      if (ids.contains(uid)) {
        tx.update(ref, {
          'supporterIds': FieldValue.arrayRemove([uid]),
          'supporterCount': FieldValue.increment(-1),
        });
        return false;
      }
      tx.update(ref, {
        'supporterIds': FieldValue.arrayUnion([uid]),
        'supporterCount': FieldValue.increment(1),
      });
      return true;
    });
  }
}
