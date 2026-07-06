import {HttpsError, onCall} from "firebase-functions/v2/https";
import {nvidiaApiKey, REGION} from "../config";
import {NvidiaClient} from "../lib/nvidiaClient";

interface Request {
  imageBase64Front: string;
  imageBase64Back?: string;
  mimeType: string;
}

/**
 * One-time convenience extraction of {name, address, pincode, wardNumber}
 * from self-uploaded Aadhaar front/back photos, via an NVIDIA NIM
 * document-understanding vision model (see `NvidiaClient`) — every other
 * AI task in this app stays on Gemini. The decoded images only ever exist
 * in this function's memory for the duration of the call — they are never
 * written to Cloud Storage, Firestore, or disk, and the Aadhaar number
 * itself is never read back to the client (scrubbed as defense-in-depth
 * even if the model ignores the prompt instruction not to include one).
 *
 * This is NOT verified UIDAI eKYC. Nothing here cryptographically proves
 * the uploader is who the document names — it is purely OCR convenience so
 * citizens don't have to type their name/address/pincode/ward by hand.
 */
export const extractAadhaarDetails = onCall(
  {region: REGION, secrets: [nvidiaApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const data = request.data as Request;
    if (!data?.imageBase64Front) {
      throw new HttpsError("invalid-argument", "imageBase64Front is required.");
    }

    const nvidia = new NvidiaClient(nvidiaApiKey.value());
    const result = await nvidia.extractAadhaarFields(
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
  },
);
