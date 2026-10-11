import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../app/theme.dart';
import '../../../core/services/constituency_report_service.dart';
import '../../../core/services/official_service.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Downloads the AI-written PDF report for the signed-in official's area
/// (`generateAreaReport`) and opens the system print / save / share sheet.
Future<void> downloadAreaReport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(
    content: Text('Preparing your PDF report… this can take up to a minute.'),
    duration: Duration(seconds: 3),
  ));
  try {
    final result = await ConstituencyReportService().generateReport();
    final bytes = (await http.get(Uri.parse(result.downloadUrl))).bodyBytes;
    final name =
        'prajadhwani-report-${DateFormat('yyyy-MM-dd').format(result.generatedAt)}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  } catch (e) {
    debugPrint('Report download failed: $e');
    messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't generate the report. Please try again.")));
  }
}

/// "AI briefing" — what's going wrong in this official's area, what's
/// trending, what's urgent and what to do, written by Gemini from the
/// area's issue groups (never from any citizen's own words). Cached
/// server-side for 6 hours; Refresh regenerates at most hourly.
class AiBriefingCard extends StatefulWidget {
  const AiBriefingCard({super.key, this.compact = false});

  /// Profile / admin home show a shorter version.
  final bool compact;

  @override
  State<AiBriefingCard> createState() => _AiBriefingCardState();
}

class _AiBriefingCardState extends State<AiBriefingCard> {
  final _service = OfficialService();
  late Future<AreaBriefing> _future = _service.briefing();
  bool _downloading = false;

  void _refresh() => setState(() => _future = _service.briefing(refresh: true));

  Future<void> _download() async {
    setState(() => _downloading = true);
    await downloadAreaReport(context);
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: appCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B2AA8), AppColors.indigo],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.saffron),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('AI briefing',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _refresh,
                ),
              ],
            ),
          ),
          FutureBuilder<AreaBriefing>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Reading your area’s reports…',
                          style: TextStyle(color: AppColors.inkSoft)),
                    ],
                  ),
                );
              }
              if (snap.hasError || snap.data == null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                          'The AI briefing is unavailable right now.',
                          style: TextStyle(color: AppColors.inkSoft)),
                      TextButton(onPressed: _refresh, child: const Text('Try again')),
                    ],
                  ),
                );
              }
              return _BriefingBody(
                b: snap.data!,
                compact: widget.compact,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Download PDF report'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.vermilion,
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefingBody extends StatelessWidget {
  const _BriefingBody({required this.b, required this.compact});

  final AreaBriefing b;
  final bool compact;

  Widget _heading(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(text.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(b.generatedAt);
    final ageText = age.inMinutes < 2
        ? 'just now'
        : age.inHours < 1
            ? '${age.inMinutes} min ago'
            : '${age.inHours} h ago';
    final problems = compact ? b.topProblems.take(2) : b.topProblems;
    final actions = compact ? b.actions.take(2) : b.actions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(b.headline,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 6),
          Text(b.situation,
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.inkSoft, height: 1.45)),
          if (b.urgent.isNotEmpty) ...[
            _heading('Urgent', Icons.priority_high_rounded, AppColors.vermilion),
            for (final u in b.urgent)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.vermilionMist,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(u,
                    style: const TextStyle(
                        color: AppColors.vermilionDeep,
                        fontWeight: FontWeight.w600)),
              ),
          ],
          if (problems.isNotEmpty) ...[
            _heading('Top problems', Icons.report_problem_rounded,
                AppColors.saffronDeep),
            for (final p in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor:
                          categoryColor(p.theme).withValues(alpha: 0.14),
                      child: Icon(kThemeIcons[p.theme] ?? Icons.place,
                          size: 16, color: categoryColor(p.theme)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          if (p.why.isNotEmpty)
                            Text(p.why,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.inkSoft,
                                    height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (!compact && b.trends.isNotEmpty) ...[
            _heading('Trends', Icons.trending_up_rounded, AppColors.indigo),
            for (final t in b.trends)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('•  $t', style: const TextStyle(height: 1.35)),
              ),
          ],
          if (actions.isNotEmpty) ...[
            _heading('Recommended actions', Icons.checklist_rounded,
                AppColors.teal),
            for (final (i, a) in actions.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.teal,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.action,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            [a.owner, a.timeframe]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            'AI-written from ${b.totalReports} reports · updated $ageText',
            style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
