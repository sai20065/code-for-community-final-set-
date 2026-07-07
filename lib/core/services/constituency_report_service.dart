import 'package:cloud_functions/cloud_functions.dart';

class ConstituencyReportResult {
  final String downloadUrl;
  final DateTime generatedAt;

  const ConstituencyReportResult({
    required this.downloadUrl,
    required this.generatedAt,
  });
}

/// Calls the `generateConstituencyReport` Cloud Function (see
/// `functions/src/reports/generateConstituencyReport.ts`) — an AI-authored
/// PDF briefing (executive summary, recommended actions, top issues by
/// priority) for the signed-in official's own constituency, scoped
/// server-side to their own `users/{uid}.constituencyId` (never a
/// caller-supplied parameter).
class ConstituencyReportService {
  ConstituencyReportService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<ConstituencyReportResult> generateReport() async {
    final callable = _functions.httpsCallable(
      'generateConstituencyReport',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final response = await callable.call<Map<String, dynamic>>();
    final data = response.data;
    return ConstituencyReportResult(
      downloadUrl: data['downloadUrl'] as String,
      generatedAt: DateTime.parse(data['generatedAt'] as String),
    );
  }
}
