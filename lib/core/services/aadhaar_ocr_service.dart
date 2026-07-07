import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

/// Result of one-time Aadhaar OCR extraction. Only these five fields ever
/// leave the Cloud Function — no Aadhaar number, no image, no other field
/// on the document is read back to the client or persisted anywhere.
class AadhaarExtractionResult {
  final String? name;
  final String? address;
  final String? pincode;
  final String? wardNumber;
  final double confidence;

  const AadhaarExtractionResult({
    this.name,
    this.address,
    this.pincode,
    this.wardNumber,
    this.confidence = 0,
  });

  bool get looksUsable => pincode != null && pincode!.length == 6;
}

/// Calls the `extractAadhaarDetails` Cloud Function (see `functions/src/
/// aadhaar/extractAadhaarDetails.ts`), backed by Vertex-AI Gemini vision
/// (see `functions/src/lib/geminiClient.ts`). Images are sent as base64 in
/// the request payload and are never written to Cloud Storage or disk
/// anywhere in this pipeline — the Cloud Function reads them once, in
/// memory, to run OCR, and discards them the moment the call returns. This
/// is a one-time convenience extraction, not verified UIDAI eKYC: nothing
/// here proves the uploader is who the document names.
class AadhaarOcrService {
  AadhaarOcrService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  /// Derives the real mime type from the picked file's extension — image_picker
  /// doesn't always normalize to JPEG (e.g. a PNG picked from the gallery
  /// stays PNG), and sending the wrong mime type to the vision model can
  /// degrade or break extraction.
  String _mimeTypeFor(File file) {
    final ext = file.path.split('.').last.toLowerCase();
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

  /// [front] is required; [back] is optional — the back side of an Aadhaar
  /// card often carries the full address the front truncates, so sending it
  /// too (when captured) improves extraction accuracy, but citizens can
  /// always skip straight to manual entry instead.
  ///
  /// Throws on failure (network issue, OCR outage, etc.) — callers must
  /// catch this and show a visible error/retry option rather than letting
  /// it propagate silently, same as every other submit-flow in this app.
  Future<AadhaarExtractionResult> extractDetails({
    required File front,
    File? back,
  }) async {
    final frontBytes = await front.readAsBytes();
    final callable = _functions.httpsCallable('extractAadhaarDetails');
    final response = await callable.call<Map<String, dynamic>>({
      'imageBase64Front': base64Encode(frontBytes),
      if (back != null)
        'imageBase64Back': base64Encode(await back.readAsBytes()),
      'mimeType': _mimeTypeFor(front),
    });
    final data = response.data;
    return AadhaarExtractionResult(
      name: data['name'] as String?,
      address: data['address'] as String?,
      pincode: data['pincode'] as String?,
      wardNumber: data['wardNumber'] as String?,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}
