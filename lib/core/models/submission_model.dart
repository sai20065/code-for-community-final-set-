import 'package:cloud_firestore/cloud_firestore.dart';

enum SubmissionType { voice, text, photo, video }

enum SubmissionStatus { newSubmission, reviewed, inProgress, resolved }

/// Whether a ticket reports a problem (pothole, outage, etc.) or is
/// feedback on an existing/planned development project — the citizen picks
/// this in the compose flow before describing it.
enum SubmissionCategory { problem, feedback }

class SubmissionLocation {
  final double? lat;
  final double? lng;
  final String pincode;
  final String? boothId;
  final String? constituencyId;

  const SubmissionLocation({
    required this.pincode,
    this.lat,
    this.lng,
    this.boothId,
    this.constituencyId,
  });

  factory SubmissionLocation.fromMap(Map<String, dynamic> map) {
    return SubmissionLocation(
      pincode: map['pincode'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      boothId: map['boothId'] as String?,
      constituencyId: map['constituencyId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
      'boothId': boothId,
      'constituencyId': constituencyId,
    };
  }
}

/// A citizen's suggestion ticket. `tokenId` is generated client-side at
/// creation time (see `FirestoreService.generateTokenId`) so the citizen
/// always has a receipt, even if the downstream AI pipeline fails.
class SubmissionModel {
  final String id;
  final String userId;
  final SubmissionType type;
  final SubmissionCategory category;
  final String inputMode;
  final String? rawText;
  final String? mediaUrl;
  final String? transcript;
  final String? translatedText;
  final String language;
  final String? theme;
  final String? clusterId;
  final double? priorityScore;
  final SubmissionLocation location;
  final SubmissionStatus status;
  final String tokenId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final int supporterCount;
  final List<String> supporterIds;

  const SubmissionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.inputMode,
    required this.language,
    required this.location,
    required this.status,
    required this.tokenId,
    required this.createdAt,
    this.category = SubmissionCategory.problem,
    this.rawText,
    this.mediaUrl,
    this.transcript,
    this.translatedText,
    this.theme,
    this.clusterId,
    this.priorityScore,
    this.updatedAt,
    this.resolvedAt,
    this.supporterCount = 0,
    this.supporterIds = const [],
  });

  static SubmissionStatus statusFromString(String value) {
    switch (value) {
      case 'reviewed':
        return SubmissionStatus.reviewed;
      case 'inProgress':
        return SubmissionStatus.inProgress;
      case 'resolved':
        return SubmissionStatus.resolved;
      case 'new':
      default:
        return SubmissionStatus.newSubmission;
    }
  }

  static String statusToString(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.newSubmission:
        return 'new';
      case SubmissionStatus.reviewed:
        return 'reviewed';
      case SubmissionStatus.inProgress:
        return 'inProgress';
      case SubmissionStatus.resolved:
        return 'resolved';
    }
  }

  static SubmissionCategory categoryFromString(String? value) {
    return value == 'feedback'
        ? SubmissionCategory.feedback
        : SubmissionCategory.problem;
  }

  factory SubmissionModel.fromMap(String id, Map<String, dynamic> map) {
    return SubmissionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: SubmissionType.values.firstWhere(
        (t) => t.name == (map['type'] as String? ?? 'text'),
        orElse: () => SubmissionType.text,
      ),
      category: categoryFromString(map['submissionCategory'] as String?),
      inputMode: map['inputMode'] as String? ?? 'text',
      rawText: map['rawText'] as String?,
      mediaUrl: map['mediaUrl'] as String?,
      transcript: map['transcript'] as String?,
      translatedText: map['translatedText'] as String?,
      language: map['language'] as String? ?? 'en',
      theme: map['theme'] as String?,
      clusterId: map['clusterId'] as String?,
      priorityScore: (map['priorityScore'] as num?)?.toDouble(),
      location: SubmissionLocation.fromMap(
        (map['location'] as Map<String, dynamic>?) ?? const {},
      ),
      status: statusFromString(map['status'] as String? ?? 'new'),
      tokenId: map['tokenId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      supporterCount: map['supporterCount'] as int? ?? 0,
      supporterIds: (map['supporterIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'submissionCategory': category == SubmissionCategory.feedback
          ? 'feedback'
          : 'problem',
      'inputMode': inputMode,
      'rawText': rawText,
      'mediaUrl': mediaUrl,
      'transcript': transcript,
      'translatedText': translatedText,
      'language': language,
      'theme': theme,
      'clusterId': clusterId,
      'priorityScore': priorityScore,
      'location': location.toMap(),
      'status': statusToString(status),
      'tokenId': tokenId,
      'createdAt': Timestamp.fromDate(createdAt),
      'supporterCount': supporterCount,
      'supporterIds': supporterIds,
    };
  }
}
