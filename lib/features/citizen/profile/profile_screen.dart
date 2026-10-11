import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/submission_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/citizen_stats.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/citizen_activity_widgets.dart';
import '../../../shared/widgets/consistency_map.dart';
import '../../../shared/widgets/mp_constituency_card.dart';
import '../../onboarding/auth/auth_common.dart';
import '../../onboarding/language_select_screen.dart';

final _profileSubmissionsProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchUserSubmissions(uid);
});

/// Profile: username and account security (change password, change
/// security question), home constituency/booth/pincode/language at a
/// glance, a privacy reminder (what's stored and why), and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authService = AuthService();
    final profileAsync = ref.watch(currentUserProfileProvider);
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.profileTitle),
      ),
      body: profileAsync.when(
        data: (profile) {
          final languageEntry = kSupportedLanguages.firstWhere(
            (l) => l.$1 == (profile?.preferredLanguage ?? 'en'),
            orElse: () => ('en', 'English', 'English'),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                    Text(profile?.name ?? l10n.citizenDefault,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if ((profile?.username ?? '').isNotEmpty)
                      Text('@${profile!.username}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.inkSoft)),
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.flag_rounded,
                      label: l10n.homeConstituency,
                      value: profile?.constituencyId ?? l10n.notYetMatched,
                    ),
                    const Divider(height: 22),
                    _InfoRow(
                      icon: Icons.place_rounded,
                      label: l10n.homeBooth,
                      value: profile?.homeBoothName ?? l10n.notYetMatched,
                    ),
                    const Divider(height: 22),
                    _InfoRow(
                      icon: Icons.pin_drop_rounded,
                      label: l10n.pincode,
                      value: profile?.pincodeHome ?? '—',
                    ),
                    const Divider(height: 22),
                    InkWell(
                      onTap: () => context.go('/language', extra: true),
                      borderRadius: BorderRadius.circular(10),
                      child: _InfoRow(
                        icon: Icons.language_rounded,
                        label: l10n.preferredLanguage,
                        value: '${languageEntry.$3} (${languageEntry.$2})',
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _AccountSecurityCard(),
              if (uid != null) ...[
                const SizedBox(height: 16),
                _CivicActivityCard(uid: uid),
              ],
              const SizedBox(height: 16),
              MpConstituencyCard(constituencyId: profile?.constituencyId),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/public/dashboard'),
                icon: const Icon(Icons.travel_explore_rounded),
                label: Text(l10n.seePublicDashboard),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.indigoMist,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_rounded, size: 18, color: AppColors.indigoDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.privacyStoreAddress,
                        style: const TextStyle(fontSize: 12, color: AppColors.indigoDeep, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await authService.signOut();
                  await ref.read(onboardingProgressProvider.notifier).reset();
                  if (context.mounted) context.go('/welcome');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.vermilion,
                  side: const BorderSide(color: AppColors.vermilion),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.signOutClears),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
      ),
    );
  }
}

/// The full 26-week activity picture: contribution grid, streaks, level
/// progress, badges, and a way out to the public dashboard.
///
/// Shares `_profileSubmissionsProvider` with nothing else on this screen —
/// riverpod caches it per-uid, so if the citizen came from Home (which
/// already watches the same underlying query) this costs nothing extra.
class _CivicActivityCard extends ConsumerWidget {
  const _CivicActivityCard({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final submissionsAsync = ref.watch(_profileSubmissionsProvider(uid));

    return submissionsAsync.when(
      data: (submissions) {
        final grid = buildContributionGrid(submissions);
        final streaks = computeStreaks(submissions);
        final level = computeLevel(submissions.length);
        final badges = computeBadges(submissions);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: appCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.yourCivicActivity,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 14),
              if (submissions.isEmpty)
                Text(l10n.consistencyEmptyNudge,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.inkFaint, height: 1.4))
              else ...[
                StreakBadgeRow(stats: streaks),
                const SizedBox(height: 16),
                Text(l10n.contributionsInLast26Weeks,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.inkFaint)),
                const SizedBox(height: 8),
                ConsistencyMap(grid: grid),
                const SizedBox(height: 18),
                LevelProgressBar(level: level),
                const SizedBox(height: 18),
                BadgeGrid(badges: badges),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Change password / change security question, from inside a signed-in
/// session. Changing the password re-checks the current one first — see
/// `AuthService.changePassword`.
class _AccountSecurityCard extends StatelessWidget {
  const _AccountSecurityCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: appCardShadow,
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded, color: AppColors.indigo),
            title: Text(l10n.changePasswordTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showSheet(context, const _ChangePasswordForm()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: AppColors.indigo),
            title: Text(l10n.changeSecurityQuestionTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showSheet(context, const _ChangeSecurityQuestionForm()),
          ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService().changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
    } on CitizenAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = citizenAuthErrorText(e.failure, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.changePasswordTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          PasswordField(
            controller: _current,
            label: l10n.currentPasswordLabel,
            validator: (v) => (v ?? '').isEmpty ? l10n.passwordTooShort : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _next,
            label: l10n.newPasswordLabel,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => validateNewPasswordField(v, l10n),
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirm,
            label: l10n.confirmPasswordLabel,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => v != _next.text ? l10n.passwordsDontMatch : null,
          ),
          const SizedBox(height: 16),
          if (_error != null) AuthErrorBanner(_error!),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(l10n.saveLabel),
          ),
        ],
      ),
    );
  }
}

class _ChangeSecurityQuestionForm extends StatefulWidget {
  const _ChangeSecurityQuestionForm();

  @override
  State<_ChangeSecurityQuestionForm> createState() =>
      _ChangeSecurityQuestionFormState();
}

class _ChangeSecurityQuestionFormState
    extends State<_ChangeSecurityQuestionForm> {
  final _formKey = GlobalKey<FormState>();
  final _answer = TextEditingController();
  String _questionId = kSecurityQuestionIds.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AccountRecoveryService().setSecurityQuestion(
        questionId: _questionId,
        answer: _answer.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.securityQuestionSaved)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.couldNotContinue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.changeSecurityQuestionTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SecurityQuestionFields(
            questionId: _questionId,
            onQuestionChanged: (id) => setState(() => _questionId = id),
            answerController: _answer,
          ),
          const SizedBox(height: 16),
          if (_error != null) AuthErrorBanner(_error!),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(l10n.saveLabel),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkFaint),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
