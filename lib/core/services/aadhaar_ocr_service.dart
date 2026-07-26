import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'app_exceptions.dart';

/// Result of one-time Aadhaar OCR extraction. Only these fields ever leave
/// the Cloud Function — no Aadhaar number, no image, no other field on the
/// document is read back to the client or persisted anywhere.
class AadhaarExtractionResult {
  final String? name;
  final String? address;
  final String? pincode;
  final String? wardNumber;
  final double confidence;

  /// True when the back image was dropped client-side to stay under the
  /// callable's request-size limit. The extraction still ran on the front,
  /// so this is a quality note, not a failure.
  final bool backDropped;

  const AadhaarExtractionResult({
    this.name,
    this.address,
    this.pincode,
    this.wardNumber,
    this.confidence = 0,
    this.backDropped = false,
  });

  static final _pincodePattern = RegExp(r'^[1-9][0-9]{5}$');

  bool get _hasPincode =>
      pincode != null && _pincodePattern.hasMatch(pincode!.trim());
  bool get _hasName => name != null && name!.trim().length >= 3;
  bool get _hasAddress => address != null && address!.trim().length >= 10;

  /// Whether the extraction produced anything worth pre-filling.
  ///
  /// Deliberately generous. This used to require a valid pincode and
  /// nothing else, which meant a crisp read of the citizen's name and full
  /// address was reported to them as a *failure* whenever the six digits
  /// happened to be smudged — throwing away good data and making them
  /// retype all of it. Any one usable field is a win; the citizen reviews
  /// and corrects the form regardless.
  bool get looksUsable => _hasPincode || _hasName || _hasAddress;

  /// True when something came back but not everything. The UI shows a
  /// "check these details" hint for this, never an error.
  bool get isPartial => looksUsable && !(_hasPincode && _hasName);
}

/// Calls the `extractAadhaarDetails` Cloud Function (see `functions/src/
/// aadhaar/extractAadhaarDetails.ts`), backed by Vertex-AI Gemini vision
/// (see `functions/src/lib/geminiClient.ts`). Images are sent as base64 in
/// the request payload and are never written to Cloud Storage or disk
/// anywhere in this pipeline — the Cloud Function reads them once, in
/// memory, to run OCR, and discards them the moment the call returns. This
/// is a one-time convenience extraction, not verified UIDAI eKYC: nothing
/// here proves the uploader is who the document names.
///
/// Takes raw bytes rather than `File` deliberately: `dart:io` doesn't exist
/// on the web, where `XFile.path` is a blob URL that `File()` cannot open —
/// the old `File`-based signature made this whole flow crash on the Firebase
/// Hosting build.
class AadhaarOcrService {
  AadhaarOcrService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  /// Callable HTTPS requests cap at 10 MB and base64 inflates by 4/3. Cap
  /// the *combined* encoded payload well below that so headers and the
  /// JSON envelope can't push a borderline request over.
  static const _maxCombinedEncodedBytes = 7 * 1024 * 1024;

  /// Derives the mime type from the picked file's name — `image_picker`
  /// doesn't normalize to JPEG (a PNG picked from the gallery stays PNG),
  /// and sending the wrong mime type to the vision model degrades or breaks
  /// extraction. Uses the name rather than a path because on web there is
  /// no path.
  String _mimeTypeForName(String? fileName) {
    final ext = (fileName ?? '').split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static int _encodedLength(int rawBytes) => ((rawBytes + 2) ~/ 3) * 4;

  /// [front] is required; [back] is optional — the back side of an Aadhaar
  /// card often carries the full address the front truncates, so sending it
  /// too (when captured) improves extraction accuracy, but citizens can
  /// always skip straight to manual entry instead.
  ///
  /// Throws [AadhaarOcrException] with a specific [AadhaarOcrFailure] on
  /// every failure path, so callers can say *what* went wrong instead of
  /// showing one catch-all message.
  Future<AadhaarExtractionResult> extractDetails({
    required Uint8List front,
    String? frontFileName,
    Uint8List? back,
    String? backFileName,
  }) async {
    // Drop the back image rather than failing the whole call when the pair
    // would exceed the request budget — a front-only extraction is far
    // better than an error, and the back is only ever an accuracy boost.
    var backBytes = back;
    var backDropped = false;
    if (backBytes != null &&
        _encodedLength(front.length) + _encodedLength(backBytes.length) >
            _maxCombinedEncodedBytes) {
      backBytes = null;
      backDropped = true;
    }

    try {
      final callable = _functions.httpsCallable('extractAadhaarDetails');
      final response = await callable.call<Map<String, dynamic>>({
        'imageBase64Front': base64Encode(front),
        if (backBytes != null) 'imageBase64Back': base64Encode(backBytes),
        'mimeType': _mimeTypeForName(frontFileName),
      });
      final data = response.data;

      // The function reports an unreadable card as a successful result, not
      // an error — but callers want it as a distinct failure so they can
      // suggest better lighting rather than a retry.
      if (data['reason'] == 'unreadable') {
        throw const AadhaarOcrException(AadhaarOcrFailure.imageUnreadable);
      }

      return AadhaarExtractionResult(
        name: data['name'] as String?,
        address: data['address'] as String?,
        pincode: data['pincode'] as String?,
        wardNumber: data['wardNumber'] as String?,
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
        backDropped: backDropped,
      );
    } on FirebaseFunctionsException catch (e) {
      throw AadhaarOcrException(
        _failureFor(e),
        debugMessage: '${e.code}/${e.details} ${e.message}',
      );
    } on AadhaarOcrException {
      rethrow;
    } catch (e) {
      throw AadhaarOcrException(
        AadhaarOcrFailure.unknown,
        debugMessage: e.toString(),
      );
    }
  }

  /// Maps the callable's error onto a cause. Prefers the explicit
  /// `details.reason` the function sets, because several distinct causes
  /// legitimately share the `internal` code.
  AadhaarOcrFailure _failureFor(FirebaseFunctionsException e) {
    final details = e.details;
    final reason = details is Map ? details['reason'] as String? : null;
    switch (reason) {
      case 'not-signed-in':
        return AadhaarOcrFailure.notSignedIn;
      case 'image-too-large':
        return AadhaarOcrFailure.imageTooLarge;
      case 'model-busy':
      case 'model-permission':
      case 'model-error':
        return AadhaarOcrFailure.modelUnavailable;
    }
    switch (e.code) {
      case 'unauthenticated':
        return AadhaarOcrFailure.notSignedIn;
      case 'invalid-argument':
        return AadhaarOcrFailure.imageTooLarge;
      case 'resource-exhausted':
      case 'unavailable':
        return AadhaarOcrFailure.modelUnavailable;
      case 'deadline-exceeded':
      case 'cancelled':
        return AadhaarOcrFailure.network;
      default:
        return AadhaarOcrFailure.unknown;
    }
  }
}
