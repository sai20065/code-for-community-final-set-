import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION, bhashiniInferenceKey} from "../config";
import {BhashiniClient} from "../lib/bhashiniClient";
import {GeminiClient} from "../lib/geminiClient";
import {TranslateClient} from "../lib/translateClient";

interface Request {
  audioBase64: string;
  sourceLanguage: string;
  mimeType?: string;
}

/**
 * Voice note → transcript + English translation, called by the compose
 * screen before submit so the citizen can see and edit what was heard.
 *
 * Bhashini first (free, built for Indian languages); Gemini transcription
 * plus Cloud Translation only when Bhashini fails or times out, so a
 * citizen is never left without a transcript. `provider` says which ran.
 */
export const transcribeAndTranslate = onCall(
  {region: REGION, secrets: [bhashiniInferenceKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const data = request.data as Request;
    if (!data?.audioBase64) {
      throw new HttpsError("invalid-argument", "audioBase64 is required.");
    }
    const mimeType = data.mimeType ?? "audio/mp4";
    let lang = data.sourceLanguage || "hi";

    try {
      const bhashini = new BhashiniClient(bhashiniInferenceKey.value());
      // The transcript must come out in the language the citizen spoke, so
      // detect it rather than trust the app's language setting.
      lang = (await bhashini.detectLanguage(data.audioBase64, mimeType)) ?? lang;
      const result = await bhashini.transcribeAndTranslate(data.audioBase64, lang, mimeType);
      return {...result, language: lang, provider: "bhashini"};
    } catch (err) {
      console.warn("Bhashini voice failed; using Gemini", err);
    }

    const gemini = new GeminiClient();
    const translate = new TranslateClient();
    const transcript = await gemini.transcribeAudioBase64(data.audioBase64, mimeType, lang);
    const translatedText = await translate.translate({
      text: transcript,
      sourceLanguage: lang,
      targetLanguage: "en",
    });
    return {transcript, translatedText, language: lang, provider: "gemini"};
  },
);
