import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {GeminiClient} from "../lib/geminiClient";

interface Request {
  imageBase64Front: string;
  imageBase64Back?: string;
  mimeType: string;
}

/**
 * One-time convenience extraction of {name, address, pincode, wardNumber}
 * from self-uploaded Aadhaar front/back photos, via Vertex-AI-backed
 * Gemini vision (see `GeminiClient.extractAadhaarFields`) — migrated from
 * NVIDIA NIM so every AI task in this app now runs on the same Vertex AI
 * billing path (see `config.ts`). The decoded images only ever exist in
 * this function's memory for the duration of the call — they are never
 * written to Cloud Storage, Firestore, or disk, and the Aadhaar number
 * itself is never read back to the client (scrubbed as defense-in-depth
 * even if the model ignores the prompt instruction not to include one).
 *
 * This is NOT verified UIDAI eKYC. Nothing here cryptographically proves
 * the uploader is who the document names — it is purely OCR convenience so
 * citizens don't have to type their name/address/pincode/ward by hand.
 */
export const extractAadhaarDetails = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const data = request.data as Request;
    if (!data?.imageBase64Front) {
      throw new HttpsError("invalid-argument", "imageBase64Front is required.");
    }

    const gemini = new GeminiClient();
    try {
      const result = await gemini.extractAadhaarFields(
        data.imageBase64Front,
        data.mimeType || "image/jpeg",
        data.imageBase64Back,
      );
      return {
        name: result.name ?? null,
        address: result.address ?? null,
        pincode: result.pincode ?? null,
        wardNumber: result.wardNumber ?? null,
        confidence: result.confidence,
      };
    } catch (err) {
      console.error("Aadhaar OCR extraction failed", err);
      throw new HttpsError(
        "unavailable",
        "Could not read the Aadhaar photo right now — please try again or enter your details manually.",
      );
    }
  },
);
