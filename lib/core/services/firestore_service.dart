import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> upsertUser(UserModel user) {
    return _users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  /// Creates `users/{uid}` the moment a phone number is verified (Phase 2,
  /// Section 5) if it doesn't already exist, so the document is never
  /// missing even if the user quits before finishing Basic Info/Location.
  Future<UserModel> getOrCreateUser({
    required String uid,
    required String phone,
    required String preferredLanguage,
  }) async {
    final existing = await getUser(uid);
    if (existing != null) return existing;
    final user = UserModel(
      uid: uid,
      phone: phone,
      role: UserRole.citizen,
      preferredLanguage: preferredLanguage,
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
    return _submissions
        .doc(id)
        .update({'status': SubmissionModel.statusToString(status)});
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
}
