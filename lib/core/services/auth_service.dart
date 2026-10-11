import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Why a username was rejected, so the UI can say exactly what to fix.
enum UsernameProblem { tooShort, tooLong, badCharacters }

/// Why a citizen auth call failed, mapped from Firebase error codes so
/// screens show a plain sentence instead of a raw `FirebaseAuthException`.
enum CitizenAuthFailure {
  usernameTaken,
  wrongCredentials,
  weakPassword,
  tooManyAttempts,
  network,
  unknown,
}

class CitizenAuthException implements Exception {
  final CitizenAuthFailure failure;
  final String? debugMessage;
  const CitizenAuthException(this.failure, {this.debugMessage});

  @override
  String toString() => 'CitizenAuthException(${failure.name}: $debugMessage)';
}

/// Citizens sign in with a **username and password** — no email, no phone
/// number, no ID document. Firebase Auth's email/password provider needs an
/// address, so the username is mapped to a synthetic one
/// (`<username>@citizen.prajadhwani.app`) that the citizen never sees and
/// that can never receive mail. Same trick [signInOfficial] has always used
/// for MP logins.
///
/// Because there is no inbox to send a reset link to, "Forgot password" is
/// a **security question** checked server-side — see
/// [AccountRecoveryService] and `functions/src/citizens/`.
///
/// Usernames are unique app-wide via a `usernames/{username}` reservation
/// doc written in the same flow as the account (see
/// `FirestoreService.reserveUsername`).
///
/// MP/official identity is unchanged: constituency ID + password, mapped to
/// `<constituencyId>@mp.prajadhwani.app`, provisioned out-of-band.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static const _officialEmailSuffix = '@mp.prajadhwani.app';
  static const _citizenEmailSuffix = '@citizen.prajadhwani.app';

  static const minUsernameLength = 4;
  static const maxUsernameLength = 20;

  /// Firebase's own floor; anything shorter is rejected server-side anyway.
  static const minPasswordLength = 6;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Usernames are case-insensitive: "Ravi_K" and "ravi_k" are one account.
  static String normalizeUsername(String raw) => raw.trim().toLowerCase();

  /// Null when [raw] is a valid username, otherwise what's wrong with it.
  /// Letters, digits, `_` and `.` only — no spaces or `@`, since the name
  /// becomes part of a synthetic email address.
  static UsernameProblem? validateUsername(String raw) {
    final u = normalizeUsername(raw);
    if (u.length < minUsernameLength) return UsernameProblem.tooShort;
    if (u.length > maxUsernameLength) return UsernameProblem.tooLong;
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(u)) {
      return UsernameProblem.badCharacters;
    }
    return null;
  }

  static String citizenEmailFor(String username) =>
      '${normalizeUsername(username)}$_citizenEmailSuffix';

  /// Creates a new citizen account. If this device still holds an older
  /// anonymous or phone session (from before usernames existed), the
  /// password credential is *linked* to it instead, so that citizen keeps
  /// the same uid — and with it every report they already filed.
  Future<User> signUpCitizen({
    required String username,
    required String password,
  }) async {
    final email = citizenEmailFor(username);
    try {
      final existing = _auth.currentUser;
      final canLink = existing != null &&
          !existing.providerData.any((p) => p.providerId == 'password');
      if (canLink) {
        final credential =
            EmailAuthProvider.credential(email: email, password: password);
        final result = await existing.linkWithCredential(credential);
        return result.user!;
      }
      if (existing != null) await _auth.signOut();
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<User> signInCitizen({
    required String username,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: citizenEmailFor(username),
        password: password,
      );
      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Change password while signed in. Firebase requires a recent login for
  /// this, so the current password is re-checked first — which also stops
  /// someone holding an unlocked phone from silently taking the account.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const CitizenAuthException(CitizenAuthFailure.wrongCredentials);
    }
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      ));
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  CitizenAuthException _mapAuthError(FirebaseAuthException e) {
    final failure = switch (e.code) {
      'email-already-in-use' ||
      'credential-already-in-use' ||
      'provider-already-linked' =>
        CitizenAuthFailure.usernameTaken,
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' ||
      'invalid-email' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        CitizenAuthFailure.wrongCredentials,
      'weak-password' => CitizenAuthFailure.weakPassword,
      'too-many-requests' => CitizenAuthFailure.tooManyAttempts,
      'network-request-failed' => CitizenAuthFailure.network,
      _ => CitizenAuthFailure.unknown,
    };
    return CitizenAuthException(failure, debugMessage: '${e.code} ${e.message}');
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

/// Ids of the fixed security questions. The question *text* is localized in
/// the ARB files (`securityQuestion_<id>`); only the id is stored.
const kSecurityQuestionIds = <String>[
  'firstSchool',
  'motherBirthplace',
  'favouriteFood',
  'childhoodFriend',
  'firstVehicle',
];

/// Why a password reset was refused.
enum RecoveryFailure { notMatched, locked, weakPassword, network, unknown }

class RecoveryException implements Exception {
  final RecoveryFailure failure;
  final String? debugMessage;
  const RecoveryException(this.failure, {this.debugMessage});

  @override
  String toString() => 'RecoveryException(${failure.name}: $debugMessage)';
}

/// "Forgot password" without email or SMS: the citizen answers the security
/// question they chose at Sign Up. The answer is only ever compared
/// server-side against a salted hash (`userSecrets/{uid}`, which no client
/// can read), and the server locks the account for 15 minutes after five
/// wrong answers so it can't be guessed by brute force. See
/// `functions/src/citizens/securityQuestion.ts`.
class AccountRecoveryService {
  AccountRecoveryService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  /// Saves (or replaces) the signed-in citizen's question and answer.
  Future<void> setSecurityQuestion({
    required String questionId,
    required String answer,
  }) async {
    try {
      await _functions.httpsCallable('setSecurityQuestion').call<void>({
        'questionId': questionId,
        'answer': answer,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _map(e);
    }
  }

  /// The question id for [username], so the reset screen can ask it. Returns
  /// null when there's nothing to ask (unknown username, or an account that
  /// never set a question) — deliberately indistinguishable, so this can't
  /// be used to discover which usernames exist.
  Future<String?> getSecurityQuestion(String username) async {
    try {
      final result = await _functions
          .httpsCallable('getSecurityQuestion')
          .call<Map<String, dynamic>>({
        'username': AuthService.normalizeUsername(username),
      });
      return result.data['questionId'] as String?;
    } on FirebaseFunctionsException catch (e) {
      throw _map(e);
    }
  }

  Future<void> resetPassword({
    required String username,
    required String answer,
    required String newPassword,
  }) async {
    try {
      await _functions.httpsCallable('resetPasswordWithSecurityQuestion').call<void>({
        'username': AuthService.normalizeUsername(username),
        'answer': answer,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _map(e);
    }
  }

  RecoveryException _map(FirebaseFunctionsException e) {
    final failure = switch (e.code) {
      'permission-denied' || 'not-found' => RecoveryFailure.notMatched,
      'resource-exhausted' => RecoveryFailure.locked,
      'invalid-argument' => RecoveryFailure.weakPassword,
      'unavailable' || 'deadline-exceeded' => RecoveryFailure.network,
      _ => RecoveryFailure.unknown,
    };
    return RecoveryException(failure, debugMessage: '${e.code} ${e.message}');
  }
}
