import 'package:cloud_functions/cloud_functions.dart';

/// How long a citizen has to answer "was it fixed?" before the ticket may be
/// closed by hand. Mirrors CLOSE_WINDOW_MS in functions/src/work/workflowMath.ts.
const kCloseWindow = Duration(hours: 48);

/// Time left in the citizen's window; [Duration.zero] once it is over.
Duration answerWindowLeft(DateTime fixedAt, [DateTime? now]) {
  final left = kCloseWindow - (now ?? DateTime.now()).difference(fixedAt);
  return left.isNegative ? Duration.zero : left;
}

class WorkerInfo {
  const WorkerInfo({
    required this.uid,
    required this.name,
    required this.email,
    required this.areaName,
    required this.parentName,
    required this.disabled,
    required this.openTickets,
  });

  final String uid;
  final String name;
  final String email;
  final String areaName;
  final String parentName;
  final bool disabled;
  final int openTickets;

  factory WorkerInfo.fromMap(Map m) => WorkerInfo(
        uid: m['uid'] as String? ?? '',
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        areaName: m['areaName'] as String? ?? '',
        parentName: m['parentName'] as String? ?? '',
        disabled: m['disabled'] == true,
        openTickets: (m['openTickets'] as num?)?.toInt() ?? 0,
      );
}

class WorkerTask {
  const WorkerTask({
    required this.id,
    required this.tokenId,
    required this.summary,
    required this.theme,
    required this.status,
    required this.area,
    required this.lat,
    required this.lng,
    required this.note,
    required this.assignedBy,
    required this.closeState,
    required this.reopened,
    this.fixedAt,
    this.hasPhoto = false,
  });

  final String id;
  final String tokenId;
  final String summary;
  final String? theme;
  final String status;
  final String area;

  /// The report has a photo; the worker opens the original with `ticketPhoto`.
  final bool hasPhoto;
  final double? lat;
  final double? lng;
  final String? note;
  final String assignedBy;
  final DateTime? fixedAt;

  /// `none`, `awaiting_citizen` or `closeable`.
  final String closeState;
  final bool reopened;

  bool get isClosed => status == 'closed';
  bool get isFixed => status == 'resolved' || status == 'closed';

