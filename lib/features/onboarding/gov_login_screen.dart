import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/primary_button.dart';

/// Government sign-in — its own screen rather than a tab on Welcome.
///
/// Officials are provisioned out-of-band (see
/// `functions/src/scripts/seedKarnatakaOfficials.ts`), so this is a two-field
/// form: the constituency ID printed on their onboarding letter, and a
/// password mailed to their official address. `AuthService.signInOfficial`
/// turns the ID into the synthetic `{id}@mp.prajadhwani.app` credential — an
/// official never sees or types an email address.
class GovLoginScreen extends StatefulWidget {
  const GovLoginScreen({super.key});

  @override
  State<GovLoginScreen> createState() => _GovLoginScreenState();
}

class _GovLoginScreenState extends State<GovLoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  bool get _canSubmit =>
      _idController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _login() async {
    if (!_canSubmit || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signInOfficial(
        constituencyId: _idController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/gov/dashboard');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not sign in. Check your ID and password, or use '
            '"First-time setup" below to get a fresh password by email.';
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.indigoDeep,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/welcome'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Government access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in with the constituency ID and password issued to '
                    'your office.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: appCardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _FieldLabel('Constituency ID'),
                        TextField(
                          controller: _idController,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'e.g. blr-north',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Password'),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            hintText: 'Password from your setup email',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.vermilion.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: AppColors.vermilion),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.vermilion,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: 'Sign in',
                          icon: Icons.login_rounded,
                          loading: _loading,
                          onPressed: _canSubmit ? _login : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => context.go('/mp/first-time-setup'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.saffron),
                        child: const Text('First-time setup',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/mp/forgot-credentials'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.saffron),
                        child: const Text('Forgot password',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.55)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Officials see anonymised tickets only — token '
                          'number, the reported problem, and its area. Never '
                          'a name, phone number or address.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.inkSoft,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
