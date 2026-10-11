import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/official_scope.dart';

/// A self-registered MLA / officer waiting for (or past) admin review —
/// `officialApplications/{uid}`.
class OfficialApplication {
  const OfficialApplication({
    required this.uid,
    required this.name,
    required this.officialType,
    required this.jurisdictionType,
    required this.jurisdictionId,
    required this.jurisdictionName,
    required this.officialEmail,
    required this.status,
    this.designation,
    this.proofPath,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.constituencyId,
  });

  final String uid;
  final String name;
  final OfficialType officialType;
  final String jurisdictionType;
  final String jurisdictionId;
  final String jurisdictionName;
  final String officialEmail;

  /// `pending` | `approved` | `rejected`.
  final String status;
  final String? designation;
  final String? proofPath;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? constituencyId;

  factory OfficialApplication.fromMap(String uid, Map<String, dynamic> m) {
    final j = (m['jurisdiction'] as Map?) ?? const {};
    return OfficialApplication(
      uid: uid,
      name: m['name'] as String? ?? '',
      officialType: officialTypeFrom(m['officialType'] as String?),
      jurisdictionType: j['type'] as String? ?? '',
      jurisdictionId: j['id'] as String? ?? '',
      jurisdictionName: j['name'] as String? ?? '',
      constituencyId: j['constituencyId'] as String?,
      officialEmail: m['officialEmail'] as String? ?? '',
      status: m['status'] as String? ?? 'pending',
      designation: m['designation'] as String?,
      proofPath: m['proofPath'] as String?,
      rejectionReason: m['rejectionReason'] as String?,
      submittedAt: (m['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (m['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The area an applicant picked, with its parent Lok Sabha seat if known.
class PickedArea {
  const PickedArea({
    required this.type,
    required this.id,
    required this.name,
    this.constituencyId,
  });

  final String type; // assembly | bbmpWard | taluk | district
  final String id;
  final String name;
  final String? constituencyId;
}

/// AI briefing for an official's area — `getAreaBriefing`.
class AreaBriefing {
  const AreaBriefing({
    required this.headline,
    required this.situation,
    required this.topProblems,
    required this.trends,
    required this.urgent,
    required this.actions,
    required this.generatedAt,
    required this.totalReports,
    required this.areaName,
    this.cached = false,
  });

  final String headline;
  final String situation;
  final List<({String title, String theme, String why})> topProblems;
  final List<String> trends;
  final List<String> urgent;
  final List<({String action, String owner, String timeframe})> actions;
  final DateTime generatedAt;
  final int totalReports;
  final String areaName;
  final bool cached;

  factory AreaBriefing.fromMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> maps(Object? v) => (v as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    List<String> strings(Object? v) =>
        (v as List? ?? const []).whereType<String>().toList();
    return AreaBriefing(
      headline: m['headline'] as String? ?? '',
      situation: m['situation'] as String? ?? '',
      topProblems: [
        for (final p in maps(m['topProblems']))
          (
            title: p['title'] as String? ?? '',
            theme: p['theme'] as String? ?? 'more',
            why: p['whyItMatters'] as String? ?? '',
          ),
      ],
      trends: strings(m['trends']),
      urgent: strings(m['urgent']),
      actions: [
        for (final a in maps(m['recommendedActions']))
          (
            action: a['action'] as String? ?? '',
            owner: a['owner'] as String? ?? '',
            timeframe: a['timeframe'] as String? ?? '',
          ),
      ],
      generatedAt:
          DateTime.tryParse(m['generatedAt'] as String? ?? '') ?? DateTime.now(),
      totalReports: ((m['stats'] as Map?)?['total'] as num?)?.toInt() ?? 0,
      areaName: m['areaName'] as String? ?? '',
      cached: m['cached'] == true,
    );
  }
}

class AdminOverview {
  const AdminOverview(this.raw);
  final Map<String, dynamic> raw;
  int _n(String k) => (raw[k] as num?)?.toInt() ?? 0;
  int get citizens => _n('citizens');
  int get officials => _n('officials');
  int get pending => _n('pendingApplications');
  int get reports => _n('reports');
  int get reportsThisWeek => _n('reportsThisWeek');
  int get resolved => _n('resolved');
  Map<String, int> get byType => {
        for (final e in ((raw['officialsByType'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      };
}

/// Officials and admins: email sign-in, self-registration, applications,
/// approvals, the AI briefing and the downloadable report.
class OfficialService {
  OfficialService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _apps =>
      _db.collection('officialApplications');

  static const maxProofBytes = 5 * 1024 * 1024;

  Future<User> signInWithEmail(String email, String password) async {
    final r = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(), password: password);
    return r.user!;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());

  /// Creates the account, uploads the proof, files a pending application
  /// and sends a verification email. The account has NO dashboard access
  /// until an admin approves it — firestore.rules never let a client set
  /// `role: 'official'`.
  Future<void> register({
    required String name,
    required String designation,
    required OfficialType type,
    required PickedArea area,
    required String email,
    required String password,
    required Uint8List proofBytes,
    required String proofContentType,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(), password: password);
    final uid = cred.user!.uid;
    try {
      await cred.user!.sendEmailVerification();
    } catch (_) {
      // Non-fatal: the admin still reviews the proof.
    }
    final proofPath = await uploadProof(uid, proofBytes, proofContentType);
    await _apps.doc(uid).set(_applicationMap(
      name: name,
      designation: designation,
      type: type,
      area: area,
      email: email,
      proofPath: proofPath,
    ));
  }

  /// Re-submit after a rejection (edits allowed).
  Future<void> resubmit({
    required String name,
    required String designation,
    required OfficialType type,
    required PickedArea area,
    Uint8List? proofBytes,
    String proofContentType = 'image/jpeg',
    String? existingProofPath,
  }) async {
    final user = _auth.currentUser!;
    final proofPath = proofBytes != null
        ? await uploadProof(user.uid, proofBytes, proofContentType)
        : existingProofPath;
    await _apps.doc(user.uid).set(_applicationMap(
      name: name,
      designation: designation,
      type: type,
      area: area,
      email: user.email ?? '',
      proofPath: proofPath,
    ));
  }

  Map<String, dynamic> _applicationMap({
    required String name,
    required String designation,
    required OfficialType type,
    required PickedArea area,
    required String email,
    required String? proofPath,
  }) =>
      {
        'name': name.trim(),
        'designation': designation.trim(),
        'officialType': type.name,
        'jurisdiction': {
          'type': area.type,
          'id': area.id,
          'name': area.name,
          if (area.constituencyId != null) 'constituencyId': area.constituencyId,
        },
        'officialEmail': email.trim().toLowerCase(),
        'proofPath': proofPath,
        'status': 'pending',
        'rejectionReason': null,
        'submittedAt': FieldValue.serverTimestamp(),
      };

  Future<String> uploadProof(String uid, Uint8List bytes, String contentType) async {
    final ext = contentType == 'application/pdf' ? 'pdf' : 'jpg';
    final path = 'officialProofs/$uid/proof_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _storage.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  Future<Uint8List?> loadProof(String path) =>
      _storage.ref(path).getData(maxProofBytes);

  Stream<OfficialApplication?> watchApplication(String uid) => _apps
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? OfficialApplication.fromMap(d.id, d.data()!) : null);

  /// Admin only (rules).
  Stream<List<OfficialApplication>> watchApplications(String status) => _apps
          .where('status', isEqualTo: status)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => OfficialApplication.fromMap(d.id, d.data()))
            .toList();
        list.sort((a, b) => (b.submittedAt ?? DateTime(0))
            .compareTo(a.submittedAt ?? DateTime(0)));
        return list;
      });

  Future<void> review(String applicantUid, {required bool approve, String? reason}) async {
    await _functions.httpsCallable('reviewOfficialApplication').call({
      'applicantUid': applicantUid,
      'decision': approve ? 'approve' : 'reject',
      if (reason != null) 'reason': reason,
    });
  }

  Future<AreaBriefing> briefing({bool refresh = false}) async {
    final r = await _functions
        .httpsCallable('getAreaBriefing',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 120)))
        .call<Map<String, dynamic>>({'refresh': refresh});
    return AreaBriefing.fromMap(Map<String, dynamic>.from(r.data));
  }

  Future<AdminOverview> adminOverview() async {
    final r = await _functions
        .httpsCallable('getAdminOverview')
        .call<Map<String, dynamic>>();
    return AdminOverview(Map<String, dynamic>.from(r.data));
  }
}
