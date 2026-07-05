import {HttpsError, onCall} from "firebase-functions/v2/https";
import {geminiApiKey, REGION} from "../config";
import {GeminiClient} from "../lib/geminiClient";

interface Request {
  imageBase64: string;
  mimeType: string;
}

/**
 * One-time convenience extraction of {name, address, pincode} from a
 * self-uploaded Aadhaar photo. The decoded image only ever exists in this
 * function's memory for the duration of the call — it is never written to
 * Cloud Storage, Firestore, or disk, and the Aadhaar number itself is never
 * read back to the client (scrubbed as defense-in-depth even if the model
 * ignores the prompt instruction not to include one).
 *
 * This is NOT verified UIDAI eKYC. Nothing here cryptographically proves
 * the uploader is who the document names — it is purely OCR convenience so
 * citizens don't have to type their name/address/pincode by hand.
 */
export const extractAadhaarDetails = onCall(
  {region: REGION, secrets: [geminiApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const data = request.data as Request;
    if (!data?.imageBase64) {
      throw new HttpsError("invalid-argument", "imageBase64 is required.");
    }

    const gemini = new GeminiClient(geminiApiKey.value());
    const result = await gemini.extractAadhaarFields(
      data.imageBase64,
      data.mimeType || "image/jpeg",
    );

    return {
      name: result.name ?? null,
      address: result.address ?? null,
      pincode: result.pincode ?? null,
      confidence: result.confidence,
    };
  },
);
