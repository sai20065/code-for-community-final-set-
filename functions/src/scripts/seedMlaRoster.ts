/**
 * One-off admin seed script — NOT deployed as a Cloud Function. Stamps the
 * sitting MLA onto every `assemblies/*` document (what the public report
 * card and the representative leaderboard read), and onto `wards/*` and
 * `taluks/*` so the map and area picker can show "who represents this
 * place" at the assembly level, alongside the MP on `constituencies/*`.
 *
 * Why a separate script rather than seeding it with the boundaries: the
 * boundary data is stable for years, while an MLA roster changes with every
 * assembly election, by-election and defection. Keeping them apart means
 * refreshing representatives never touches geometry.
 *
 * Input: `functions/src/data/ka_mla_roster.json` —
 *   {asOf, source, members: [{acNo, assemblyConstituency, reserved,
 *    mlaName, mlaParty, vacant}]}
 * Committed *with its date and source*, so anyone can audit who the card
 * names and since when. Refresh it after every by-election; a vacant seat
 * carries `mlaName: null, vacant: true` and the UI says "Seat vacant"
 * rather than naming the previous member.
 *
 * Assemblies are matched on the seat number (`acNo`, unambiguous); wards
 * on `assemblyNo` when present, else the segment name; taluks by taluk
 * name, which in most of rural Karnataka is also the segment name. Anything
 * unmatched is reported, never guessed.
 *
 * Finally writes `publicReps/karnataka`: one small, world-readable doc
 * mapping every assembly seat to its MLA, every Karnataka Lok Sabha seat to
 * its MP, and GBA ward ids to names. The public report card and the
 * leaderboard read that instead of `assemblies/*`, whose boundary polygons
 * would make every lookup a large download.
 *
 *   cd functions
 *   npx ts-node src/scripts/seedMlaRoster.ts
 */
import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

admin.initializeApp({projectId: "code-for-community-e2cf2"});
const db = admin.firestore();

interface RosterRow {
  acNo: number;
  assemblyConstituency: string;
  reserved: string | null;
  mlaName: string | null;
  mlaParty: string | null;
  vacant: boolean;
}

interface Roster {
  asOf: string;
  source: string;
  members: RosterRow[];
}

const ROSTER_PATH = path.join(__dirname, "..", "data", "ka_mla_roster.json");

function normalise(name: string): string {
  return name.trim().toLowerCase().replace(/\s*\((sc|st)\)\s*$/, "").replace(/\s+/g, " ");
}

async function main() {
  const roster = JSON.parse(fs.readFileSync(ROSTER_PATH, "utf8")) as Roster;
  const byNo = new Map(roster.members.map((m) => [m.acNo, m]));
  const byName = new Map(roster.members.map((m) => [normalise(m.assemblyConstituency), m]));
  console.log(`Loaded ${byNo.size} seats (roster as of ${roster.asOf}).`);

  let batch = db.batch();
  let ops = 0;
  const flush = async () => {
    if (ops === 0) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };
  const stamp = (row: RosterRow) => ({
    mlaName: row.mlaName,
    mlaParty: row.mlaParty,
    mlaVacant: row.vacant,
    rosterAsOf: roster.asOf,
  });

  const unmatched: string[] = [];
  let assemblies = 0;
  for (const doc of (await db.collection("assemblies").get()).docs) {
    const row = byNo.get(Number(doc.data().acNo));
    if (!row) {
      unmatched.push(`assembly:${doc.id}`);
      continue;
    }
    batch.update(doc.ref, stamp(row));
    assemblies++;
    if (++ops >= 400) await flush();
  }
  await flush();

  const mlaIndex: Record<string, {seat: string; name: string | null; vacant: boolean}> = {};
  for (const doc of (await db.collection("assemblies").select("acNo", "name").get()).docs) {
    const row = byNo.get(Number(doc.data().acNo));
    if (row) mlaIndex[doc.id] = {seat: doc.data().name ?? row.assemblyConstituency, name: row.mlaName, vacant: row.vacant};
  }
  const mpIndex: Record<string, {seat: string; name: string | null}> = {};
  const kaSeats = await db.collection("constituencies").where("state", "==", "Karnataka")
    .select("name", "mpName").get();
  for (const doc of kaSeats.docs) {
    mpIndex[doc.id] = {seat: doc.data().name ?? doc.id, name: doc.data().mpName ?? null};
  }
  const wardNames: Record<string, string> = {};

  let wards = 0;
  for (const doc of (await db.collection("wards").get()).docs) {
    const d = doc.data();
    if (typeof d.wardName === "string") wardNames[doc.id] = d.wardName;
    const row = (d.assemblyNo != null ? byNo.get(Number(d.assemblyNo)) : undefined) ??
      (d.assemblyConstituency ? byName.get(normalise(d.assemblyConstituency)) : undefined);
    if (!row) {
      if (d.assemblyConstituency) unmatched.push(`ward:${d.assemblyConstituency}`);
      continue;
    }
    batch.update(doc.ref, stamp(row));
    wards++;
    if (++ops >= 400) await flush();
  }
  await flush();

  let taluks = 0;
  for (const doc of (await db.collection("taluks").get()).docs) {
    const talukName = doc.data().talukName as string | undefined;
    const row = talukName ? byName.get(normalise(talukName)) : undefined;
    if (!row) continue; // expected for many taluks: name ≠ segment
    batch.update(doc.ref, {assemblyConstituency: row.assemblyConstituency, ...stamp(row)});
    taluks++;
    if (++ops >= 400) await flush();
  }
  await flush();

  await db.collection("publicReps").doc("karnataka").set({
    rosterAsOf: roster.asOf,
    rosterSource: roster.source,
    mla: mlaIndex,
    mp: mpIndex,
    wardNames,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Stamped ${assemblies} assemblies, ${wards} wards, ${taluks} taluks; ` +
    `publicReps/karnataka has ${Object.keys(mlaIndex).length} MLAs, ` +
    `${Object.keys(mpIndex).length} MPs, ${Object.keys(wardNames).length} ward names.`);
  if (unmatched.length) {
    console.log(`${unmatched.length} unmatched:`, [...new Set(unmatched)].slice(0, 40).join(", "));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
