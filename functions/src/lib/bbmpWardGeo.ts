import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import {feature, point} from "@turf/helpers";
import type {Feature, MultiPolygon, Polygon} from "geojson";
import wardsData from "../data/bbmp_wards_198.json";

/** The 198 BBMP wards (2010 delimitation — the wards on BBMP's printed
 * "Zones and Wards" map), from DataMeet's `BBMP_oldWards.geojson`
 * (CC BY-SA 2.5 India). A second ward layer alongside the 369 GBA wards in
 * `wardGeo.ts`, not a replacement: tickets carry both `wardId` (GBA) and
 * `bbmpWardId` (this). */
export const WARD_CORPORATION = "BBMP";

export interface WardProperties {
  ward_no: number;
  ward_name: string;
  assembly_constituency: string;
  assembly_no: string;
  total_population: number;
  sc_population: number;
  st_population: number;
  lat: number | null;
  lng: number | null;
}

export type WardGeometry = Polygon | MultiPolygon;

export const WARD_FEATURES = (wardsData as unknown as {
  features: Feature<WardGeometry, WardProperties>[];
}).features;

/** `wards/{id}` document id, e.g. `BBMP-150`. Ward numbers are unique
 * across all of BBMP, so the number alone identifies a ward. */
export function bbmpWardDocId(wardNo: number | string): string {
  return `${WARD_CORPORATION}-${wardNo}`;
}

export interface ResolvedBbmpWard {
  wardId: string;
  wardName: string;
  corporation: string;
}

/**
 * Point-in-polygon lookup against the 198 BBMP ward boundaries. Every ward
 * is stored as a `MultiPolygon` (a few have disjoint parts), which turf's
 * `booleanPointInPolygon` accepts directly.
 */
export function resolveBbmpWardForPoint(lat: number, lng: number): ResolvedBbmpWard | null {
  const pt = point([lng, lat]);
  for (const f of WARD_FEATURES) {
    try {
      if (booleanPointInPolygon(pt, feature(f.geometry))) {
        return {
          wardId: bbmpWardDocId(f.properties.ward_no),
          wardName: f.properties.ward_name,
          corporation: WARD_CORPORATION,
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}
