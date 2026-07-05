import 'package:firebase_auth/firebase_auth.dart';

/// Identity = Firebase Anonymous Auth. There is no phone number and no
/// Aadhaar number anywhere in this app: sign-in is invisible to the citizen
/// (no OTP, no password) and only exists to give Firestore security rules a
/// stable `request.auth.uid` to anchor ownership on. The Aadhaar Upload
/// screen (see `AadhaarOcrService`) is purely a one-time onboarding
/// convenience that extracts name/address/pincode from a self-uploaded
/// image — it is NOT verified UIDAI eKYC and makes no claim the uploader is
/// who the document says they are.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

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

  Future<void> signOut() => _auth.signOut();
}
