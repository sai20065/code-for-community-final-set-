import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/status_stepper.dart';
import '../../../shared/widgets/theme_icon_chip.dart';

/// Home (Citizen), Section 4 screen 6: exactly one dominant action — a
/// large central mic FAB, thumb-reachable, everything else secondary.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        title: const Text('Praja Dhvani'),
        bottom: const TricolorTrustStrip(),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SecondaryAction(
                  icon: Icons.camera_alt_rounded,
                  label: 'Photo',
                  onTap: () => context.go('/compose/photo'),
                ),
                const SizedBox(width: 32),
                _SecondaryAction(
                  icon: Icons.edit_rounded,
                  label: 'Text',
                  onTap: () => context.go('/compose/text'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Please sign in'))
                  : StreamBuilder<List<SubmissionModel>>(
                      stream: firestoreService.watchUserSubmissions(uid),
                      builder: (context, snapshot) {
                        final submissions = snapshot.data ?? const [];
                        if (submissions.isEmpty) {
                          return const Center(
                            child: Text('No tickets yet — tap the mic below'),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: submissions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final s = submissions[index];
                            return _ReportCard(
                              submission: s,
                              onTap: () =>
                                  context.go('/reports/${s.id}'),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => context.go('/compose/voice'),
        child: const Icon(Icons.mic_rounded, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.trustBlue,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.submission, required this.onTap});

  final SubmissionModel submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: categoryColor(submission.theme ?? 'more'),
                child: Icon(
                  kThemeIcons[submission.theme] ?? Icons.help_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.tokenId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      submission.rawText ?? submission.transcript ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusStepper(status: submission.status, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
