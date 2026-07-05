import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booth_model.dart';
import '../models/cluster_model.dart';
import '../models/submission_model.dart';
import '../models/user_model.dart';

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

  /// Generates the citizen-facing ticket id, e.g. `PD-2026-004821`.
  /// Must be produced and persisted at document-creation time — before any
  /// AI/Cloud Function processing runs — so a citizen never loses their
  /// receipt even if the downstream pipeline fails (see Section 6).
  String generateTokenId() {
    final year = DateTime.now().year;
    final random = Random();
    final suffix = random.nextInt(999999).toString().padLeft(6, '0');
    return 'PD-$year-$suffix';
  }

  Future<SubmissionModel> createSubmission(SubmissionModel draft) async {
    final tokenId = draft.tokenId.isNotEmpty ? draft.tokenId : generateTokenId();
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

  Stream<List<BoothModel>> watchBoothsForConstituency(String constituencyId) {
    return _booths
        .where('constituencyId', isEqualTo: constituencyId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BoothModel.fromMap(d.id, d.data())).toList());
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
}
