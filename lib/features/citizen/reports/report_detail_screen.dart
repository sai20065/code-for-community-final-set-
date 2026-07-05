import 'package:flutter/material.dart';

import '../../../core/models/submission_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/status_stepper.dart';

/// Section 4, screen 10: status stepper large at top, original submission
/// content, transcript/translation collapsed under "See details".
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.submissionId,
    this.submission,
  });

  final String submissionId;
  final SubmissionModel? submission;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _firestoreService = FirestoreService();
  SubmissionModel? _submission;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.submission != null) {
      _submission = widget.submission;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final result = await _firestoreService.getSubmission(widget.submissionId);
    if (mounted) {
      setState(() {
        _submission = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = _submission;
    if (s == null) {
      return const Scaffold(body: Center(child: Text('Ticket not found')));
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.tokenId)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            StatusStepper(status: s.status),
            const SizedBox(height: 24),
            Text('Ticket', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(s.rawText ?? s.transcript ?? 'No description'),
            if (s.translatedText != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('See details (transcript/translation)'),
                children: [Text(s.translatedText!)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
