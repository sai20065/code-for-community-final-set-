import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// A processed image ready to be sent to an OCR/vision endpoint.
class ProcessedImage {
  final Uint8List bytes;
  final String mimeType;

  /// True when [bytes] were re-encoded rather than passed through. Worth
  /// surfacing in logs: a re-encode changes the mime type, and a *failed*
  /// re-encode silently falling back to the original is the kind of thing
  /// you want to see when an oversized payload still gets rejected.
  final bool reEncoded;

  const ProcessedImage({
    required this.bytes,
    required this.mimeType,
    this.reEncoded = false,
  });
}

/// Shrinks [bytes] so the longest edge is at most [maxDimension] and the
/// result fits within [maxBytes].
///
/// Exists because `image_picker`'s own `maxWidth`/`imageQuality` arguments
/// are **ignored by `image_picker_for_web`** — on the web build a 12 MP
/// phone photo arrives at full size and blows the callable's request limit,
/// which surfaced as an unexplained failure. On mobile the picker already
/// compressed the image, so this usually passes through untouched.
///
/// Note the deliberate asymmetry: re-encoding happens only when the image
/// is actually over budget. `ui.Image.toByteData` can only emit PNG, and a
/// PNG re-encode of a *photo* is typically larger than its JPEG source —
/// so unconditionally "optimising" every image would make most of them
/// bigger. Returns the original bytes untouched whenever they already fit.
Future<ProcessedImage> downscaleForOcr(
  Uint8List bytes, {
  required String mimeType,
  int maxDimension = 1600,
  int maxBytes = 3 * 1024 * 1024,
}) async {
  if (bytes.length <= maxBytes) {
    return ProcessedImage(bytes: bytes, mimeType: mimeType);
  }

  // Step the target size down until the PNG re-encode fits, rather than
  // guessing a single ratio — PNG size depends on image content, not just
  // pixel count, so one pass is not reliably enough.
  for (final target in <int>[maxDimension, 1200, 900]) {
    try {
      final resized = await _reEncode(bytes, target);
      if (resized == null) continue;
      if (resized.length <= maxBytes) {
        return ProcessedImage(
          bytes: resized,
          mimeType: 'image/png',
          reEncoded: true,
        );
      }
    } catch (e) {
      debugPrint('downscaleForOcr: re-encode at $target failed: $e');
    }
  }

  // Every attempt failed or stayed over budget. Return the original and let
  // the server-side size guard reject it with a specific, honest error —
  // that is strictly more informative than anything we can decide here.
  debugPrint(
    'downscaleForOcr: could not get ${bytes.length} bytes under $maxBytes',
  );
  return ProcessedImage(bytes: bytes, mimeType: mimeType);
}

Future<Uint8List?> _reEncode(Uint8List bytes, int maxDimension) async {
  final descriptor = await ui.ImageDescriptor.encoded(
    await ui.ImmutableBuffer.fromUint8List(bytes),
  );
  final width = descriptor.width;
  final height = descriptor.height;
  final longest = width > height ? width : height;

  // Already small enough in pixel terms — shrinking further would only
  // destroy the detail the OCR model needs to read the card.
  if (longest <= maxDimension) {
    descriptor.dispose();
    return null;
  }

  final scale = maxDimension / longest;
  final codec = await descriptor.instantiateCodec(
    targetWidth: (width * scale).round(),
    targetHeight: (height * scale).round(),
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);

  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();

  return data?.buffer.asUint8List();
}
