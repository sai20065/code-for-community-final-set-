import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {MAX_OCR_IMAGE_BYTES, REGION} from "../config";
import {GeminiClient} from "../lib/geminiClient";

interface Request {
  imageBase64Front: string;
  imageBase64Back?: string;
  mimeType: string;
}

/** Machine-readable cause, sent to the client in `HttpsError.details.reason`
 * and mapped there to a specific, actionable sentence. The client cannot
 * distinguish causes from the error *code* alone — several distinct
 * failures share `internal` — so the reason string is the real contract. */
type FailureReason =
  | "not-signed-in"
  | "missing-image"
  | "image-too-large"
  | "model-busy"
  | "model-permission"
  | "model-error";

function fail(
  code: "unauthenticated" | "invalid-argument" | "resource-exhausted" | "internal",
  reason: FailureReason,
  message: string,
): never {
  throw new HttpsError(code, message, {reason});
}

/** Decoded size of a base64 payload, without actually allocating the
 * buffer — the whole point is to reject oversized images cheaply. */
function decodedBytes(base64: string): number {
  const padding = base64.endsWith("==") ? 2 : base64.endsWith("=") ? 1 : 0;
  return Math.floor((base64.length * 3) / 4) - padding;
}

/** Classifies a thrown Vertex AI error. The SDK surfaces status codes
 * inconsistently (sometimes `.code`, sometimes only in the message), so this
 * checks both rather than trusting one shape. */
function classifyVertexError(err: unknown): {
  code: "resource-exhausted" | "internal";
  reason: FailureReason;
  message: string;
} {
  const text = err instanceof Error ? `${err.message}` : String(err);
  const status = (err as {code?: number | string})?.code;
  const has = (...needles: Array<string | number>) =>
    needles.some((n) => text.includes(String(n)) || status === n);

  if (has(429, "RESOURCE_EXHAUSTED", "Quota exceeded", "rate limit")) {
    return {
      code: "resource-exhausted",
      reason: "model-busy",
      message: "The reader is busy right now — please try again in a moment.",
    };
  }
  if (has(403, 401, "PERMISSION_DENIED", "UNAUTHENTICATED", "aiplatform")) {
    // Almost always the runtime service account missing
    // `roles/aiplatform.user`, or `aiplatform.googleapis.com` disabled —
    // an operator problem, not something the citizen can act on.
    return {
      code: "internal",
      reason: "model-permission",
      message: "The reader is unavailable right now.",
    };
  }
  return {
    code: "internal",
    reason: "model-error",
    message: "The reader failed unexpectedly.",
  };
}

/**
 * One-time convenience extraction of {name, address, pincode, wardNumber}
 * from self-uploaded Aadhaar front/back photos, via Vertex-AI-backed
 * Gemini vision (see `GeminiClient.extractAadhaarFields`). The decoded
 * images only ever exist in this function's memory for the duration of the
 * call — they are never written to Cloud Storage, Firestore, or disk, and
 * the Aadhaar number itself is never read back to the client (scrubbed as
 * defense-in-depth even if the model ignores the prompt instruction not to
 * include one).
 *
 * This is NOT verified UIDAI eKYC. Nothing here cryptographically proves
 * the uploader is who the document names — it is purely OCR convenience so
 * citizens don't have to type their name/address/pincode/ward by hand.
 *
 * **Every failure mode is reported distinctly** (`details.reason`), because
 * this call has four genuinely different ways to fail — auth, payload size,
 * model availability, and an unreadable photo — and only the last is fixed
 * by taking a better picture. Collapsing them into one message, as this
 * previously did, made a disabled auth provider indistinguishable from a
 * blurry card.
 */
export const extractAadhaarDetails = onCall(
  {region: REGION},
  async (request) => {
    const startedAt = Date.now();

    if (!request.auth) {
      fail("unauthenticated", "not-signed-in", "Sign in required.");
    }
    const data = request.data as Request;
    if (!data?.imageBase64Front) {
      fail("invalid-argument", "missing-image", "imageBase64Front is required.");
    }

    const frontBytes = decodedBytes(data.imageBase64Front);
    const backBytes = data.imageBase64Back ?
      decodedBytes(data.imageBase64Back) :
      0;
    if (frontBytes > MAX_OCR_IMAGE_BYTES || backBytes > MAX_OCR_IMAGE_BYTES) {
      fail(
        "invalid-argument",
        "image-too-large",
        "That photo is too large to process.",
      );
    }

    const gemini = new GeminiClient();
    try {
      const result = await gemini.extractAadhaarFields(
        data.imageBase64Front,
        data.mimeType || "image/jpeg",
        data.imageBase64Back,
      );

      const fieldsFound = {
        name: !!result.name,
        address: !!result.address,
        pincode: !!result.pincode,
        ward: !!result.wardNumber,
      };
      const readable = Object.values(fieldsFound).some(Boolean);

      // Never log image bytes — only their sizes and what was found.
      logger.info("aadhaar_ocr", {
        uid: request.auth.uid,
        hasBack: !!data.imageBase64Back,
        frontBytes,
        backBytes,
        mimeType: data.mimeType || "image/jpeg",
        latencyMs: Date.now() - startedAt,
        confidence: result.confidence,
        fieldsFound,
        readable,
      });

      // An unreadable card is a RESULT, not an exception. Throwing here
      // would show the citizen a scary error for the one outcome that is
      // both expected and easily recovered from ("type it in instead").
      return {
        name: result.name ?? null,
        address: result.address ?? null,
        pincode: result.pincode ?? null,
        wardNumber: result.wardNumber ?? null,
        confidence: result.confidence,
        reason: readable ? null : "unreadable",
      };
    } catch (err) {
      const classified = classifyVertexError(err);
      logger.error("aadhaar_ocr_failed", {
        uid: request.auth.uid,
        frontBytes,
        backBytes,
        latencyMs: Date.now() - startedAt,
        reason: classified.reason,
        error: err instanceof Error ? err.message : String(err),
      });
      fail(classified.code, classified.reason, classified.message);
    }
  },
);
