/**
 * Every Gemini call (Aadhaar OCR, transcription, photo captioning,
 * classification, cluster summarization) runs via Vertex AI, authenticated
 * through the function's own runtime service account (Application Default
 * Credentials — no API key/secret to manage) rather than the Gemini
 * Developer API's separate AI-Studio prepay balance. This was migrated
 * from the AI-Studio key after that balance silently ran out and broke
 * the whole AI pipeline with no visible error anywhere in the app —
 * Vertex AI bills against the project's regular (already-active, Blaze
 * plan) Cloud Billing account instead, so there's no separate balance to
 * run dry. Requires the runtime service account
 * (`{project-number}-compute@developer.gserviceaccount.com`) to hold
 * `roles/aiplatform.user`, and `aiplatform.googleapis.com` enabled on the
 * project — both already done as of this migration.
 */
export const VERTEX_AI_PROJECT = "code-for-community-e2cf2";
export const VERTEX_AI_LOCATION = "us-central1";

/**
 * Translation runs via the Cloud Translation API (see `TranslateClient`),
 * authenticated through the function's own runtime service account —
 * only `translate.googleapis.com` needs to be enabled on the project.
 */

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
