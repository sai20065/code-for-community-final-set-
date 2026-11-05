import 'package:cloud_firestore/cloud_firestore.dart';

/// A visible comment under a feed post (`feedComments/{id}`). Hidden
/// comments are never readable, so the app never sees them.
class FeedComment {
  final String id;
  final String ticketId;
  final String uid;
  final String username;
  final String text;
  final DateTime? createdAt;

  const FeedComment({
    required this.id,
    required this.ticketId,
    required this.uid,
    required this.username,
    required this.text,
    this.createdAt,
  });

  factory FeedComment.fromMap(String id, Map<String, dynamic> map) => FeedComment(
        id: id,
        ticketId: map['ticketId'] as String? ?? '',
        uid: map['uid'] as String? ?? '',
        username: map['username'] as String? ?? '',
        text: map['text'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      );
}
