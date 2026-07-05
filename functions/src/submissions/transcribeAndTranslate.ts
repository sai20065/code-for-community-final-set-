import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  REGION,
  bhashiniApiKey,
  bhashiniAsrPipelineId,
  bhashiniTranslationPipelineId,
} from "../config";
import {BhashiniClient} from "../lib/bhashiniClient";

interface Request {
  audioBase64: string;
  sourceLanguage: string;
}

/**
 * Standalone wrapper around the same Bhashini pipeline used by
 * `onSubmissionCreated`, for manual reprocessing of a ticket whose
 * automatic transcription failed, and for isolated testing via the
 * Cloud Functions emulator shell (`firebase functions:shell`) without
 * needing to write a fake Firestore document first.
 */
export const transcribeAndTranslate = onCall(
  {
    region: REGION,
    secrets: [bhashiniApiKey, bhashiniAsrPipelineId, bhashiniTranslationPipelineId],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const data = request.data as Request;
    if (!data?.audioBase64) {
      throw new HttpsError("invalid-argument", "audioBase64 is required.");
    }

    const bhashini = new BhashiniClient(
      bhashiniApiKey.value(),
      bhashiniAsrPipelineId.value(),
      bhashiniTranslationPipelineId.value(),
    );
    const transcript = await bhashini.speechToText({
      audioBase64: data.audioBase64,
      sourceLanguage: data.sourceLanguage,
    });
    const translatedText = await bhashini.translate({
      text: transcript,
      sourceLanguage: data.sourceLanguage,
      targetLanguage: "en",
    });
    return {transcript, translatedText};
  },
);
