import 'package:firebase_auth/firebase_auth.dart';

import 'app_exceptions.dart';

/// Citizen identity has two entry points, both landing on the same
/// `users/{uid}` document shape: **Phone** (real Firebase Phone Auth with
/// SMS OTP) and **Anonymous** (invisible, no credential — still available as
/// "skip" for anyone who doesn't want to attach a number). Citizen
/// email/password was removed: Firebase has no native email-OTP and
/// magic-links are unreliable on a sideloaded APK, so phone OTP is the one
/// "verify yourself" path. Whichever is chosen, the Aadhaar Upload step (see
/// `AadhaarOcrService`) remains a one-time onboarding convenience that
/// extracts name/address/pincode/wardNumber from self-uploaded front/back
/// images — it is NOT verified UIDAI eKYC and makes no claim the uploader is
/// who the document says they are.
///
/// Sign Up and Sign In are deliberately separate flows (`SignUpScreen` /
/// `SignInScreen`), not one combined "continue" action: Sign Up always
/// creates a fresh credential and writes `users/{uid}.signupCompletedAt`;
/// Sign In always authenticates an existing credential and errors out if no
/// `users/{uid}` profile is found, rather than silently creating one.
///
/// MP/official identity = Firebase email/password auth, keyed by a
/// constituency ID rather than an email address (mapped internally — see
/// [signInOfficial]). Officials are provisioned out-of-band (their
/// `users/{uid}` doc's `role`/`constituencyId` is set by an admin, not
/// self-assigned at login).
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static const _officialEmailSuffix = '@mp.prajadhwani.app';

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Signs in anonymously if no session exists yet. Firebase Auth persists
  /// the anonymous session across app restarts, so this only actually hits
  /// the network the very first time a device opens the app.
  ///
  /// Translates "the Anonymous provider isn't enabled on this Firebase
  /// project" into [AadhaarOcrFailure.authUnavailable] rather than letting a
  /// raw `FirebaseAuthException` escape. That distinction matters: this is
  /// called from the Aadhaar upload step *before* the citizen has picked a
  /// sign-in method, so a disabled provider used to surface to them as
  /// "we couldn't read your photo" — a project misconfiguration disguised
  /// as an image problem, which is close to undiagnosable from the UI.
  Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      const providerDisabledCodes = {
        'operation-not-allowed',
        'admin-restricted-operation',
        'configuration-not-found',
      };
      if (providerDisabledCodes.contains(e.code) ||
          (e.message?.contains('CONFIGURATION_NOT_FOUND') ?? false)) {
        throw AadhaarOcrException(
          AadhaarOcrFailure.authUnavailable,
          debugMessage: 'Anonymous sign-in unavailable: ${e.code} ${e.message}',
        );
      }
      if (e.code == 'network-request-failed') {
        throw AadhaarOcrException(
          AadhaarOcrFailure.network,
          debugMessage: e.message,
        );
      }
      rethrow;
    }
  }

  /// Starts real Firebase Phone Auth for a citizen entering their number on
  /// the Welcome screen. [onCodeSent] fires once the SMS has gone out, with
  /// a `verificationId` to pass back into [confirmSmsCode]. On Android,
  /// Play Integrity can silently auto-verify without the user ever typing a
  /// code — [onAutoVerified] fires that completed sign-in directly, so
  /// callers should skip the OTP field entirely in that case.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(User user) onAutoVerified,
    required void Function(String message) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        final result = await _auth.signInWithCredential(credential);
        onAutoVerified(result.user!);
      },
      verificationFailed: (e) => onError(e.message ?? 'Verification failed.'),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Completes phone sign-in with the 6-digit code the citizen typed in,
  /// against the `verificationId` handed back by [startPhoneVerification].
  Future<User> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  /// MP office login — the constituency ID is mapped to a synthetic email
  /// address internally so Firebase's standard email/password auth can be
  /// reused without exposing "email" as a concept to the official user.
  Future<User> signInOfficial({
    required String constituencyId,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: '${constituencyId.trim().toLowerCase()}$_officialEmailSuffix',
      password: password,
    );
    return credential.user!;
  }

  Future<void> signOut() => _auth.signOut();
}
