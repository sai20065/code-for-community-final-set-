import {defineSecret} from "firebase-functions/params";

/**
 * Secrets, backed by Secret Manager (requires the Blaze plan). Set with:
 *   firebase functions:secrets:set GEMINI_API_KEY
 *   firebase functions:secrets:set BHASHINI_API_KEY
 *   firebase functions:secrets:set BHASHINI_ASR_PIPELINE_ID
 *   firebase functions:secrets:set BHASHINI_TRANSLATION_PIPELINE_ID
 *
 * GEMINI_API_KEY: from the Gemini Developer API (aistudio.google.com) — has
 * a free tier and does not itself require GCP billing, though Secret
 * Manager + Cloud Functions v2 deployment still needs Blaze regardless.
 *
 * BHASHINI_*: from registering at bhashini.gov.in (ULCA). The pipeline ids
 * identify which registered ASR/translation pipeline to call — confirm the
 * exact ids issued by your Bhashini registration before deploying.
 */
export const geminiApiKey = defineSecret("GEMINI_API_KEY");
export const bhashiniApiKey = defineSecret("BHASHINI_API_KEY");
export const bhashiniAsrPipelineId = defineSecret("BHASHINI_ASR_PIPELINE_ID");
export const bhashiniTranslationPipelineId = defineSecret(
  "BHASHINI_TRANSLATION_PIPELINE_ID",
);

export const REGION = "asia-south1";

/** The six citizen-facing category ids used throughout the app's UI. */
export const THEME_IDS = [
  "roads",
  "water",
  "electricity",
  "health",
  "sanitation",
  "education",
] as const;
export type ThemeId = (typeof THEME_IDS)[number];
