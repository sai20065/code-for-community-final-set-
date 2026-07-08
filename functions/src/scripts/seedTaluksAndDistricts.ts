/**
 * One-off admin seed script — NOT deployed as a Cloud Function. Loads
 * Karnataka's 227 taluks and 30 districts (official KSRSAC/KGIS data,
 * https://github.com/samashti/KGIS) into new `taluks` and `districts`
 * Firestore collections.
 *
 * Taluks are the "ward-equivalent" fine-grained map/routing unit for every
 * Karnataka constituency outside Bengaluru Urban (which uses the 369 GBA
 * wards instead — see `seedWards.ts`). Each taluk is already tagged with its
 * parent constituencyId (resolved via point-in-polygon against the precise
 * KGIS PC boundaries — see `updateConstituencyBoundariesKGIS.ts`) and its
 * districtId/districtName (read directly from the source data's own
 * district-code column, no separate join needed).
 *
 * Districts are a coarser reference layer only — a district's boundary can
 * span multiple constituencies, so it is not itself used for MP routing.
 *
 * Source rows for both taluks and districts are fragmented (a district or
 * taluk with disjoint/enclave parts — common in Karnataka's Western Ghats
 * districts like Uttara Kannada — appears as several separate GeoPackage
 * rows sharing the same code). Fragments were already dissolved into one
 * MultiPolygon feature per real taluk/district before being written to
 * `functions/src/data/karnataka_taluks.json` / `karnataka_districts.json`
 * (see the one-off conversion notes in that data-prep session).
 *
 * Run with a service account that has Firestore write access:
 *   cd functions
 *   npm install
 *   npx ts-node src/scripts/seedTaluksAndDistricts.ts
 */
import * as admin from "firebase-admin";
import taluksData from "../data/karnataka_taluks.json";
import districtsData from "../data/karnataka_districts.json";

admin.initializeApp();
const db = admin.firestore();

interface TalukProperties {
  talukId: string;
  talukName: string;
  districtId: string;
  districtName: string;
  constituencyId: string | null;
}

interface DistrictProperties {
  districtId: string;
  name: string;
}

async function main() {
  const taluks = (taluksData as {features: {properties: TalukProperties; geometry: object}[]}).features;
  const districts = (districtsData as {features: {properties: DistrictProperties; geometry: object}[]}).features;

  let batch = db.batch();
  let ops = 0;
  const flush = async () => {
    if (ops === 0) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  for (const f of taluks) {
    const p = f.properties;
    batch.set(db.collection("taluks").doc(p.talukId), {
      talukId: p.talukId,
      talukName: p.talukName,
      districtId: p.districtId,
      districtName: p.districtName,
      constituencyId: p.constituencyId,
      boundaryGeoJson: JSON.stringify(f.geometry),
    });
    ops++;
    if (ops >= 400) await flush();
  }
  await flush();
  console.log(`Seeded ${taluks.length} taluks.`);

  for (const f of districts) {
    const p = f.properties;
    batch.set(db.collection("districts").doc(p.districtId), {
      districtId: p.districtId,
      name: p.name,
      boundaryGeoJson: JSON.stringify(f.geometry),
    });
    ops++;
    if (ops >= 400) await flush();
  }
  await flush();
  console.log(`Seeded ${districts.length} districts.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
