import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Wraps `FirebaseAuth.instance.authStateChanges()` (Phase 2, Section 8) so
/// the splash screen can decide Home vs. onboarding without touching
/// `FirebaseAuth` directly.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});
