/**
 * One-off admin seed — NOT deployed. Loads Karnataka's 224 assembly
 * constituencies from `src/data/karnataka_assembly.json` into
 * `assemblies/KA-AC-<n>` (name, number, parent Lok Sabha constituencyId,
 * boundary). Used by the official-registration picker (MLAs choose their
 * seat) and to draw an MLA's area on the map. Upserts; safe to re-run.
 *
 *   npx ts-node src/scripts/seedAssemblies.ts
 */
import * as admin from "firebase-admin";
import {ASSEMBLY_FEATURES, assemblyDocId} from "../lib/assemblyGeo";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";

admin.initializeApp({projectId: "code-for-community-e2cf2"});
const db = admin.firestore();

async function main() {
  let batch = db.batch();
  let pending = 0;
  let resolved = 0;
  for (const f of ASSEMBLY_FEATURES) {
    const polys = f.geometry.type === "Polygon" ?
      [f.geometry.coordinates] :
      f.geometry.coordinates;
    const pts = polys.flat(2);
    const lng = pts.reduce((s, p) => s + p[0], 0) / pts.length;
    const lat = pts.reduce((s, p) => s + p[1], 0) / pts.length;
    const pc = resolveConstituencyForPoint(lat, lng);
    if (pc) resolved++;
    batch.set(db.collection("assemblies").doc(assemblyDocId(f.properties.ac_no)), {
      acNo: f.properties.ac_no,
      name: f.properties.ac_name,
      districtName: f.properties.district,
      constituencyId: pc?.constituencyId ?? null,
      constituencyName: pc?.constituencyName ?? null,
      centroid: {lat, lng},
      boundaryGeoJson: JSON.stringify(f.geometry),
    });
    if (++pending === 100) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending) await batch.commit();
  console.log(`Seeded ${ASSEMBLY_FEATURES.length} assemblies; parent Lok Sabha resolved for ${resolved}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
