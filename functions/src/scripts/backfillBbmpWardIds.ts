/**
 * One-off backfill after adding the BBMP (198-ward) layer. NOT deployed.
 *
 * New tickets get `location.bbmpWardId` from `onSubmissionCreated`; this
 * fills it in for tickets and clusters created before that, by
 * point-in-polygon against `bbmp_wards_198.json`:
 *   - `submissions/*.location.bbmpWardId`  (from the ticket's lat/lng)
 *   - `clusters/*.bbmpWardId`              (from the cluster's centroid)
 * GBA `wardId`s are left untouched. Only docs missing the field are
 * written, so it's safe to re-run. The public-projection triggers re-project
 * each rewritten doc on their own.
 *
 *   npx ts-node src/scripts/backfillBbmpWardIds.ts --dry-run
 *   npx ts-node src/scripts/backfillBbmpWardIds.ts
 */
import * as admin from "firebase-admin";
import {resolveBbmpWardForPoint} from "../lib/bbmpWardGeo";

admin.initializeApp({projectId: "code-for-community-e2cf2"});
const db = admin.firestore();
const DRY_RUN = process.argv.includes("--dry-run");

type Write = {ref: FirebaseFirestore.DocumentReference; patch: Record<string, unknown>};

async function commit(writes: Write[]): Promise<void> {
  if (DRY_RUN) return;
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const w of writes.slice(i, i + 400)) batch.update(w.ref, w.patch);
    await batch.commit();
  }
}

function resolve(p: {lat?: unknown; lng?: unknown} | undefined): string | null {
  if (typeof p?.lat !== "number" || typeof p?.lng !== "number") return null;
  return resolveBbmpWardForPoint(p.lat, p.lng)?.wardId ?? null;
}

async function main() {
  const submissions: Write[] = [];
  for (const doc of (await db.collection("submissions").get()).docs) {
    const loc = doc.data().location;
    if (loc?.bbmpWardId !== undefined) continue;
    const id = resolve(loc);
    if (id) submissions.push({ref: doc.ref, patch: {"location.bbmpWardId": id}});
  }

  const clusters: Write[] = [];
  for (const doc of (await db.collection("clusters").get()).docs) {
    const c = doc.data();
    if (c.bbmpWardId !== undefined) continue;
    const id = resolve(c.centroid);
    if (id) clusters.push({ref: doc.ref, patch: {bbmpWardId: id}});
  }

  await commit(submissions);
  await commit(clusters);
  console.log(
    `${DRY_RUN ? "[dry run] would set" : "Set"} bbmpWardId on ` +
    `${submissions.length} submissions and ${clusters.length} clusters.`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
