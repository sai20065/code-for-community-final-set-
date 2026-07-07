/**
 * One-off admin seed script — NOT deployed as a Cloud Function. Loads all
 * 369 Greater Bengaluru Authority (GBA) ward boundaries (final delimitation,
 * notified 19 Nov 2025 — see `src/data/gba_wards.json`, sourced from
 * OpenCity/Oorvani Foundation) into a new `wards` collection.
 *
 * Each ward is tagged with its parent Lok Sabha constituencyId by resolving
 * its centroid against the already-deployed `resolveConstituencyForPoint`
 * (the same point-in-polygon logic `resolveConstituencyForLocation` uses
 * for citizen routing) — no separate ward->PC crosswalk data needed. The
 * source data's own `assembly_constituency` field is kept alongside as a
 * free cross-check/display value, one level down (Assembly, not
 * Parliamentary) from what's used for routing.
 *
 * Run with a service account that has Firestore write access:
 *   cd functions
 *   npm install
 *   npx ts-node src/scripts/seedWards.ts
 */
import * as admin from "firebase-admin";
import wardsData from "../data/gba_wards.json";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";

admin.initializeApp();
const db = admin.firestore();

interface WardProperties {
  ward_id: string;
  ward_name: string;
  corporation: string;
  assembly_constituency: string;
  assembly_no: string;
  zone_name: string;
  total_population: number;
  sc_population: number;
  st_population: number;
}

type Ring = number[][];
type AnyGeometry =
  | {type: "Polygon"; coordinates: Ring[]}
  | {type: "GeometryCollection"; geometries: {type: "Polygon"; coordinates: Ring[]}[]};

/** Average-of-vertices centroid — good enough to pick which (much larger)
 * parliamentary constituency a small ward falls inside; not a true
 * area centroid. */
function centroidOf(geometry: AnyGeometry): [number, number] {
  const points: number[][] = [];
  const collect = (rings: Ring[]) => rings.forEach((ring) => points.push(...ring));
  if (geometry.type === "Polygon") {
    collect(geometry.coordinates);
  } else {
    geometry.geometries.forEach((g) => collect(g.coordinates));
  }
  const lng = points.reduce((sum, p) => sum + p[0], 0) / points.length;
  const lat = points.reduce((sum, p) => sum + p[1], 0) / points.length;
  return [lng, lat];
}

async function main() {
  const features = (wardsData as {
    features: {properties: WardProperties; geometry: AnyGeometry}[];
  }).features;

  let resolved = 0;
  const unresolved: string[] = [];

  for (const feature of features) {
    const p = feature.properties;
    const [lng, lat] = centroidOf(feature.geometry);
    const match = resolveConstituencyForPoint(lat, lng);
    if (match) resolved++;
    else unresolved.push(p.ward_name);

    // ward_id is only unique *within* a corporation (1..N repeats per
    // corporation), not citywide — combine with corporation for a globally
    // unique doc id.
    const wardDocId = `${p.corporation}-${p.ward_id}`;
    await db.collection("wards").doc(wardDocId).set({
      wardName: p.ward_name,
      corporation: p.corporation,
      assemblyConstituency: p.assembly_constituency,
      assemblyNo: p.assembly_no,
      zoneName: p.zone_name,
      totalPopulation: p.total_population,
      scPopulation: p.sc_population,
      stPopulation: p.st_population,
      constituencyId: match?.constituencyId ?? null,
      boundaryGeoJson: JSON.stringify(feature.geometry),
    });
  }

  console.log(`Seeded ${features.length} wards. Resolved parent constituency for ${resolved}/${features.length}.`);
  if (unresolved.length) {
    console.log(`Unresolved (${unresolved.length}):`, unresolved.join(", "));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
