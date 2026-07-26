/// Typed failures for flows where "something went wrong" is not an
/// acceptable answer — because the fix differs completely depending on what
/// actually broke.
///
/// The Aadhaar upload is the motivating case. It used to collapse *every*
/// failure into one string ("We couldn't process that image"): a disabled
/// Anonymous sign-in provider, an oversized photo, a Vertex AI quota error,
/// and a genuinely blurry card all looked identical to the citizen and to
/// anyone debugging it. Three of those four aren't image problems at all,
/// and the advice for each is different.
library;

/// What specifically went wrong during Aadhaar OCR.
///
/// Deliberately about *causes*, not HTTP codes — the UI maps each value to
/// its own actionable sentence, and every value keeps "type it in manually"
/// available, because the citizen must never be blocked from signing up by
/// an OCR convenience feature.
enum AadhaarOcrFailure {
  /// Firebase Anonymous sign-in is disabled on the project, so the session
  /// the OCR callable requires can't be established (surfaces as
  /// `CONFIGURATION_NOT_FOUND` / `operation-not-allowed`). A project
  /// configuration problem — no amount of retrying or re-photographing
  /// helps.
  authUnavailable,

  /// The callable rejected the caller's token.
  notSignedIn,

  /// The photo exceeded the request-size budget, client- or server-side.
  imageTooLarge,

  /// OCR ran fine but the model could not read the card. The one failure
  /// here that a better photo actually fixes.
  imageUnreadable,

  /// Vertex AI was unavailable, out of quota, or the runtime service
  /// account lacks `roles/aiplatform.user`.
  modelUnavailable,

  /// Offline, DNS failure, or timeout.
  network,

  /// Anything unclassified. Always logged with its stack trace.
  unknown,
}

/// Thrown by [AadhaarOcrService] and by `AuthService.ensureSignedIn` when
/// the session needed for OCR cannot be established.
///
/// [debugMessage] is for logs only — it may contain provider error text and
/// is never rendered to the citizen.
class AadhaarOcrException implements Exception {
  final AadhaarOcrFailure failure;
  final String? debugMessage;

  const AadhaarOcrException(this.failure, {this.debugMessage});

  @override
  String toString() =>
      'AadhaarOcrException(${failure.name}${debugMessage == null ? '' : ': $debugMessage'})';
}
