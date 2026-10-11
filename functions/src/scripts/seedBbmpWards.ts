/**
 * One-off admin seed script — NOT deployed as a Cloud Function. Loads the
 * 198 BBMP ward boundaries (2010 delimitation, the wards shown on BBMP's
 * "Zones and Wards" map) from `src/data/bbmp_wards_198.json` into the
 * `wards` collection as `wards/BBMP-<wardNo>`, next to (not instead of)
 * the 369 GBA wards that `seedWards.ts` loads.
 *
 * Source: DataMeet `Municipal_Spatial_Data/Bangalore/BBMP_oldWards.geojson`,
 * CC BY-SA 2.5 India — attribution is shown on every map screen.
 *
 * Each ward is tagged with its parent Lok Sabha constituencyId by resolving
 * its centroid with `resolveConstituencyForPoint` (the same point-in-polygon
 * logic citizen routing uses). The ward's assembly constituency comes from
 * the source data and doubles as its `zoneName` — the area picker groups
 * wards by it.
 *
 * Upserts by default. Pass `--replace` to first delete the existing BBMP
 * ward docs (GBA ward docs are never deleted).
 *
 * Run with credentials that have Firestore write access:
 *   cd functions
 *   npx ts-node src/scripts/seedBbmpWards.ts
 */
import * as admin from "firebase-admin";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";
import {
  WARD_CORPORATION,
  WARD_FEATURES,
  WardGeometry,
  bbmpWardDocId,
} from "../lib/bbmpWardGeo";

admin.initializeApp({projectId: "code-for-community-e2cf2"});
const db = admin.firestore();

/** Average of every vertex — good enough to pick which (much larger)
 * parliamentary constituency a ward falls inside. */
function centroidOf(geometry: WardGeometry): [number, number] {
  const polygons = geometry.type === "Polygon" ?
    [geometry.coordinates] :
    geometry.coordinates;
  const points = polygons.flat(2);
  const lng = points.reduce((sum, p) => sum + p[0], 0) / points.length;
  const lat = points.reduce((sum, p) => sum + p[1], 0) / points.length;
  return [lng, lat];
}

/** Deletes only BBMP ward docs — the 369 GBA wards (Central-*, East-*, …)
 * are a separate layer and are never touched by this script. */
async function deleteBbmpWards(): Promise<number> {
  let deleted = 0;
  for (;;) {
    const snap = await db.collection("wards")
      .where("corporation", "==", WARD_CORPORATION).limit(400).get();
    if (snap.empty) return deleted;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    deleted += snap.size;
  }
}

async function main() {
  if (process.argv.includes("--replace")) {
    console.log(`Deleted ${await deleteBbmpWards()} existing BBMP ward docs.`);
  }

  let resolved = 0;
  const unresolved: string[] = [];
  let batch = db.batch();
  let pending = 0;

  for (const f of WARD_FEATURES) {
    const p = f.properties;
    const [cLng, cLat] = centroidOf(f.geometry);
    const lat = p.lat ?? cLat;
    const lng = p.lng ?? cLng;
    const match = resolveConstituencyForPoint(lat, lng);
    if (match) resolved++;
    else unresolved.push(`${p.ward_no} ${p.ward_name}`);

    batch.set(db.collection("wards").doc(bbmpWardDocId(p.ward_no)), {
      wardNo: p.ward_no,
      wardName: p.ward_name,
      corporation: WARD_CORPORATION,
      assemblyConstituency: p.assembly_constituency,
      assemblyNo: p.assembly_no,
      zoneName: p.assembly_constituency,
      totalPopulation: p.total_population,
      scPopulation: p.sc_population,
      stPopulation: p.st_population,
      centroid: {lat, lng},
      constituencyId: match?.constituencyId ?? null,
      boundaryGeoJson: JSON.stringify(f.geometry),
    });
    // Each doc carries its boundary (~4 KB avg), so keep batches well under
    // Firestore's 10 MB request ceiling.
    if (++pending === 100) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending) await batch.commit();

  console.log(
    `Seeded ${WARD_FEATURES.length} BBMP wards. ` +
    `Resolved parent constituency for ${resolved}/${WARD_FEATURES.length}.`,
  );
  if (unresolved.length) {
    console.log(`Unresolved (${unresolved.length}):`, unresolved.join(", "));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
