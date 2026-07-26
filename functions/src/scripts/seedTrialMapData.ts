/**
 * One-off admin script — NOT deployed as a Cloud Function. Fills
 * `publicClusters` and `publicTickets` with **clearly-labelled trial data**
 * spread across every taluk (and, inside Bengaluru, every GBA ward) of one
 * constituency, so the area map renders with coloured boundaries and a
 * tappable indicator on each area before real reports exist at that volume.
 *
 * Why this exists: the public map, the hotspot leaderboard and the whole
 * government dashboard read the anonymised `publicClusters`/`publicTickets`
 * projections, never `submissions`. Those projections are maintained by
 * Firestore triggers that only fire on *new* writes, so a database whose
 * clusters predate the triggers renders a completely empty map — which is
 * indistinguishable, on screen, from a broken one.
 *
 * EVERY document this writes carries `isTrialData: true`, and `--clear`
 * deletes exactly those and nothing else. Real projections written by the
 * triggers are never touched in either direction. Do not leave trial data in
 * a database anyone is reading as fact.
 *
 *   cd functions
 *   npm install
 *   npx ts-node src/scripts/seedTrialMapData.ts [constituencyId]
 *   npx ts-node src/scripts/seedTrialMapData.ts --clear
 *
 * Defaults to constituency 2927 (Chikkaballapur), which spans nine taluks
 * across three districts and so exercises the multi-district picker path.
 */
import * as admin from "firebase-admin";
import taluksData from "../data/karnataka_taluks.json";


admin.initializeApp();
const db = admin.firestore();

const DEFAULT_CONSTITUENCY = "2927";
const TRIAL_FLAG = "isTrialData";

interface AreaSeed {
  kind: "taluk" | "ward";
  id: string;
  name: string;
  lat: number;
  lng: number;
}

/** Themes the app has icons and labels for — see `kThemeLabels` in
 * lib/shared/widgets/theme_icon_chip.dart. Anything outside this list
 * renders as a grey "more" chip. */
const THEMES = [
  "roads", "water", "electricity", "health",
  "sanitation", "education", "skilling",
] as const;
type Theme = (typeof THEMES)[number];

/** Plausible civic complaints per theme. Deliberately mundane and
 * area-agnostic: trial copy that names real streets or real people reads as
 * fact the moment someone screenshots it. */
const SUMMARIES: Record<Theme, string[]> = {
  roads: [
    "Potholes across the main road are worsening after the rains; two-wheelers are being forced into oncoming traffic.",
    "The stretch near the bus stand has no streetlights and the shoulder has collapsed.",
    "Residents report the approach road has not been resurfaced in several years.",
  ],
  water: [
    "Piped supply is arriving once every three days and pressure drops sharply in the afternoon.",
    "A leaking main has been running for over a week and the road surface is eroding around it.",
    "Borewell water in this area has turned brackish and households are buying cans instead.",
  ],
  electricity: [
    "Repeated evening power cuts, typically two to three hours, reported across several streets.",
    "A transformer here has failed twice this month and load appears to exceed capacity.",
    "Street lighting along the connecting road has been out for weeks.",
  ],
  health: [
    "The primary health centre is short of staff and patients are being referred onward for routine care.",
    "No ambulance stationed locally; the nearest one takes upwards of forty minutes.",
    "Mosquito breeding around stagnant water has coincided with a rise in fever cases.",
  ],
  sanitation: [
    "Door-to-door waste collection has become irregular and waste is accumulating at the corner.",
    "An open drain near the market is blocked and overflowing onto the footpath.",
    "Public toilets at the bus stand are unusable and have no water supply.",
  ],
  education: [
    "The government school needs classroom repairs; two rooms are unusable in the monsoon.",
    "Shortage of subject teachers is affecting higher classes.",
    "No functioning drinking water or toilet facility at the school.",
  ],
  skilling: [
    "Requests for a local skill-development centre; young people are travelling to the district town for training.",
    "Existing training centre has equipment but no instructor.",
    "Demand for computer and spoken-English training for school leavers.",
  ],
};

const TITLES: Record<Theme, string> = {
  roads: "Road surface and street lighting",
  water: "Drinking water supply gaps",
  electricity: "Power reliability",
  health: "Primary healthcare access",
  sanitation: "Waste collection and drainage",
  education: "School infrastructure",
  skilling: "Skill training access",
};

const STATUSES = ["new", "reviewed", "inProgress", "resolved"] as const;

/**
 * Deterministic PRNG (mulberry32) seeded from the area id.
 *
 * Deliberately not `Math.random()`: re-running this script has to produce
 * the same map, or every run reshuffles which areas look urgent and nobody
 * can tell a data change from a reseed.
 */
