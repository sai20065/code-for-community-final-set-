import {defineSecret} from "firebase-functions/params";

/**
 * Gmail SMTP credentials for sending MP credential-delivery emails (first-
 * time setup + forgot-credentials, see functions/src/officials/). A
 * dedicated Gmail account + App Password (not the account's normal login
 * password) — set with:
 *   firebase functions:secrets:set EMAIL_USER
 *   firebase functions:secrets:set EMAIL_APP_PASSWORD
 */
export const emailUser = defineSecret("EMAIL_USER");
export const emailAppPassword = defineSecret("EMAIL_APP_PASSWORD");

/**
 * Salt for the per-cluster reporter hashes (see `clusterAggregates.ts`).
 * Clusters record *how many distinct people* reported an issue, which the
 * Root-Cause agent needs to tell "40 households" from "one very persistent
 * neighbour". Storing raw uids on a cluster to do that would put an
 * identifier one denormalisation mistake away from the public projection,
 * so we store salted SHA-256 digests instead — countable, not reversible.
 * Set with: firebase functions:secrets:set REPORTER_HASH_SALT
 */
export const reporterHashSalt = defineSecret("REPORTER_HASH_SALT");

/**
 * Every Gemini call (transcription, photo captioning,
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

/** The single Gemini model every AI task in this app uses. Lives here
 * rather than in `geminiClient.ts` so the agent layer can record it in
 * transcripts without importing the client (an audit trail is worthless if
 * it can't say what generated the text). */
export const GEMINI_MODEL = "gemini-2.5-flash";

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

/* -------------------------------------------------------------------------
 * Civic intelligence layer (functions/src/agents/)
 * ---------------------------------------------------------------------- */

/** Same model as everything else — one billing path, one place to change. */
export const AGENT_MODEL = GEMINI_MODEL;

/** Cluster sizes at which the four-agent chain re-runs. Deliberately sparse
 * and superlinear: the analysis barely changes between 5 and 6 tickets, and
 * an agent run is 4 Gemini calls. Same cost-control instinct as the every-
 * 5th-ticket summary refresh in `onSubmissionCreated`. */
export const AGENT_TRIGGER_COUNTS = [5, 15, 40] as const;

/** A cluster crossing into "red" also earns an analysis run regardless of
 * how few tickets it has — a safety-critical issue shouldn't wait for its
 * fifth report. Matches the map's hotspot threshold so the flame marker and
 * the Solution Card appear together. */
export const AGENT_PRIORITY_THRESHOLD = 70;

/** Floor between two automatic runs on the same cluster. Guards against a
 * burst of tickets crossing several thresholds within minutes. */
export const AGENT_MIN_RERUN_HOURS = 6;

/** How long a cluster's agent-run lock stays valid before another
 * invocation may claim it. Longer than the orchestrator's own wall-clock
 * budget, so a crashed run self-heals instead of deadlocking. */
export const AGENT_LOCK_MINUTES = 5;

/** Wall-clock budget for one full four-agent chain. On exceeding it the
 * orchestrator stops calling Gemini and uses deterministic fallbacks for
 * the remaining agents — a degraded card beats a timed-out function. */
export const AGENT_TIME_BUDGET_MS = 90_000;

/* -------------------------------------------------------------------------
 * Public projection (functions/src/public/)
 * ---------------------------------------------------------------------- */

/** Grid size that public map coordinates are snapped to, in degrees.
 * ~330 m at Indian latitudes — coarse enough that a pin can't be walked
 * back to a house, fine enough that a ward-level map still reads. */
export const PUBLIC_GEO_SNAP_DEGREES = 0.003;

/** k-anonymity floor: a ticket only gets a public map point once its
 * cluster holds at least this many reports. A lone pin in a sparse ward
 * *is* somebody's address, no matter how much it has been snapped. */
export const PUBLIC_GEO_MIN_TICKETS = 3;

/* -------------------------------------------------------------------------
 * Citizen accounts (functions/src/citizens/)
 * ---------------------------------------------------------------------- */

/** Citizens log in with a username; Firebase Auth gets this synthetic,
 * undeliverable address instead. Must match `AuthService` in the app. */
export const CITIZEN_EMAIL_SUFFIX = "@citizen.prajadhwani.app";

/** Ids of the fixed security questions. Question text lives in the app's
 * ARB files; must match `kSecurityQuestionIds` in auth_service.dart. */
export const SECURITY_QUESTION_IDS = [
  "firstSchool",
  "motherBirthplace",
  "favouriteFood",
  "childhoodFriend",
  "firstVehicle",
];

/** Wrong answers allowed before password recovery locks... */
export const RECOVERY_MAX_ATTEMPTS = 5;
/** ...and for how long. */
export const RECOVERY_LOCK_MINUTES = 15;

/* -------------------------------------------------------------------------
 * Per-ticket "suggested office" (functions/src/assignment/)
 * ---------------------------------------------------------------------- */

/**
 * Gemma runs on the **free** Gemini Developer API (Google AI Studio), not on
 * Vertex AI, which has no free tier. The key must be created in a Google
 * Cloud project with *no billing account attached*, so it can never be
 * charged — the free tier's rate limits are far above pilot volume. Only
 * the PII-free `publicSummary` is ever sent with it, since free-tier
 * prompts may be used by Google. Set with:
 *   firebase functions:secrets:set GEMMA_API_KEY
 */
/** Flip to true once `GEMMA_API_KEY` exists. The deploy CLI demands a
 * value for every *declared* secret, so the secret isn't even defined
 * until then. While false, every ticket still gets a suggestion from the
 * deterministic rules. */
export const GEMMA_ENABLED = false;

export const gemmaApiKey = GEMMA_ENABLED ? defineSecret("GEMMA_API_KEY") : null;

/** Tried in order; the first id the API recognises is used. */
export const GEMMA_MODELS = ["gemma-4-26b-a4b-it", "gemma-3-27b-it"];

/** Below this, the model's pick is ignored in favour of the rules' top
 * candidate. */
export const ROUTER_MIN_CONFIDENCE = 0.5;
