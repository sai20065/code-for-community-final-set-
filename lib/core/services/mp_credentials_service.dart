import 'package:cloud_functions/cloud_functions.dart';

/// Calls the `mpFirstTimeSetup`/`mpForgotCredentials` Cloud Functions (see
/// `functions/src/officials/`) — neither requires a signed-in session
/// (an MP setting up or locked out of their account has no session yet),
/// so these are public callables gated only by knowing the constituency's
/// `uniqueId`.
class MpCredentialsService {
  MpCredentialsService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<void> firstTimeSetup({required String uniqueId, required String email}) async {
    final callable = _functions.httpsCallable('mpFirstTimeSetup');
    await callable.call<Map<String, dynamic>>({'uniqueId': uniqueId, 'email': email});
  }

  Future<void> forgotCredentials({required String uniqueId, required String email}) async {
    final callable = _functions.httpsCallable('mpForgotCredentials');
    await callable.call<Map<String, dynamic>>({'uniqueId': uniqueId, 'email': email});
  }
}
