import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/status_stepper.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import '../../../app/theme.dart';

/// Section 4, screen 9: card per submission with theme icon/color, snippet,
/// and status stepper.
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<List<SubmissionModel>>(
              stream: firestoreService.watchUserSubmissions(uid),
              builder: (context, snapshot) {
                final submissions = snapshot.data ?? const [];
                if (submissions.isEmpty) {
                  return const Center(child: Text('No tickets yet'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: submissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = submissions[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () =>
                            context.go('/reports/${s.id}', extra: s),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        categoryColor(s.theme ?? 'more'),
                                    child: Icon(
                                      kThemeIcons[s.theme] ??
                                          Icons.help_outline_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      s.tokenId,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                s.rawText ?? s.transcript ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              StatusStepper(status: s.status),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
