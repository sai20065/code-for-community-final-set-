/**
 * One-off backfill for citizen profiles created before Location Setup saved
 * the constituency's *name* and the BBMP ward. NOT deployed.
 *
 * For every `users/*` doc, fills only what's missing:
 *   - `constituencyName`   from `constituencies/{constituencyId}.name`
 *   - from the profile's home `location` (the same point-in-polygon lookups
 *     as `resolveConstituencyForLocation`): `constituencyId/Name`,
 *     `districtId/Name`, `talukId/Name`, `homeWardId/Name` (GBA),
 *     `homeBbmpWardId/Name` and `assemblyId/Name`
 *   - `hasSecurityQuestion` when a `userSecrets/{uid}` doc exists
 *
 * Profiles with no saved location can't be fixed here — those citizens are
 * routed back into onboarding by the app the next time they open it.
 *
 *   npx ts-node src/scripts/backfillUserPlaces.ts --dry-run
 *   npx ts-node src/scripts/backfillUserPlaces.ts
 */
import * as admin from "firebase-admin";
import {resolveAssemblyForPoint} from "../lib/assemblyGeo";
import {resolveBbmpWardForPoint} from "../lib/bbmpWardGeo";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";
import {resolveTalukForPoint} from "../lib/talukGeo";
import {resolveWardForPoint} from "../lib/wardGeo";

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

    const loc = u.location;
    if (typeof loc?.lat === "number" && typeof loc?.lng === "number") {
      const setIfMissing = (key: string, value: unknown) => {
        if (value != null && (u[key] == null || u[key] === "")) patch[key] = value;
      };
      const c = resolveConstituencyForPoint(loc.lat, loc.lng);
      setIfMissing("constituencyId", c?.constituencyId);
      setIfMissing("constituencyName", c?.constituencyName);
      const t = resolveTalukForPoint(loc.lat, loc.lng);
      setIfMissing("districtId", t?.districtId);
      setIfMissing("districtName", t?.districtName);
      setIfMissing("talukId", t?.talukId);
      setIfMissing("talukName", t?.talukName);
      const w = resolveWardForPoint(loc.lat, loc.lng);
      setIfMissing("homeWardId", w?.wardId);
      setIfMissing("homeWardName", w?.wardName);
      const b = resolveBbmpWardForPoint(loc.lat, loc.lng);
      setIfMissing("homeBbmpWardId", b?.wardId);
      setIfMissing("homeBbmpWardName", b?.wardName);
      const a = resolveAssemblyForPoint(loc.lat, loc.lng);
      setIfMissing("assemblyId", a?.assemblyId);
      setIfMissing("assemblyName", a?.assemblyName);
    }
    const cid = (patch.constituencyId ?? u.constituencyId) as string | undefined;
    if (typeof cid === "string" && !u.constituencyName && !patch.constituencyName) {
      const name = await constituencyName(cid);
      if (name) patch.constituencyName = name;
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
