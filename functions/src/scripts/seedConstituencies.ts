/**
 * One-off admin seed script — NOT deployed as a Cloud Function. Loads all
 * 543 real Lok Sabha constituency boundaries (DataMeet, CC-BY-SA 2.5 India,
 * see `src/data/india_pc_boundaries.json`) into the `constituencies`
 * collection, joined with a scraped 18th-Lok-Sabha MP roster (name + party)
 * keyed by constituency name.
 *
 * This is the nationwide replacement for the old approach of manually
 * seeding a handful of `booths` with `pincodesCovered` arrays — pincodes
 * and constituency boundaries don't reliably align, so routing now happens
 * via `resolveConstituencyForLocation` (point-in-polygon) instead.
 *
 * Constituency doc id = `pc_id` from the boundary dataset, EXCEPT pc_id
 * 2924 ("Bangalore North"), which keeps the pre-existing demo id
 * `blr-north` so it doesn't orphan the booths/official account already
 * seeded under that id (see `constituencyIdForPcId`).
 *
 * Run with a service account that has Firestore write access:
 *   cd functions
 *   npm install
 *   npx ts-node src/scripts/seedConstituencies.ts [path/to/mp_roster.json]
 *
 * The roster file must be a JSON array of
 * `{ state, constituencyName, mpName, party }` objects (see
 * `ls18_mp_roster.json`). If omitted, boundaries are seeded without MP
 * names/parties (mpName/party left unset) — safe to re-run later with the
 * roster to backfill those fields via a merge write.
 */
import * as admin from "firebase-admin";
import * as fs from "fs";
import {allConstituencyBoundaries, constituencyIdForPcId} from "../lib/constituencyGeo";

admin.initializeApp();
const db = admin.firestore();

interface RosterEntry {
  state: string;
  constituencyName: string;
  mpName: string;
  party: string;
}

/** Normalizes a constituency name for fuzzy matching across the boundary
 * dataset's older city names (e.g. "Bangalore") and the MP roster's
 * current-day naming (e.g. "Bengaluru") — strips case/punctuation/spacing
 * and swaps well-known renamed cities to a common form. */
function normalize(name: string): string {
  const RENAMES: Record<string, string> = {
    bangalore: "bengaluru",
    bombay: "mumbai",
    madras: "chennai",
    calcutta: "kolkata",
    trivandrum: "thiruvananthapuram",
    cochin: "kochi",
    mysore: "mysuru",
    belgaum: "belagavi",
    poona: "pune",
    baroda: "vadodara",
    gurgaon: "gurugram",
    orissa: "odisha",
    firozepur: "ferozepur",
    barrackpore: "barrackpur",
    davangere: "davanagere",
    haasan: "hassan",
    vadakara: "vatakara",
    mayiladuturai: "mayiladuthurai",
    thoothukudi: "tuticorin",
    kanyakumari: "kanniyakumari",
    chikodi: "chikkodi",
    kodarma: "koderma",
    anantapuramu: "anantapur",
  };
  let n = name.toLowerCase().replace(/[^a-z]/g, "");
  for (const [from, to] of Object.entries(RENAMES)) {
    n = n.replace(from, to);
  }
  return n;
}

async function main() {
  const rosterPath = process.argv[2];
  const roster: RosterEntry[] = rosterPath
    ? JSON.parse(fs.readFileSync(rosterPath, "utf-8"))
    : [];
  const rosterByKey = new Map<string, RosterEntry>();
  for (const entry of roster) {
    rosterByKey.set(`${normalize(entry.state)}|${normalize(entry.constituencyName)}`, entry);
  }

  const boundaries = allConstituencyBoundaries();
  let matched = 0;
  const unmatched: string[] = [];

  for (const feature of boundaries) {
    const {pc_id: pcId, pc_name: pcName, st_name: stName} = feature.properties;
    const id = constituencyIdForPcId(pcId);
    const key = `${normalize(stName)}|${normalize(pcName)}`;
    const rosterEntry = rosterByKey.get(key);
    if (rosterEntry) matched++;
    else if (roster.length) unmatched.push(`${pcName} (${stName})`);

    // Firestore rejects arrays directly nested in arrays, which is exactly
    // what GeoJSON coordinate rings are — stored as a JSON string instead.
    // (Not a functional problem: the actual point-in-polygon lookup reads
    // the bundled `india_pc_boundaries.json`, not this Firestore field.)
    const data: Record<string, unknown> = {
      name: pcName,
      state: stName,
      boundaryGeoJson: JSON.stringify(feature.geometry),
    };
    if (rosterEntry) {
      data.mpName = rosterEntry.mpName;
      data.party = rosterEntry.party;
    }
    await db.collection("constituencies").doc(id).set(data, {merge: true});
  }

  console.log(`Seeded ${boundaries.length} constituency boundaries.`);
  if (roster.length) {
    console.log(`Matched MP roster for ${matched}/${boundaries.length}.`);
    if (unmatched.length) {
      console.log(`Unmatched (${unmatched.length}):`, unmatched.join(", "));
    }
  } else {
    console.log("No roster file given — boundaries seeded without mpName/party.");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
