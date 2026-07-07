import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";

interface Request {
  lat: number;
  lng: number;
}

/**
 * Authoritative constituency lookup for a lat/lng, via point-in-polygon
 * against India's real 543 Lok Sabha constituency boundaries — used at
 * Location Setup (and whenever a citizen re-confirms their pin) instead of
 * the old pincode/booth-array heuristic, which only ever covered the
 * handful of pincodes manually seeded into `booths`. Runs server-side
 * because the boundary dataset (~1.4MB, 543 polygons) is too large to ship
 * in the client app just for this one lookup.
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
    const resolved = resolveConstituencyForPoint(data.lat, data.lng);
    return resolved ?? {constituencyId: null, constituencyName: null, state: null};
  },
);
