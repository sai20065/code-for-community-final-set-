import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

/// Result of one-time Aadhaar OCR extraction. Only these four fields ever
/// leave the Cloud Function — no Aadhaar number, no image, no other field
/// on the document is read back to the client or persisted anywhere.
class AadhaarExtractionResult {
  final String? name;
  final String? address;
  final String? pincode;
  final double confidence;

  const AadhaarExtractionResult({
    this.name,
    this.address,
    this.pincode,
    this.confidence = 0,
  });

  bool get looksUsable => pincode != null && pincode!.length == 6;
}

/// Calls the `extractAadhaarDetails` Cloud Function (see `functions/src/
/// aadhaar/extractAadhaarDetails.ts`). The image is sent as base64 in the
/// request payload and is never written to Cloud Storage or disk anywhere
/// in this pipeline — the Cloud Function reads it once, in memory, to run
/// OCR, and discards it the moment the call returns. This is a one-time
/// convenience extraction, not verified UIDAI eKYC: nothing here proves the
/// uploader is who the document names.
class AadhaarOcrService {
  AadhaarOcrService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<AadhaarExtractionResult> extractDetails(File image) async {
    final bytes = await image.readAsBytes();
    final callable = _functions.httpsCallable('extractAadhaarDetails');
    final response = await callable.call<Map<String, dynamic>>({
      'imageBase64': base64Encode(bytes),
      'mimeType': 'image/jpeg',
    });
    final data = response.data;
    return AadhaarExtractionResult(
      name: data['name'] as String?,
      address: data['address'] as String?,
      pincode: data['pincode'] as String?,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}
