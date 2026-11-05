import type {Geometry, Position} from "geojson";
import bbmpWardsData from "../data/bbmp_wards_198.json";
import gbaWardsData from "../data/gba_wards.json";
import districtsData from "../data/karnataka_districts.json";
import taluksData from "../data/karnataka_taluks.json";
import {bbmpWardDocId} from "../lib/bbmpWardGeo";
import {wardDocId} from "../lib/wardGeo";

export type AreaPrecision = "ward" | "taluk" | "district";

export interface AreaCentroid {
  lat: number;
  lng: number;
  precision: AreaPrecision;
}

type LatLng = {lat: number; lng: number};

/** Shoelace centroid of one linear ring; falls back to the vertex average
 * for degenerate (zero-area) rings. */
function ringCentroid(ring: Position[]): {c: LatLng; area: number} {
  let a = 0;
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < ring.length - 1; i++) {
    const [x0, y0] = ring[i];
    const [x1, y1] = ring[i + 1];
    const f = x0 * y1 - x1 * y0;
    a += f;
    cx += (x0 + x1) * f;
    cy += (y0 + y1) * f;
  }
  if (Math.abs(a) < 1e-12) {
    const n = ring.length || 1;
    const sx = ring.reduce((s, p) => s + p[0], 0);
    const sy = ring.reduce((s, p) => s + p[1], 0);
    return {c: {lng: sx / n, lat: sy / n}, area: 0};
  }
  a /= 2;
  return {c: {lng: cx / (6 * a), lat: cy / (6 * a)}, area: Math.abs(a)};
}

/** Centroid of the largest outer ring — an area's "main body", so a
 * district with a small detached enclave doesn't get its marker pulled
 * into the gap between the parts. */
function geometryCentroid(geometry: Geometry): LatLng | null {
  const outerRings: Position[][] = [];
  const collect = (g: Geometry) => {
    if (g.type === "Polygon") outerRings.push(g.coordinates[0]);
    else if (g.type === "MultiPolygon") g.coordinates.forEach((p) => outerRings.push(p[0]));
    else if (g.type === "GeometryCollection") g.geometries.forEach(collect);
  };
  collect(geometry);
  let best: {c: LatLng; area: number} | null = null;
  for (const ring of outerRings) {
    const rc = ringCentroid(ring);
    if (!best || rc.area > best.area) best = rc;
  }
  return best?.c ?? null;
}

type Fc = {features: {properties: Record<string, unknown>; geometry: Geometry}[]};

function indexBy(data: unknown, key: (p: Record<string, unknown>) => string | null) {
  const out = new Map<string, LatLng>();
  for (const f of (data as Fc).features) {
    const id = key(f.properties);
    const c = id ? geometryCentroid(f.geometry) : null;
    if (id && c) out.set(id, c);
  }
  return out;
}

// Built lazily, once per function instance.
let cache: {
  bbmp: Map<string, LatLng>;
  gba: Map<string, LatLng>;
  taluk: Map<string, LatLng>;
  district: Map<string, LatLng>;
} | null = null;

function centroids() {
  cache ??= {
    bbmp: indexBy(bbmpWardsData, (p) => (p.ward_no != null ? bbmpWardDocId(p.ward_no as number) : null)),
    gba: indexBy(gbaWardsData, (p) =>
      p.corporation && p.ward_id ? wardDocId(String(p.corporation), String(p.ward_id)) : null),
    taluk: indexBy(taluksData, (p) => (p.talukId ? String(p.talukId) : null)),
    district: indexBy(districtsData, (p) => (p.districtId ? String(p.districtId) : null)),
  };
  return cache;
}

/**
 * The coarse, privacy-safe location of a ticket's area — used when the
 * ticket can't be pinned more precisely (see `projectTicket`). Most
 * specific first: BBMP ward → GBA ward → taluk → district.
 */
export function areaCentroidFor(location: FirebaseFirestore.DocumentData | undefined): AreaCentroid | null {
  if (!location) return null;
  const c = centroids();
  const pick = (map: Map<string, LatLng>, id: unknown, precision: AreaPrecision) => {
    const hit = typeof id === "string" ? map.get(id) : undefined;
    return hit ? {...hit, precision} : null;
  };
  return (
    pick(c.bbmp, location.bbmpWardId, "ward") ??
    pick(c.gba, location.wardId, "ward") ??
    pick(c.taluk, location.talukId, "taluk") ??
    pick(c.district, location.districtId, "district")
  );
}
