import 'package:firebase_auth/firebase_auth.dart';

/// Citizen identity = Firebase Anonymous Auth. There is no phone number and
/// no Aadhaar number anywhere in this app: sign-in is invisible to the
/// citizen (no OTP, no password) and only exists to give Firestore security
/// rules a stable `request.auth.uid` to anchor ownership on. The Aadhaar
/// Upload screen (see `AadhaarOcrService`) is purely a one-time onboarding
/// convenience that extracts name/address/pincode from a self-uploaded
/// image — it is NOT verified UIDAI eKYC and makes no claim the uploader is
/// who the document says they are.
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
