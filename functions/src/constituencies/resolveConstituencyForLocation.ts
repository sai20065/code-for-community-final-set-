import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";
import {resolveTalukForPoint} from "../lib/talukGeo";
import {resolveWardForPoint, wardDocId} from "../lib/wardGeo";

interface Request {
  lat: number;
  lng: number;
}

/**
 * Authoritative area lookup for a lat/lng, via point-in-polygon against
 * India's real 543 Lok Sabha constituency boundaries, Karnataka's 227
 * taluks/30 districts and Bengaluru's 369 GBA wards — used at Location
 * Setup (and whenever a citizen re-confirms their pin) instead of the old
 * pincode/booth-array heuristic, which only ever covered the handful of
 * pincodes manually seeded into `booths`.
 *
 * Returns all four layers in one call so signup can stamp a citizen's home
 * district, taluk and ward onto their profile in a single round trip — the
 * same layers `onSubmissionCreated` resolves per ticket, so a citizen's
 * profile and their reports agree about where they are.
 *
 * Runs server-side because the boundary datasets (~12MB across four files)
 * are far too large to ship in the client app just for this lookup.
 */
export const resolveConstituencyForLocation = onCall(
  {region: REGION},
  (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const data = request.data as Request;
    if (typeof data?.lat !== "number" || typeof data?.lng !== "number") {
      throw new HttpsError("invalid-argument", "lat and lng are required.");
    }
    const constituency = resolveConstituencyForPoint(data.lat, data.lng);
    const taluk = resolveTalukForPoint(data.lat, data.lng);
    const ward = resolveWardForPoint(data.lat, data.lng);

    return {
      constituencyId: constituency?.constituencyId ?? null,
      constituencyName: constituency?.constituencyName ?? null,
      state: constituency?.state ?? null,
      districtId: taluk?.districtId ?? null,
      districtName: taluk?.districtName ?? null,
      talukId: taluk?.talukId ?? null,
      talukName: taluk?.talukName ?? null,
      wardId: ward ? wardDocId(ward.corporation, ward.wardId) : null,
      wardName: ward?.wardName ?? null,
    };
  },
);
