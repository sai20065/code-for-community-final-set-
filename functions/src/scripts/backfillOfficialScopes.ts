/**
 * One-off backfill for the MP / MLA / officer scopes. NOT deployed.
 *   - submissions: location.assemblyId / assemblyName / districtId
 *   - clusters:    assemblyId / districtId (from centroid)
 *   - users:       existing MP accounts get officialType 'mp' + jurisdiction
 * Only fills what's missing; safe to re-run. The public-projection triggers
 * re-project rewritten submissions/clusters on their own.
 *
 *   npx ts-node src/scripts/backfillOfficialScopes.ts --dry-run
 *   npx ts-node src/scripts/backfillOfficialScopes.ts
 */
import * as admin from "firebase-admin";
import {resolveAssemblyForPoint} from "../lib/assemblyGeo";
import {resolveTalukForPoint} from "../lib/talukGeo";

admin.initializeApp({projectId: "code-for-community-e2cf2"});
const db = admin.firestore();
const DRY_RUN = process.argv.includes("--dry-run");

type P = {lat?: unknown; lng?: unknown} | undefined;
const ok = (p: P): p is {lat: number; lng: number; [k: string]: unknown} =>
  typeof p?.lat === "number" && typeof p?.lng === "number";

async function main() {
  let subs = 0;
  for (const d of (await db.collection("submissions").get()).docs) {
    const loc = d.data().location;
    if (!ok(loc) || (loc.assemblyId !== undefined && loc.districtId !== undefined)) continue;
    const a = resolveAssemblyForPoint(loc.lat, loc.lng);
    const t = resolveTalukForPoint(loc.lat, loc.lng);
    const patch: Record<string, unknown> = {
      "location.assemblyId": a?.assemblyId ?? null,
      "location.assemblyName": a?.assemblyName ?? null,
      "location.districtId": t?.districtId ?? null,
    };
    subs++;
    if (!DRY_RUN) await d.ref.update(patch);
  }

  let clusters = 0;
  for (const d of (await db.collection("clusters").get()).docs) {
    const c = d.data();
    if (!ok(c.centroid) || (c.assemblyId !== undefined && c.districtId !== undefined)) continue;
    const a = resolveAssemblyForPoint(c.centroid.lat, c.centroid.lng);
    const t = resolveTalukForPoint(c.centroid.lat, c.centroid.lng);
    clusters++;
    if (!DRY_RUN) {
      await d.ref.update({assemblyId: a?.assemblyId ?? null, districtId: t?.districtId ?? null});
    }
  }

  let mps = 0;
  const officials = await db.collection("users").where("role", "==", "official").get();
  for (const d of officials.docs) {
    const u = d.data();
    if (u.officialType || !u.constituencyId) continue;
    const name = (await db.collection("constituencies").doc(u.constituencyId).get()).data()?.name;
    mps++;
    if (!DRY_RUN) {
      await d.ref.update({
        officialType: "mp",
        jurisdiction: {type: "constituency", id: u.constituencyId, name: name ?? u.constituencyId},
      });
    }
  }
  console.log(`${DRY_RUN ? "[dry run] would update" : "Updated"}: ` +
    `${subs} submissions, ${clusters} clusters, ${mps} MP accounts.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
