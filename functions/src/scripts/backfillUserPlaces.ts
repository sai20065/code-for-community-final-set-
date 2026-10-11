/**
 * One-off backfill for citizen profiles created before Location Setup saved
 * the constituency's *name* and the BBMP ward. NOT deployed.
 *
 * For every `users/*` doc, fills only what's missing:
 *   - `constituencyName`   from `constituencies/{constituencyId}.name`
 *   - `homeBbmpWardId/Name` from the profile's home `location`
 *   - `hasSecurityQuestion` when a `userSecrets/{uid}` doc exists
 *
 *   npx ts-node src/scripts/backfillUserPlaces.ts --dry-run
 *   npx ts-node src/scripts/backfillUserPlaces.ts
 */
import * as admin from "firebase-admin";
import {resolveBbmpWardForPoint} from "../lib/bbmpWardGeo";

admin.initializeApp({projectId: "code-for-community-e2cf2"});
const db = admin.firestore();
const DRY_RUN = process.argv.includes("--dry-run");

async function main() {
  const names = new Map<string, string | null>();
  const constituencyName = async (id: string): Promise<string | null> => {
    if (!names.has(id)) {
      const doc = await db.collection("constituencies").doc(id).get();
      names.set(id, (doc.data()?.name as string | undefined) ?? null);
    }
    return names.get(id) ?? null;
  };

  let updated = 0;
  for (const doc of (await db.collection("users").get()).docs) {
    const u = doc.data();
    if (u.role === "official") continue;
    const patch: Record<string, unknown> = {};

    if (typeof u.constituencyId === "string" && !u.constituencyName) {
      const name = await constituencyName(u.constituencyId);
      if (name) patch.constituencyName = name;
    }
    const loc = u.location;
    if (!u.homeBbmpWardId && typeof loc?.lat === "number" && typeof loc?.lng === "number") {
      const ward = resolveBbmpWardForPoint(loc.lat, loc.lng);
      if (ward) {
        patch.homeBbmpWardId = ward.wardId;
        patch.homeBbmpWardName = ward.wardName;
      }
    }
    if (u.hasSecurityQuestion !== true) {
      const secret = await db.collection("userSecrets").doc(doc.id).get();
      if (secret.exists) patch.hasSecurityQuestion = true;
    }

    if (Object.keys(patch).length) {
      updated++;
      console.log(doc.id, JSON.stringify(patch));
      if (!DRY_RUN) await doc.ref.update(patch);
    }
  }
  console.log(`${DRY_RUN ? "[dry run] would update" : "Updated"} ${updated} profiles.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
