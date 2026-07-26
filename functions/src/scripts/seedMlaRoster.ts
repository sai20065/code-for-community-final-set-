/**
 * One-off admin seed script — NOT deployed as a Cloud Function. Stamps the
 * sitting MLA onto every `wards/*` and `taluks/*` document so the map and
 * area picker can show "who represents this place" at the assembly level,
 * alongside the MP already carried on `constituencies/*`.
 *
 * Why a separate script rather than seeding it with the boundaries: the
 * boundary data is stable for years, while an MLA roster changes with every
 * assembly election, by-election and defection. Keeping them apart means
 * refreshing representatives never touches geometry.
 *
 * Input: `functions/src/data/ka_mla_roster.json`, an array of
 *   {assemblyConstituency, assemblyNo, mlaName, mlaParty}
 * keyed on the assembly-segment *name*, matched case-insensitively against
 * `wards.assemblyConstituency`. That file is deliberately NOT committed —
 * supply a current roster at seed time, the same way `seedConstituencies.ts`
 * expects `ls18_mp_roster.json`. Publishing a stale roster is worse than
 * publishing none: the UI degrades to "Representative not yet recorded",
 * which is honest, whereas a wrong name is not.
 *
 * Taluks carry no assembly column in the KGIS source, so they are matched
 * by taluk name against the roster's `assemblyConstituency` — in most of
 * rural Karnataka the taluk and the assembly segment share a name. Any taluk
 * that doesn't match is left untouched and reported at the end, rather than
 * being guessed at.
 *
 * Run with a service account that has Firestore write access:
 *   cd functions
 *   npm install
 *   npx ts-node src/scripts/seedMlaRoster.ts
 */
import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

admin.initializeApp();
const db = admin.firestore();

interface RosterRow {
  assemblyConstituency: string;
  assemblyNo?: string;
  mlaName: string;
  mlaParty?: string;
}

const ROSTER_PATH = path.join(__dirname, "..", "data", "ka_mla_roster.json");

function normalise(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, " ");
}

async function main() {
  if (!fs.existsSync(ROSTER_PATH)) {
    console.error(
      `No roster at ${ROSTER_PATH}. Supply a current MLA roster before ` +
      "running this script — see the file header.",
    );
    process.exit(1);
  }
  const roster = JSON.parse(
    fs.readFileSync(ROSTER_PATH, "utf8"),
  ) as RosterRow[];
  const byName = new Map<string, RosterRow>();
  for (const row of roster) {
    byName.set(normalise(row.assemblyConstituency), row);
  }
  console.log(`Loaded ${byName.size} assembly segments.`);

  let batch = db.batch();
  let ops = 0;
  const flush = async () => {
    if (ops === 0) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  const unmatched: string[] = [];
  let matched = 0;

  const wardsSnap = await db.collection("wards").get();
  for (const doc of wardsSnap.docs) {
    const segment = doc.data().assemblyConstituency as string | undefined;
    const row = segment ? byName.get(normalise(segment)) : undefined;
    if (!row) {
      if (segment) unmatched.push(`ward:${segment}`);
      continue;
    }
    batch.update(doc.ref, {
      mlaName: row.mlaName,
      mlaParty: row.mlaParty ?? null,
    });
    matched++;
    ops++;
    if (ops >= 400) await flush();
  }
  await flush();

  const taluksSnap = await db.collection("taluks").get();
  for (const doc of taluksSnap.docs) {
    const talukName = doc.data().talukName as string | undefined;
    const row = talukName ? byName.get(normalise(talukName)) : undefined;
    if (!row) {
      if (talukName) unmatched.push(`taluk:${talukName}`);
      continue;
    }
    batch.update(doc.ref, {
      assemblyConstituency: row.assemblyConstituency,
      mlaName: row.mlaName,
      mlaParty: row.mlaParty ?? null,
    });
    matched++;
    ops++;
    if (ops >= 400) await flush();
  }
  await flush();

  console.log(`Stamped MLA details onto ${matched} ward/taluk documents.`);
  if (unmatched.length) {
    console.log(
      `${unmatched.length} left untouched (no roster match):`,
      [...new Set(unmatched)].slice(0, 40).join(", "),
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
