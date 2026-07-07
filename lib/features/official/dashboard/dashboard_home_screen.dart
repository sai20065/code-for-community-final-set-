import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/constituency_report_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';

/// Section 3.8 / 5.2: lead with a single glanceable number per stat before
/// any chart — "can a busy person understand value in 5 minutes" test.
/// Every stat is scoped to the signed-in official's OWN constituency.
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.constituencyDashboard),
        bottom: const TricolorTrustStrip(),
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            final constituencyId = profile?.constituencyId;
            if (constituencyId == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.notLinkedConstituency,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _DashboardBody(constituencyId: constituencyId);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  int? _newThisWeek;
  int? _resolvedCount;
  int? _totalCount;
  Duration? _avgResponseTime;
  bool _loading = true;
  bool _generatingReport = false;
  String? _reportError;
  final _reportService = ConstituencyReportService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(firestoreServiceProvider);
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final results = await Future.wait([
      service.countSubmissionsSince(widget.constituencyId, weekAgo),
      service.countResolvedSubmissions(widget.constituencyId),
      service.countAllSubmissions(widget.constituencyId),
      service.averageResolutionTime(widget.constituencyId),
    ]);
    if (!mounted) return;
    setState(() {
      _newThisWeek = results[0] as int;
      _resolvedCount = results[1] as int;
      _totalCount = results[2] as int;
      _avgResponseTime = results[3] as Duration?;
      _loading = false;
    });
  }

  /// Generates the AI constituency report (see `generateConstituencyReport`
  /// Cloud Function), downloads the resulting PDF, and hands it to the OS
  /// print/save dialog via `Printing.layoutPdf` — "so he can directly print
  /// the report" rather than just getting a link.
  Future<void> _generateReport() async {
    setState(() {
      _generatingReport = true;
      _reportError = null;
    });
    try {
      final result = await _reportService.generateReport();
      final response = await http.get(Uri.parse(result.downloadUrl));
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => response.bodyBytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _reportError = AppLocalizations.of(context).couldNotGenerateReport);
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final resolvedRate = (_totalCount ?? 0) == 0
        ? '—'
        : '${(((_resolvedCount ?? 0) / _totalCount!) * 100).round()}%';
    final avgResponse = _avgResponseTime == null
        ? '—'
        : l10n.daysValue(
            '${_avgResponseTime!.inHours ~/ 24}.${(_avgResponseTime!.inHours % 24 * 10 ~/ 24)}');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.newThisWeek,
                value: '${_newThisWeek ?? 0}',
                color: AppColors.coralRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: l10n.resolvedRate,
                value: resolvedRate,
                color: AppColors.leafGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatCard(
          label: l10n.avgResponseTime,
          value: avgResponse,
          color: AppColors.trustBlue,
          fullWidth: true,
        ),
        const SizedBox(height: 20),
        Text(l10n.constituencyMap, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: Material(
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/official/map'),
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_rounded, size: 48, color: AppColors.trustBlue),
                    const SizedBox(height: 8),
                    Text(l10n.openConstituencyMap),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/official/works'),
              icon: const Icon(Icons.leaderboard_rounded),
              label: Text(l10n.rankedWorks),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/official/themes'),
              icon: const Icon(Icons.bar_chart_rounded),
              label: Text(l10n.themesOverview),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/official/tickets'),
              icon: const Icon(Icons.list_alt_rounded),
              label: Text(l10n.problemReports),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: l10n.generateReport,
          icon: Icons.picture_as_pdf_rounded,
          loading: _generatingReport,
          onPressed: _generatingReport ? null : _generateReport,
        ),
        if (_reportError != null) ...[
          const SizedBox(height: 8),
          Text(_reportError!,
              style: const TextStyle(color: AppColors.coralRed, fontSize: 12.5)),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
