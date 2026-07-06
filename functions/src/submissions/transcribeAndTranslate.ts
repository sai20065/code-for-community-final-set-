import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION, geminiApiKey} from "../config";
import {GeminiClient} from "../lib/geminiClient";
import {TranslateClient} from "../lib/translateClient";

interface Request {
  audioBase64: string;
  sourceLanguage: string;
  mimeType?: string;
}

/**
 * Standalone wrapper around the same Gemini-transcription + Cloud-Translate
 * pipeline used by `onSubmissionCreated`, for manual reprocessing of a
 * ticket whose automatic transcription failed, and for isolated testing via
 * the Cloud Functions emulator shell (`firebase functions:shell`) without
 * needing to write a fake Firestore document first.
 */
export const transcribeAndTranslate = onCall(
  {
    region: REGION,
    secrets: [geminiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const data = request.data as Request;
    if (!data?.audioBase64) {
      throw new HttpsError("invalid-argument", "audioBase64 is required.");
    }

    const gemini = new GeminiClient(geminiApiKey.value());
    const translate = new TranslateClient();

    const transcript = await gemini.transcribeAudioBase64(
      data.audioBase64,
      data.mimeType ?? "audio/mp4",
      data.sourceLanguage,
    );
    const translatedText = await translate.translate({
      text: transcript,
      sourceLanguage: data.sourceLanguage,
      targetLanguage: "en",
    });
    return {transcript, translatedText};
  },
);
