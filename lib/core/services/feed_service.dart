import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/feed_comment_model.dart';
import '../models/public_models.dart';

/// One page of the citizen feed, plus the cursor for the next.
class FeedPage {
  const FeedPage(this.posts, this.cursor, {required this.hasMore});

  final List<PublicTicketModel> posts;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

/// The citizen feed: real public reports (never seeded trial data — only
/// real tickets carry `feedEligible`), their comments, and "Me too".
///
/// Everything read here is public projection data; "Me too" and comment
/// reports go through Cloud Functions so supporter and reporter uids are
/// never readable by other citizens.
class FeedService {
  FeedService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static const pageSize = 15;

  Future<FeedPage> page({
    String? districtId,
    bool withPhotos = false,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> q =
        _db.collection('publicTickets').where('feedEligible', isEqualTo: true);
    if (districtId != null) q = q.where('districtId', isEqualTo: districtId);
    if (withPhotos) q = q.where('hasPhoto', isEqualTo: true);
    q = q.orderBy('createdDate', descending: true).limit(limit);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.get();
    return FeedPage(
      snap.docs.map((d) => PublicTicketModel.fromMap(d.id, d.data())).toList(),
      snap.docs.isEmpty ? after : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  Stream<List<FeedComment>> watchComments(String ticketId, {int limit = 50}) {
    return _db
        .collection('feedComments')
        .where('ticketId', isEqualTo: ticketId)
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => FeedComment.fromMap(d.id, d.data())).toList());
  }

  Future<void> addComment({
    required String ticketId,
    required String uid,
    required String username,
    required String text,
  }) {
    return _db.collection('feedComments').add({
      'ticketId': ticketId,
      'uid': uid,
      'username': username,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'hidden': false,
      'reportCount': 0,
    });
  }

  Future<void> deleteComment(String commentId) =>
      _db.collection('feedComments').doc(commentId).delete();

  Future<void> reportComment(String commentId) =>
      _functions.httpsCallable('reportFeedComment').call<void>({'commentId': commentId});

  /// Returns whether the citizen now supports the report.
  Future<bool> toggleSupport(String ticketId) async {
    final res = await _functions
        .httpsCallable('toggleReportSupport')
        .call<Map<String, dynamic>>({'ticketId': ticketId});
    return res.data['supported'] == true;
  }

  /// The reports this citizen said "Me too" to — their own data only.
  Stream<Set<String>> watchMySupports(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('supports')
        .limit(1000)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  /// The reporter's consent switch for showing a blurred copy of their photo
  /// in the feed; the server publishes or withdraws it.
  Future<void> setPhotoPublic(String submissionId, bool value) =>
      _db.collection('submissions').doc(submissionId).update({'photoPublic': value});
}
