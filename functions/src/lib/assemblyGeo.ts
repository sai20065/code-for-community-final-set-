import booleanPointInPolygon from "@turf/boolean-point-in-polygon";
import {feature, point} from "@turf/helpers";
import type {Feature, MultiPolygon, Polygon} from "geojson";
import acData from "../data/karnataka_assembly.json";

/** Karnataka's 224 assembly constituencies (Vidhana Sabha seats — the MLA
 * layer), from DataMeet `maps/assembly-constituencies` (CC BY 2.5 India).
 * Every ticket is tagged with one so an MLA's dashboard can be scoped to
 * their seat. */
export interface AssemblyProperties {
  ac_no: number;
  ac_name: string;
  pc_no: number | null;
  district: string | null;
}

export const ASSEMBLY_FEATURES = (acData as unknown as {
  features: Feature<Polygon | MultiPolygon, AssemblyProperties>[];
}).features;

/** `assemblies/{id}` doc id, e.g. `KA-AC-150` (Yelahanka). */
export function assemblyDocId(acNo: number | string): string {
  return `KA-AC-${acNo}`;
}

export interface ResolvedAssembly {
  assemblyId: string;
  assemblyName: string;
}

export function resolveAssemblyForPoint(lat: number, lng: number): ResolvedAssembly | null {
  const pt = point([lng, lat]);
  for (const f of ASSEMBLY_FEATURES) {
    try {
      if (booleanPointInPolygon(pt, feature(f.geometry))) {
        return {
          assemblyId: assemblyDocId(f.properties.ac_no),
          assemblyName: f.properties.ac_name,
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}
