import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import {feature, point} from "@turf/helpers";
import type {Feature, GeometryCollection, Polygon} from "geojson";
import wardsData from "../data/gba_wards.json";

interface WardProperties {
  ward_id: string;
  ward_name: string;
  corporation: string;
}

type WardGeometry = Polygon | GeometryCollection;

const FEATURES = (wardsData as {
  features: Feature<WardGeometry, WardProperties>[];
}).features;

/** ward_id is only unique *within* a corporation — see seedWards.ts. */
export function wardDocId(corporation: string, wardId: string): string {
  return `${corporation}-${wardId}`;
}

export interface ResolvedWard {
  wardId: string;
  wardName: string;
  corporation: string;
}

/**
 * Point-in-polygon lookup against Bengaluru's 369 GBA ward boundaries. A
 * handful of wards (disjoint parts, e.g. "Aerocity") serialize as a
 * `GeometryCollection` of Polygons rather than a single `Polygon` — turf's
 * `booleanPointInPolygon` doesn't accept that geometry type directly, so
 * each sub-polygon is checked individually for those wards.
 */
export function resolveWardForPoint(lat: number, lng: number): ResolvedWard | null {
  const pt = point([lng, lat]);
  for (const f of FEATURES) {
    try {
      const polygons: Feature<Polygon>[] =
        f.geometry.type === "Polygon" ?
          [feature(f.geometry as Polygon)] :
          (f.geometry as GeometryCollection).geometries.map((g) => feature(g as Polygon));
      if (polygons.some((poly) => booleanPointInPolygon(pt, poly))) {
        return {
          wardId: wardDocId(f.properties.corporation, f.properties.ward_id),
          wardName: f.properties.ward_name,
          corporation: f.properties.corporation,
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}