  factory WorkerTask.fromMap(Map m) => WorkerTask(
        id: m['id'] as String? ?? '',
        tokenId: m['tokenId'] as String? ?? '',
        summary: m['summary'] as String? ?? '',
        theme: m['theme'] as String?,
        status: m['status'] as String? ?? 'new',
        area: m['area'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        note: m['note'] as String?,
        assignedBy: m['assignedBy'] as String? ?? '',
        fixedAt: m['fixedAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch((m['fixedAt'] as num).toInt())
            : null,
        closeState: m['closeState'] as String? ?? 'none',
        reopened: m['reopened'] == true,
        hasPhoto: m['hasPhoto'] == true,
      );
}

class IssueGroup {
  const IssueGroup({
    required this.key,
    required this.parts,
    required this.count,
    required this.open,
    required this.fixed,
    required this.unassigned,
    required this.closeable,
    required this.reopened,
    required this.avgAgeDays,
    required this.maxPriority,
  });

  final String key;
  final Map<String, String> parts;
  final int count, open, fixed, unassigned, closeable, reopened, maxPriority;
  final double avgAgeDays;

  String get title => parts.values.join(' · ');

  factory IssueGroup.fromMap(Map m) => IssueGroup(
        key: m['key'] as String? ?? '',
        parts: ((m['parts'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', '$v')),
        count: (m['count'] as num?)?.toInt() ?? 0,
        open: (m['open'] as num?)?.toInt() ?? 0,
        fixed: (m['fixed'] as num?)?.toInt() ?? 0,
        unassigned: (m['unassigned'] as num?)?.toInt() ?? 0,
        closeable: (m['closeable'] as num?)?.toInt() ?? 0,
        reopened: (m['reopened'] as num?)?.toInt() ?? 0,
        avgAgeDays: (m['avgAgeDays'] as num?)?.toDouble() ?? 0,
        maxPriority: (m['maxPriority'] as num?)?.toInt() ?? 0,
      );
}

class IssueTicket {
  const IssueTicket({
    required this.id,
    required this.tokenId,
    required this.theme,
    required this.status,
    required this.summary,
    required this.district,
    required this.taluk,
    required this.ageDays,
    required this.assignedTo,
    required this.closeState,
    required this.reopened,
  });

  final String id, tokenId, theme, status, summary, district, taluk;
  final int ageDays;
  final String? assignedTo;
  final String closeState;
  final bool reopened;

  factory IssueTicket.fromMap(Map m) => IssueTicket(
        id: m['id'] as String? ?? '',
        tokenId: m['tokenId'] as String? ?? '',
        theme: m['theme'] as String? ?? '',
        status: m['status'] as String? ?? 'new',
        summary: m['summary'] as String? ?? '',
        district: m['district'] as String? ?? '',
        taluk: m['taluk'] as String? ?? '',
        ageDays: (m['ageDays'] as num?)?.toInt() ?? 0,
        assignedTo: m['assignedTo'] as String?,
        closeState: m['closeState'] as String? ?? 'none',
        reopened: m['reopened'] == true,
      );
}

class IssueOverview {
  const IssueOverview({required this.totals, required this.groups, required this.tickets, required this.capped});
  final Map<String, int> totals;
  final List<IssueGroup> groups;
  final List<IssueTicket> tickets;
  final bool capped;
}

/// Everything about handing work out and closing it. All writes go through
/// Cloud Functions, which check the caller's area, keep a history, and
/// enforce the 48-hour rule.
class WorkService {
  WorkService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  // Resolved on first use so the service can be built before Firebase starts
  // (and subclassed in tests).
  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    final r = await _functions.httpsCallable(name).call<Map<Object?, Object?>>(data);
    return Map<String, dynamic>.from(r.data);
  }

  /// Returns a one-time temporary password for the new worker.
  Future<String> createWorker({
    required String name,
    required String email,
    Map<String, String>? jurisdiction,
  }) async {
    final r = await _call('createWorker', {
      'name': name,
      'email': email,
      if (jurisdiction != null) 'jurisdiction': jurisdiction,
    });
    return r['tempPassword'] as String;
  }

  Future<List<WorkerInfo>> myWorkers() async {
    final r = await _call('listMyWorkers');
    return [for (final w in (r['workers'] as List? ?? const [])) WorkerInfo.fromMap(w as Map)];
  }

  Future<void> setWorkerActive(String workerUid, bool active) =>
      _call('setWorkerActive', {'workerUid': workerUid, 'active': active});

  /// Returns how many of [ticketIds] were assigned.
  Future<int> assign(List<String> ticketIds, String workerUid, {String? note}) async {
    final r = await _call('assignTicket', {
      'ticketIds': ticketIds,
      'workerUid': workerUid,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return (r['assigned'] as num?)?.toInt() ?? 0;
  }

  /// [status] is a wire name: `new`, `reviewed`, `inProgress` or `resolved`.
  Future<int> updateStatus(List<String> ticketIds, String status, {String? note}) async {
    final r = await _call('updateTicketStatus', {
      'ticketIds': ticketIds,
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return (r['changed'] as num?)?.toInt() ?? 0;
  }

  Future<void> citizenRespond(String ticketId, {required bool fixed, String? note}) =>
      _call('citizenRespondFix', {
        'ticketId': ticketId,
        'kind': fixed ? 'confirmed' : 'not_fixed',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  /// Returns how many tickets were closed. Tickets still inside the 48-hour
  /// window, or already answered, are skipped by the server.
  Future<int> close(List<String> ticketIds, {String? reason}) async {
    final r = await _call('closeTicket', {
      'ticketIds': ticketIds,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return (r['closed'] as num?)?.toInt() ?? 0;
  }

  /// The original report photo URL, for the people who handle the report
  /// (admin, the area's officials, the assigned worker). Null when there is none.
  Future<String?> ticketPhoto(String ticketId) async {
    final r = await _call('getTicketPhoto', {'ticketId': ticketId});
    return r['url'] as String?;
  }

  Future<List<WorkerTask>> myTasks() async {
    final r = await _call('getWorkerTasks');
    return [for (final t in (r['tasks'] as List? ?? const [])) WorkerTask.fromMap(t as Map)];
  }

  Future<IssueOverview> adminIssues({
    required List<String> groupBy,
    Map<String, dynamic> filters = const {},
    String? openGroup,
  }) async {
    final r = await _functions
        .httpsCallable('getAdminIssueGroups',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 90)))
        .call<Map<Object?, Object?>>({
      'groupBy': groupBy,
      'filters': filters,
      if (openGroup != null) 'openGroup': openGroup,
    });
    final m = Map<String, dynamic>.from(r.data);
    return IssueOverview(
      totals: ((m['totals'] as Map?) ?? const {})
          .map((k, v) => MapEntry('$k', (v as num).toInt())),
      groups: [for (final g in (m['groups'] as List? ?? const [])) IssueGroup.fromMap(g as Map)],
      tickets: [for (final t in (m['tickets'] as List? ?? const [])) IssueTicket.fromMap(t as Map)],
      capped: m['capped'] == true,
    );
  }
}
