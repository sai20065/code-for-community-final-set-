import {defineSecret} from "firebase-functions/params";

/**
 * Secrets, backed by Secret Manager (requires the Blaze plan). Set with:
 *   firebase functions:secrets:set GEMINI_API_KEY
 *
 * GEMINI_API_KEY: from the Gemini Developer API (aistudio.google.com) — has
 * a free tier and does not itself require GCP billing, though Secret
 * Manager + Cloud Functions v2 deployment still needs Blaze regardless.
 *
 * Translation runs via the Cloud Translation API (see `TranslateClient`),
 * authenticated through the function's own runtime service account rather
 * than a secret — only `translate.googleapis.com` needs to be enabled on
 * the project.
 */
export const geminiApiKey = defineSecret("GEMINI_API_KEY");

/**
 * NVIDIA_API_KEY: from build.nvidia.com (NIM API catalog) — has a free
 * tier. Used only for Aadhaar OCR extraction (see `NvidiaClient` /
 * `extractAadhaarDetails.ts`); every other AI task in this app stays on
 * Gemini. Set with:
 *   firebase functions:secrets:set NVIDIA_API_KEY
 */
export const nvidiaApiKey = defineSecret("NVIDIA_API_KEY");

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
