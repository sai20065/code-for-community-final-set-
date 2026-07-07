import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

/// Result of transcribing a voice recording: the verbatim [transcript] in the
/// citizen's own language, plus an English [translatedText] used downstream
/// for classification/clustering. Only [transcript] is shown to the citizen.
class TranscriptionResult {
  final String transcript;
  final String translatedText;

  const TranscriptionResult({
    required this.transcript,
    required this.translatedText,
  });
}

/// Calls the `transcribeAndTranslate` Cloud Function (see `functions/src/
/// submissions/transcribeAndTranslate.ts`) so a citizen sees their spoken
/// report turned into editable text **before** they submit — instead of the
/// old flow where transcription only happened invisibly, server-side, after
/// submission. Same callable pattern as `AadhaarOcrService`; requires an
/// authenticated session (the citizen is already signed in by this screen).
class TranscriptionService {
  TranscriptionService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<TranscriptionResult> transcribe({
    required File audio,
    required String sourceLanguage,
  }) async {
    final bytes = await audio.readAsBytes();
    final callable = _functions.httpsCallable('transcribeAndTranslate');
    final response = await callable.call<Map<String, dynamic>>({
      'audioBase64': base64Encode(bytes),
      'sourceLanguage': sourceLanguage,
      'mimeType': 'audio/mp4',
    });
    final data = response.data;
    return TranscriptionResult(
      transcript: data['transcript'] as String? ?? '',
      translatedText: data['translatedText'] as String? ?? '',
    );
  }
}
