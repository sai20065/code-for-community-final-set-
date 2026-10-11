import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/official_service.dart';
import '../../shared/widgets/primary_button.dart';
import 'auth/auth_common.dart';

/// Where a just-signed-in government / admin account should land:
/// admin console, the scoped dashboard, or (for a self-registered official
/// not yet approved) the application status screen. Accounts with none of
/// these are signed back out — a citizen password must not open the
/// government side. Returns an error message, or null after navigating.
Future<String?> routeGovAccount(BuildContext context, String uid) async {
  final db = FirebaseFirestore.instance;
  final user = (await db.collection('users').doc(uid).get()).data();
  if (!context.mounted) return null;
  switch (user?['role']) {
    case 'admin':
      context.go('/admin');
      return null;
    case 'official':
      context.go('/gov/dashboard');
      return null;
  }
  final app = await db.collection('officialApplications').doc(uid).get();
  if (!context.mounted) return null;
  if (app.exists) {
    context.go('/gov/pending');
    return null;
  }
  await AuthService().signOut();
  return 'This is not a government account. Citizens sign in from the '
      'Citizen section; new officials can register below.';
}

enum _Mode { mp, official }

/// Government sign-in, same look as the citizen screens. Two kinds of
/// account:
///  - **MP office**: admin-provisioned; constituency ID + password, with the
///    existing setup-code + email recovery (`mpFirstTimeSetup` /
///    `mpForgotCredentials`).
///  - **MLA / Officer** (BBMP ward officer, Tahsildar, District officer):
///    self-registered with an official email; Firebase's reset email for
///    "Forgot password". Access starts only after admin approval.
class GovLoginScreen extends ConsumerStatefulWidget {
  const GovLoginScreen({super.key});

  @override
  ConsumerState<GovLoginScreen> createState() => _GovLoginScreenState();
}

class _GovLoginScreenState extends ConsumerState<GovLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  _Mode _mode = _Mode.mp;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = _mode == _Mode.mp
          ? (await AuthService().signInOfficial(
              constituencyId: _idController.text.trim().toLowerCase(),
              password: _passwordController.text,
            ))
              .uid
          : (await OfficialService().signInWithEmail(
              _idController.text, _passwordController.text))
              .uid;
      if (!mounted) return;
      final error = await routeGovAccount(context, uid);
      if (error != null && mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _mode == _Mode.mp
            ? 'Could not sign in. Check your constituency ID and password.'
            : 'Could not sign in. Check your official email and password.';
      });
    }
  }

  Future<void> _forgot() async {
    if (_mode == _Mode.mp) {
      context.go('/mp/forgot-credentials');
      return;
    }
    final email = _idController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your official email above first.');
      return;
    }
    try {
      await OfficialService().sendPasswordReset(email);
      setState(() {
        _error = null;
        _info = 'If $email has an account, a reset link is on its way.';
      });
    } catch (_) {
      setState(() => _error = 'Could not send the reset email. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMp = _mode == _Mode.mp;
    return AuthScaffold(
      title: 'Government sign-in',
      subtitle: 'For MPs, MLAs, BBMP ward officers, Tahsildars and '
          'District officers.',
      footer: Column(
        children: [
          TextButton.icon(
            onPressed: () => context.go('/gov/register'),
            icon: const Icon(Icons.how_to_reg_rounded),
            label: const Text('New MLA or officer? Register for access'),
          ),
          if (isMp)
            TextButton(
              onPressed: () => context.go('/mp/first-time-setup'),
              child: const Text('MP first-time setup'),
            ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                  value: _Mode.mp,
                  label: Text('MP office'),
                  icon: Icon(Icons.account_balance_rounded),
                ),
                ButtonSegment(
                  value: _Mode.official,
                  label: Text('MLA / Officer'),
                  icon: Icon(Icons.badge_rounded),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
                _info = null;
                _idController.clear();
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey(_mode),
              controller: _idController,
              autocorrect: false,
              keyboardType:
                  isMp ? TextInputType.text : TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: isMp ? 'Constituency ID' : 'Official email',
                hintText: isMp ? 'e.g. 2927' : 'name@karnataka.gov.in',
                prefixIcon: Icon(isMp
                    ? Icons.confirmation_number_outlined
                    : Icons.alternate_email_rounded),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Required';
                if (!isMp && !t.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgot,
                child: Text(isMp ? 'Forgot credentials?' : 'Forgot password?'),
              ),
            ),
            if (_info != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tealMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_info!,
                    style: const TextStyle(color: AppColors.tealDeep)),
              ),
            if (_error != null) AuthErrorBanner(_error!),
            PrimaryButton(
              label: 'Sign in',
              icon: Icons.login_rounded,
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
