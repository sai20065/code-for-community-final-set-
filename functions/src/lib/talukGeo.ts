import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import {feature, point} from "@turf/helpers";
import type {Feature, MultiPolygon, Polygon} from "geojson";
import taluksData from "../data/karnataka_taluks.json";

interface TalukProperties {
  talukId: string;
  talukName: string;
  districtId: string;
  districtName: string;
  constituencyId: string | null;
}

const FEATURES = (taluksData as {
  features: Feature<Polygon | MultiPolygon, TalukProperties>[];
}).features;

export interface ResolvedTaluk {
  talukId: string;
  talukName: string;
  districtId: string;
  districtName: string;
}

/**
 * Point-in-polygon lookup against Karnataka's 227 taluks (KGIS/KSRSAC
 * official data) — the "ward-equivalent" fine-grained unit for MP
 * constituencies outside Bengaluru Urban (which uses the 369 GBA wards
 * instead, see `wardGeo.ts`). A handful of taluks have disjoint parts
 * (coastal/river enclaves) and serialize as `MultiPolygon` — turf's
 * `booleanPointInPolygon` handles that natively, unlike the `Polygon`-only
 * `GeometryCollection` case in `wardGeo.ts`.
 */
export function resolveTalukForPoint(lat: number, lng: number): ResolvedTaluk | null {
  const pt = point([lng, lat]);
  for (const f of FEATURES) {
    try {
      if (booleanPointInPolygon(pt, feature(f.geometry))) {
        return {
          talukId: f.properties.talukId,
          talukName: f.properties.talukName,
          districtId: f.properties.districtId,
          districtName: f.properties.districtName,
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}
