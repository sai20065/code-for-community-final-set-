import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/submission_model.dart';
import '../../../core/services/feed_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/google_maps_directions_button.dart';
import '../../../shared/widgets/status_stepper.dart';
import '../../../shared/widgets/suggested_office_card.dart';

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
      // Opened straight from the confirmation screen, the passed copy can
      // predate the backend's suggested office — refresh it quietly.
      if (widget.submission!.suggestedOffice == null) _load();
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final result = await _firestoreService.getSubmission(widget.submissionId);
    if (mounted) {
      setState(() {
        _submission = result ?? _submission;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/reports'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final s = _submission;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/reports'),
          ),
        ),
        body: Center(child: Text(l10n.ticketNotFound)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/reports'),
        ),
        title: Text(s.tokenId),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            StatusStepper(status: s.status),
            if (s.category == SubmissionCategory.problem && s.mediaUrl != null) ...[
              const SizedBox(height: 12),
              _PhotoConsent(submissionId: s.id, initial: s),
            ],
            if (s.category == SubmissionCategory.problem) ...[
              const SizedBox(height: 16),
              SuggestedOfficeCard(
                office: s.suggestedOffice,
                tokenId: s.tokenId,
                reportText: s.rawText ?? s.transcript,
                lat: s.location.lat,
                lng: s.location.lng,
              ),
            ],
            const SizedBox(height: 24),
            Text(l10n.ticketLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(s.rawText ?? s.transcript ?? l10n.noDescription),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/public/report/${s.id}'),
              icon: const Icon(Icons.badge_rounded, size: 18),
              label: Text(l10n.seePublicCard),
            ),
            const SizedBox(height: 24),
            GoogleMapsDirectionsButton(
              lat: s.location.lat,
              lng: s.location.lng,
            ),
          ],
        ),
      ),
    );
  }
}

/// The reporter's switch for showing a blurred copy of their photo in the
/// public feed, with what the server did about it. Follows the ticket doc,
/// because publishing takes a few seconds.
class _PhotoConsent extends StatelessWidget {
  const _PhotoConsent({required this.submissionId, required this.initial});

  final String submissionId;
  final SubmissionModel initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<SubmissionModel?>(
      stream: FirestoreService().watchSubmission(submissionId),
      initialData: initial,
      builder: (context, snap) {
        final s = snap.data ?? initial;
        final status = switch (s.photoPublic ? s.publicPhotoStatus : null) {
          'processing' => l10n.photoStatusProcessing,
          'published' => l10n.photoStatusPublished,
          'rejected' => l10n.photoStatusRejected,
          'error' => l10n.photoStatusError,
          _ => l10n.showPhotoInFeedNote,
        };
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: s.photoPublic,
          onChanged: (v) => FeedService().setPhotoPublic(submissionId, v),
          title: Text(l10n.showPhotoInFeed, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(status),
        );
      },
    );
  }
}
