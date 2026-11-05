import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/work_service.dart';
import '../../../l10n/app_localizations.dart';

/// "Was this fixed?" — shown to the reporter once a worker marks their report
/// fixed. They have 48 hours to say yes (the report closes) or no (it goes
/// back to be fixed again). After that it waits for an admin or worker to
/// close it; nothing closes by itself.
class FixConfirmationCard extends StatefulWidget {
  const FixConfirmationCard({
    super.key,
    required this.submission,
    required this.onChanged,
    WorkService? service,
  }) : _service = service;

  final SubmissionModel submission;

  /// Called after an answer is saved so the screen can reload the report.
  final VoidCallback onChanged;
  final WorkService? _service;

  @override
  State<FixConfirmationCard> createState() => _FixConfirmationCardState();
}

class _FixConfirmationCardState extends State<FixConfirmationCard> {
  bool _busy = false;
  String? _message;

  Future<void> _answer(bool fixed) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await (widget._service ?? WorkService())
          .citizenRespond(widget.submission.id, fixed: fixed);
      if (!mounted) return;
      setState(() => _message = fixed ? l10n.fixThanks : l10n.fixReopened);
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.somethingWentWrong)));
      }
    }
  }

  String _left(Duration d) =>
      d.inHours >= 1 ? '${d.inHours} h' : '${d.inMinutes.clamp(1, 59)} min';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.submission;
    if (s.category != SubmissionCategory.problem) return const SizedBox.shrink();

    final lines = <Widget>[];
    if (s.assignedToName != null && s.status != SubmissionStatus.closed) {
      lines.add(_Row(Icons.engineering_rounded, l10n.fixAssignedTo(s.assignedToName!),
          AppColors.indigo));
    }

    if (_message != null) {
      lines.add(_Row(Icons.check_circle_rounded, _message!, AppColors.tealDeep));
    } else if (s.status == SubmissionStatus.closed) {
      final byCitizen = s.citizenResponseKind == 'confirmed';
      lines.add(_Row(Icons.lock_rounded,
          byCitizen ? l10n.fixThanks : l10n.fixClosedAuto, AppColors.tealDeep));
    } else if (s.status == SubmissionStatus.resolved && s.fixedAt != null) {
      final left = answerWindowLeft(s.fixedAt!);
      if (s.citizenResponseKind == null && left > Duration.zero) {
        lines.addAll([
          Text(l10n.fixQuestion,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(l10n.fixWindowLeft(_left(left)),
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _answer(true),
                icon: const Icon(Icons.thumb_up_alt_rounded, size: 18),
                label: Text(l10n.fixYes),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _answer(false),
                icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                label: Text(l10n.fixNo),
              ),
            ),
          ]),
        ]);
      } else {
        lines.add(_Row(Icons.hourglass_bottom_rounded, l10n.fixAwaiting,
            AppColors.saffronDeep));
      }
    } else if (s.citizenResponseKind == 'not_fixed') {
      lines.add(_Row(Icons.build_circle_outlined, l10n.fixReopened, AppColors.saffronDeep));
    }

    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.35))),
        ]),
      );
}
