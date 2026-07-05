import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/submission_model.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/ticket_receipt_card.dart';

/// Section 4, screen 8: receipt-card UI with checkmark + ticket ID.
/// Never let a user submit into a void (Section 3.4).
class SubmissionConfirmationScreen extends StatelessWidget {
  const SubmissionConfirmationScreen({super.key, required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TicketReceiptCard(
                tokenId: submission.tokenId,
                createdAt: submission.createdAt,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Track this report',
                icon: Icons.timeline_rounded,
                onPressed: () =>
                    context.go('/reports/${submission.id}', extra: submission),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
