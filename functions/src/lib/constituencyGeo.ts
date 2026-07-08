import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import {point} from "@turf/helpers";
import type {Feature, MultiPolygon, Polygon} from "geojson";
import boundaries from "../data/india_pc_boundaries.json";

interface PcProperties {
  pc_id: number;
  st_name: string;
  pc_name: string;
}

const FEATURES = (boundaries as {
  features: Feature<Polygon | MultiPolygon, PcProperties>[];
}).features;

/**
 * pc_id 2924 ("Bangalore North" in the source data) is kept under the
 * pre-existing demo id `blr-north` so it lines up with the constituency/
 * booth/official docs already seeded under that id. Every other
 * constituency is keyed by its numeric `pc_id` (stable, nationally unique,
 * unlike constituency names which repeat across states).
 */
export function constituencyIdForPcId(pcId: number): string {
  if (pcId === 2924) return "blr-north";
  return String(pcId);
}

export function allConstituencyBoundaries(): Feature<Polygon | MultiPolygon, PcProperties>[] {
  return FEATURES;
}

export interface ResolvedConstituency {
  constituencyId: string;
  constituencyName: string;
  state: string;
}

/**
 * Real point-in-polygon lookup against India's 543 Lok Sabha constituency
 * boundaries (DataMeet, CC-BY-SA) — replaces guessing a constituency from a
 * pincode (pincodes and constituency boundaries don't reliably align).
 * Returns null if the point falls outside all 543 polygons (offshore, bad
 * GPS fix, etc.) — callers must treat that as "unresolved," not an error.
 *
 * KNOWN DATA CAVEAT: per the source dataset's own documentation, boundaries
 * for Jammu & Kashmir, Jharkhand, Assam, Manipur, Nagaland, and Arunachal
 * Pradesh are pre-2008-delimitation and may not reflect current
 * constituency lines — citizens in those states can resolve to a stale or
 * defunct constituency name until a better-sourced boundary set replaces
 * this data for them specifically.
 *
 * Karnataka's 28 constituencies are the exception: their `geometry` here has
 * been swapped for Karnataka's own official KSRSAC/KGIS PC_Boundaries data
 * (https://github.com/samashti/KGIS), simplified with `@turf/simplify`
 * (tolerance 0.0003, ~30m) to keep file size and map-render cost reasonable
 * while still being far more precise than the national DataMeet dataset's
 * original boundaries for this state. Every other state's 515 constituencies
 * are untouched DataMeet boundaries.
 */
export function resolveConstituencyForPoint(
  lat: number,
  lng: number,
): ResolvedConstituency | null {
  const pt = point([lng, lat]);
  for (const feature of FEATURES) {
    try {
      if (booleanPointInPolygon(pt, feature)) {
        return {
          constituencyId: constituencyIdForPcId(feature.properties.pc_id),
          constituencyName: feature.properties.pc_name,
          state: feature.properties.st_name,
        };
      }
    } catch {
      // Malformed ring in the source data — skip rather than fail the whole lookup.
      continue;
    }
  }
  return null;
}
