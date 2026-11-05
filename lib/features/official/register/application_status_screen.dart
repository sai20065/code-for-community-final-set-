import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/models/official_scope.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/official_service.dart';

/// Where a self-registered official waits: Submitted → Under review →
/// Approved, the role and area they applied for, and — if rejected — the
/// admin's reason with a "Re-apply" button. Updates live, so an approval
/// shows up without signing out.
class ApplicationStatusScreen extends StatelessWidget {
  const ApplicationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Your application'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/welcome');
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            label: const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please sign in again.'))
          : StreamBuilder<OfficialApplication?>(
              stream: OfficialService().watchApplication(user.uid),
              builder: (context, snap) {
                final app = snap.data;
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (app == null) {
                  return Center(
                    child: FilledButton(
                      onPressed: () => context.go('/gov/register'),
                      child: const Text('Start an application'),
                    ),
                  );
                }
                return _Body(app: app, emailVerified: user.emailVerified);
              },
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.app, required this.emailVerified});

  final OfficialApplication app;
  final bool emailVerified;

  @override
  Widget build(BuildContext context) {
    final approved = app.status == 'approved';
    final rejected = app.status == 'rejected';
    final stage = approved ? 2 : 1;
    final date = app.submittedAt == null
        ? ''
        : DateFormat.yMMMd().format(app.submittedAt!);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: rejected
                  ? [AppColors.vermilionDeep, AppColors.vermilion]
                  : approved
                      ? [AppColors.tealDeep, AppColors.teal]
                      : [AppColors.indigoDeep, AppColors.indigo],
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            children: [
              Icon(
                rejected
                    ? Icons.cancel_rounded
                    : approved
                        ? Icons.verified_rounded
                        : Icons.hourglass_top_rounded,
                color: Colors.white,
                size: 52,
              ),
              const SizedBox(height: 10),
              Text(
                rejected
                    ? 'Application not approved'
                    : approved
                        ? 'You’re approved!'
                        : 'Application under review',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                rejected
                    ? 'See the reason below. You can update and re-submit.'
                    : approved
                        ? 'Your dashboard is ready.'
                        : 'A Prajadhwani admin is checking your proof of '
                            'appointment. This page updates on its own.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!rejected)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: appCardShadow,
            ),
            child: Row(
              children: [
                for (final (i, label) in ['Submitted', 'Under review', 'Approved'].indexed) ...[
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              i <= stage ? AppColors.teal : AppColors.indigoMist,
                          child: Icon(
                            i < stage || approved ? Icons.check_rounded : Icons.more_horiz,
                            size: 16,
                            color: i <= stage ? Colors.white : AppColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (rejected)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.vermilionMist,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text('Reason: ${app.rejectionReason ?? '—'}',
                style: const TextStyle(color: AppColors.vermilionDeep)),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: appCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row(Icons.badge_rounded, 'Role', app.officialType.label),
              _Row(app.officialType.icon, app.officialType.areaNoun,
                  app.jurisdictionName),
              _Row(Icons.person_rounded, 'Name', app.name),
              if ((app.designation ?? '').isNotEmpty)
                _Row(Icons.work_outline_rounded, 'Designation', app.designation!),
              _Row(Icons.alternate_email_rounded, 'Email',
                  '${app.officialEmail}${emailVerified ? '  ✓ verified' : ''}'),
              if (date.isNotEmpty)
                _Row(Icons.event_rounded, 'Submitted', date),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (approved)
          FilledButton.icon(
            onPressed: () => context.go('/gov/dashboard'),
            icon: const Icon(Icons.space_dashboard_rounded),
            label: const Text('Open my dashboard'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        if (rejected)
          FilledButton.icon(
            onPressed: () => context.go('/gov/register', extra: true),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Update & re-apply'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        if (!emailVerified && !approved) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.currentUser?.sendEmailVerification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Verification email sent.')));
              }
            },
            child: const Text('Resend email verification link'),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.inkFaint),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.inkFaint)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
