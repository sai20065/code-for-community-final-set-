import 'package:firebase_auth/firebase_auth.dart';

/// Citizen identity has three entry points, all landing on the same
/// `users/{uid}` document shape: **Anonymous** (invisible, no credential —
/// the original default, still available as "skip" for anyone who doesn't
/// want to attach a phone/email), **Phone** (real Firebase Phone Auth with
/// SMS OTP), and **Email/password**. Whichever is chosen, the Aadhaar Upload
/// step (see `AadhaarOcrService`) remains a one-time onboarding convenience
/// that extracts name/address/pincode/wardNumber from self-uploaded
/// front/back images — it is NOT verified UIDAI eKYC and makes no claim the
/// uploader is who the document says they are, regardless of which sign-in
/// method they used.
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
  Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
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

  /// Creates a brand-new citizen email account. Used only from the Sign Up
  /// screen — throws `email-already-in-use` (surfaced by the caller as
  /// "you already have an account, use Sign In instead") rather than
  /// silently signing the citizen into their existing account, since Sign
  /// Up and Sign In are now deliberately distinct flows.
  Future<User> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  /// Signs an existing citizen back in by email. Used only from the Sign In
  /// screen — throws `user-not-found`/`wrong-password` (surfaced by the
  /// caller as "no account found, please Sign Up first") rather than
  /// creating a new account, unlike the old combined `continueWithEmail`.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
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
