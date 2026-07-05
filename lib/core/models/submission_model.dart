import 'package:cloud_firestore/cloud_firestore.dart';

enum SubmissionType { voice, text, photo, video }

enum SubmissionStatus { newSubmission, reviewed, inProgress, resolved }

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

/// A citizen's civic complaint. `tokenId` is generated client-side at
/// creation time (see [pincode_lookup]-adjacent ticket generator) so the
/// citizen always has a receipt, even if the downstream AI pipeline fails.
class SubmissionModel {
  final String id;
  final String userId;
  final SubmissionType type;
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
    this.rawText,
    this.mediaUrl,
    this.transcript,
    this.translatedText,
    this.theme,
    this.clusterId,
    this.priorityScore,
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

  factory SubmissionModel.fromMap(String id, Map<String, dynamic> map) {
    return SubmissionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: SubmissionType.values.firstWhere(
        (t) => t.name == (map['type'] as String? ?? 'text'),
        orElse: () => SubmissionType.text,
      ),
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
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
    };
  }
}
