import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Receipt-style confirmation shown right after submission (Section 3.4) —
/// mirrors the trust citizens already place in RTI/courier tracking numbers.
/// Never let a submission complete without this.
class TicketReceiptCard extends StatelessWidget {
  const TicketReceiptCard({
    super.key,
    required this.tokenId,
    required this.createdAt,
  });

  final String tokenId;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.leafGreen,
            child: Icon(Icons.check, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).receiptWeGotThis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            tokenId,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${createdAt.day}/${createdAt.month}/${createdAt.year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
