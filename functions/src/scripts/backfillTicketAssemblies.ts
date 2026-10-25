/**
 * One-off backfill: the assembly segment (MLA scope) for tickets filed
 * before `onSubmissionCreated` resolved it. NOT deployed.
 *
 *  - `submissions/*` with a GPS point and no `location.assemblyId` get it
 *    from the same point-in-polygon lookup the trigger uses. Run
 *    `npm run backfill:public` afterwards so `publicTickets` picks it up.
 *  - Seeded trial `publicTickets` (no submission behind them) get it from
 *    their published, already-coarsened point, so their cards can name an
 *    MLA too. They are still never ranked on the leaderboard.
 *
 *   npx ts-node src/scripts/backfillTicketAssemblies.ts --dry-run
 *   npx ts-node src/scripts/backfillTicketAssemblies.ts
 */
import * as admin from "firebase-admin";
import {resolveAssemblyForPoint} from "../lib/assemblyGeo";

admin.initializeApp({projectId: "code-for-community-e2cf2"});
const db = admin.firestore();
const DRY_RUN = process.argv.includes("--dry-run");

async function main(): Promise<void> {
  let batch = db.batch();
  let ops = 0;
  const flush = async () => {
    if (ops && !DRY_RUN) await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  let subs = 0;
  for (const doc of (await db.collection("submissions").get()).docs) {
    const loc = doc.data().location ?? {};
    if (loc.assemblyId || typeof loc.lat !== "number" || typeof loc.lng !== "number") continue;
    const a = resolveAssemblyForPoint(loc.lat, loc.lng);
    if (!a) continue;
    batch.update(doc.ref, {
      "location.assemblyId": a.assemblyId,
      "location.assemblyName": a.assemblyName,
    });
    subs++;
    if (++ops >= 400) await flush();
  }
  await flush();

  let trial = 0;
  for (const doc of (await db.collection("publicTickets").where("isTrialData", "==", true).get()).docs) {
    const d = doc.data();
    if (d.assemblyId || !d.geo) continue;
    const a = resolveAssemblyForPoint(d.geo.lat, d.geo.lng);
    if (!a) continue;
    batch.update(doc.ref, {assemblyId: a.assemblyId});
    trial++;
    if (++ops >= 400) await flush();
  }
  await flush();

  console.log(`${DRY_RUN ? "[dry run] would set" : "Set"} assemblyId on ${subs} submissions ` +
    `and ${trial} trial public tickets.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