function rng(seed: string): () => number {
  let h = 1779033703 ^ seed.length;
  for (let i = 0; i < seed.length; i++) {
    h = Math.imul(h ^ seed.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = h >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Mean of a geometry's vertices — not a true area centroid, just close
 * enough to plant an indicator inside the polygon, the same tradeoff
 * `seedWards.ts` makes. */
function centroidOf(geometry: {type: string; coordinates: unknown}): {lat: number; lng: number} | null {
  const points: number[][] = [];
  const walk = (node: unknown) => {
    if (!Array.isArray(node)) return;
    if (typeof node[0] === "number" && typeof node[1] === "number") {
      points.push(node as number[]);
      return;
    }
    for (const child of node) walk(child);
  };
  walk(geometry.coordinates as unknown);
  if (!points.length) return null;
  const lng = points.reduce((s, p) => s + p[0], 0) / points.length;
  const lat = points.reduce((s, p) => s + p[1], 0) / points.length;
  return {lat, lng};
}

function isoDate(daysAgo: number): string {
  const d = new Date(Date.now() - daysAgo * 86400000);
  return d.toISOString().slice(0, 10);
}

/** ISO week key, matching the `createdWeek` the real projection writes. */
function isoWeek(daysAgo: number): string {
  const d = new Date(Date.now() - daysAgo * 86400000);
  const target = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = (target.getUTCDay() + 6) % 7;
  target.setUTCDate(target.getUTCDate() - dayNum + 3);
  const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
  const week = 1 + Math.round(
    ((target.getTime() - firstThursday.getTime()) / 86400000 - 3 + ((firstThursday.getUTCDay() + 6) % 7)) / 7,
  );
  return `${target.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

/**
 * Taluks come from the boundary file (which carries `constituencyId`), but
 * wards do **not**: `gba_wards.json` has no constituency column at all —
 * `seedWards.ts` resolves it by point-in-polygon at seed time and writes it
 * to Firestore. Reading wards from the file would silently find zero of
 * them, which is exactly what the first version of this script did.
 */
async function collectAreas(constituencyId: string): Promise<AreaSeed[]> {
  const areas: AreaSeed[] = [];

  const taluks = (taluksData as {
    features: {properties: {talukId: string; talukName: string; constituencyId: string | null}; geometry: {type: string; coordinates: unknown}}[]
  }).features;
  for (const f of taluks) {
    if (f.properties.constituencyId !== constituencyId) continue;
    const c = centroidOf(f.geometry);
    if (!c) continue;
    areas.push({
      kind: "taluk",
      id: f.properties.talukId,
      name: f.properties.talukName,
      lat: c.lat,
      lng: c.lng,
    });
  }

  const wardSnap = await db.collection("wards")
    .where("constituencyId", "==", constituencyId)
    .get();
  for (const doc of wardSnap.docs) {
    const data = doc.data();
    let geometry: {type: string; coordinates: unknown} | null = null;
    try {
      geometry = JSON.parse(data.boundaryGeoJson as string);
    } catch {
      geometry = null;
    }
    const c = geometry ? centroidOf(geometry) : null;
    if (!c) continue;
    areas.push({
      kind: "ward",
      id: doc.id,
      name: (data.wardName as string) ?? doc.id,
      lat: c.lat,
      lng: c.lng,
    });
  }

  return areas;
}

async function clearTrialData() {
  let removed = 0;
  for (const collection of ["publicClusters", "publicTickets"]) {
    const snap = await db.collection(collection).where(TRIAL_FLAG, "==", true).get();
    let batch = db.batch();
    let ops = 0;
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      removed++;
      if (++ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops) await batch.commit();
  }
  console.log(`Deleted ${removed} trial documents. Real projections untouched.`);
}

async function main() {
  if (process.argv.includes("--clear")) {
    await clearTrialData();
    return;
  }

  const constituencyId = process.argv[2] ?? DEFAULT_CONSTITUENCY;
  const constituencyDoc = await db.collection("constituencies").doc(constituencyId).get();
  if (!constituencyDoc.exists) {
    console.error(`No constituencies/${constituencyId}. Seed constituencies first.`);
    process.exit(1);
  }
  const constituencyName = (constituencyDoc.data()?.name as string) ?? constituencyId;

  const areas = await collectAreas(constituencyId);
  if (!areas.length) {
    console.error(
      `No taluks or wards tagged with constituencyId ${constituencyId} in the ` +
      "boundary data — nothing to place indicators on.",
    );
    process.exit(1);
  }
  console.log(`${constituencyName}: ${areas.length} areas.`);

  let batch = db.batch();
  let ops = 0;
  const flush = async () => {
    if (!ops) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  let clusterCount = 0;
  let ticketCount = 0;

  for (const area of areas) {
    const rand = rng(area.id);
    // One or two issue groups per area, so the map has both single-pin and
    // busier areas rather than a uniform grid.
    const groupCount = 1 + Math.floor(rand() * 2);
    const used = new Set<Theme>();

    for (let g = 0; g < groupCount; g++) {
      let theme = THEMES[Math.floor(rand() * THEMES.length)];
      while (used.has(theme)) theme = THEMES[Math.floor(rand() * THEMES.length)];
      used.add(theme);

      // Spread priority across the full red/amber/green ramp so the map
      // shows all three severity colours rather than a single flat tint.
      const priorityScore = Math.round(18 + rand() * 74);
      const submissionCount = 2 + Math.floor(rand() * 38);
      const resolved = Math.floor(submissionCount * rand() * 0.45);
      const inProgress = Math.floor((submissionCount - resolved) * rand() * 0.5);
      const firstDays = 20 + Math.floor(rand() * 70);

      const weeklyCounts: Record<string, number> = {};
      for (let w = 11; w >= 0; w--) {
        weeklyCounts[isoWeek(w * 7)] = Math.floor(rand() * 6);
      }

      const clusterId = `trial-${area.id}-${theme}`;
      const summaries = SUMMARIES[theme];
      const summaryText = summaries[Math.floor(rand() * summaries.length)];

      batch.set(db.collection("publicClusters").doc(clusterId), {
        [TRIAL_FLAG]: true,
        constituencyId,
        constituencyName,
        theme,
        title: `${TITLES[theme]} — ${area.name}`,
        summaryText,
        talukId: area.kind === "taluk" ? area.id : null,
        wardId: area.kind === "ward" ? area.id : null,
        boothId: null,
        submissionCount,
        uniqueReporterCount: Math.max(1, Math.floor(submissionCount * 0.7)),
        priorityScore,
        demandScore: Math.round(20 + rand() * 78),
        demographicScore: Math.round(20 + rand() * 78),
        infraGapScore: Math.round(20 + rand() * 78),
        centroid: {lat: area.lat, lng: area.lng},
        firstReportedDate: isoDate(firstDays),
        lastReportedDate: isoDate(Math.floor(rand() * 6)),
        weeklyCounts,
        statusCounts: {
          new: submissionCount - resolved - inProgress,
          inProgress,
          resolved,
        },
        hasSolutionCard: false,
        solutionCardVersion: 0,
      });
      clusterCount++;
      if (++ops >= 300) await flush();

      // A handful of individual reports per group — enough that tapping an
      // indicator shows a real list, not so many that trial data dominates
      // the queue.
      const ticketsHere = Math.min(submissionCount, 4 + Math.floor(rand() * 3));
      for (let t = 0; t < ticketsHere; t++) {
        const daysAgo = Math.floor(rand() * firstDays);
        const status = STATUSES[Math.floor(rand() * STATUSES.length)];
        const seq = String(t + 1).padStart(4, "0");
        const ticketId = `trial-${area.id}-${theme}-${seq}`;
        batch.set(db.collection("publicTickets").doc(ticketId), {
          [TRIAL_FLAG]: true,
          tokenId: `PD-TRIAL-${theme.slice(0, 3).toUpperCase()}-${isoDate(daysAgo).replace(/-/g, "").slice(2)}-${seq}`,
          theme,
          submissionCategory: "problem",
          status,
          publicSummary: summaries[Math.floor(rand() * summaries.length)],
          constituencyId,
          constituencyName,
          talukId: area.kind === "taluk" ? area.id : null,
          wardId: area.kind === "ward" ? area.id : null,
          boothId: null,
          clusterId,
          supporterCount: Math.floor(rand() * 24),
          createdDate: isoDate(daysAgo),
          createdWeek: isoWeek(daysAgo),
          resolvedDate: status === "resolved" ? isoDate(Math.floor(daysAgo / 2)) : null,
          // Jittered a few hundred metres off the area centroid, and
          // labelled as such: a point drawn more precisely than the data
          // supports invites conclusions the data cannot carry.
          geo: {
            lat: area.lat + (rand() - 0.5) * 0.01,
            lng: area.lng + (rand() - 0.5) * 0.01,
          },
          geoPrecision: "approx-300m",
        });
        ticketCount++;
        if (++ops >= 300) await flush();
      }
    }
  }

  await flush();
  console.log(
    `Seeded ${clusterCount} trial clusters and ${ticketCount} trial reports ` +
    `across ${areas.length} areas of ${constituencyName}.`,
  );
  console.log("Remove with:  npx ts-node src/scripts/seedTrialMapData.ts --clear");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
