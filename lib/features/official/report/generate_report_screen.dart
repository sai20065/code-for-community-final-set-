import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import '../../../app/theme.dart';
import '../../../core/services/constituency_report_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';

/// Officials-only. Split out of the (now public) dashboard so that
/// generating the AI constituency PDF briefing — which reads the full,
/// unredacted `submissions` collection server-side — stays behind the same
/// role gate as ticket status updates, rather than living on a screen
/// anyone can now reach.
class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({super.key});

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  final _reportService = ConstituencyReportService();
  bool _generating = false;
  String? _error;

  /// Downloads the AI-authored PDF (see `generateConstituencyReport`) and
  /// hands it straight to the OS print/save dialog via `Printing.layoutPdf`.
  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await _reportService.generateReport();
      final response = await http.get(Uri.parse(result.downloadUrl));
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => response.bodyBytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).couldNotGenerateReport);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/public/dashboard'),
        ),
        title: Text(l10n.generateReport),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.indigoMist,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                l10n.generateReportExplainer,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.generateReport,
              icon: Icons.picture_as_pdf_rounded,
              loading: _generating,
              onPressed: _generating ? null : _generate,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppColors.vermilion, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}
