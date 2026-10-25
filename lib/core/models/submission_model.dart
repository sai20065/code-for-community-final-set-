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
  final String? wardId;

  /// The ward-equivalent granular unit outside Bengaluru Urban, resolved
  /// server-side by `onSubmissionCreated`. Modelled here because a client
  /// read-modify-write used to silently drop it back to null on every
  /// `toMap()` — which quietly unscoped tickets outside Bengaluru.
  final String? talukId;

  const SubmissionLocation({
    required this.pincode,
    this.lat,
    this.lng,
    this.boothId,
    this.constituencyId,
    this.wardId,
    this.talukId,
  });

  factory SubmissionLocation.fromMap(Map<String, dynamic> map) {
    return SubmissionLocation(
      pincode: map['pincode'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      boothId: map['boothId'] as String?,
      constituencyId: map['constituencyId'] as String?,
      wardId: map['wardId'] as String?,
      talukId: map['talukId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
      'boothId': boothId,
      'constituencyId': constituencyId,
      'wardId': wardId,
      'talukId': talukId,
    };
  }
}

/// The office `onSubmissionCreated` suggests the citizen file with — the
/// "Suggested office to file the problem" line under the ticket id. Every
/// contact field is copied from the server's verified office directory,
/// never written by the model (see functions/src/assignment/).
class SuggestedOffice {
  final String departmentId;
  final String name;
  final String? shortName;
  final String? officerDesignation;
  final String? email;
  final String? websiteUrl;
  final String? phone;

  /// "exact", "state-fallback" or "national-fallback".
  final String matchQuality;

  /// "gemma" when the model chose among the shortlist, "rules" otherwise.
  final String source;

  const SuggestedOffice({
    required this.departmentId,
    required this.name,
    this.shortName,
    this.officerDesignation,
    this.email,
    this.websiteUrl,
    this.phone,
    this.matchQuality = 'state-fallback',
    this.source = 'rules',
  });

  static SuggestedOffice? fromMap(Map<String, dynamic>? map) {
    final id = map?['departmentId'] as String?;
    final name = map?['name'] as String?;
    if (map == null || id == null || name == null || name.isEmpty) return null;
    String? nonEmpty(String key) {
      final v = (map[key] as String?)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return SuggestedOffice(
      departmentId: id,
      name: name,
      shortName: nonEmpty('shortName'),
      officerDesignation: nonEmpty('officerDesignation'),
      email: nonEmpty('email'),
      websiteUrl: nonEmpty('websiteUrl'),
      phone: nonEmpty('phone'),
      matchQuality: map['matchQuality'] as String? ?? 'state-fallback',
      source: map['source'] as String? ?? 'rules',
    );
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
  /// Optional voice note recorded alongside a photo/text report. The
  /// transcript already lives in [rawText]; this is the original audio.
  final String? audioUrl;
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

  /// Written server-side a few seconds after submit; null until then.
  /// Read-only on the client, so deliberately absent from [toMap].
  final SuggestedOffice? suggestedOffice;

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
    this.audioUrl,
    this.transcript,
    this.translatedText,
    this.theme,
    this.clusterId,
    this.priorityScore,
    this.updatedAt,
    this.resolvedAt,
    this.supporterCount = 0,
    this.supporterIds = const [],
    this.suggestedOffice,
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
      audioUrl: map['audioUrl'] as String?,
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
      suggestedOffice: SuggestedOffice.fromMap(
        (map['suggestedOffice'] as Map?)?.cast<String, dynamic>(),
      ),
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
      if (audioUrl != null) 'audioUrl': audioUrl,
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
