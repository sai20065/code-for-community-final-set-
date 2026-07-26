import * as admin from "firebase-admin";
import {createHash} from "crypto";

/**
 * Everything the civic-intelligence agents need to reason about a cluster,
 * maintained incrementally as tickets arrive.
 *
 * The design rule throughout: every field here must be **derivable at write
 * time in O(1)**, because this runs on every single ticket. Anything needing
 * a scan of the cluster's members belongs in a backfill script, not here.
 *
 * The second rule: **no raw identifiers**. Clusters are read by officials,
 * projected to the public dashboard, and fed to an LLM. A `userId` stored
 * here would be one denormalisation mistake away from all three.
 */

/** Persons per household, for turning a ward population into a household
 * count. India's 2011 census average is 4.9 and has been falling; 4.3 is a
 * reasonable current urban figure. It is an estimate and is labelled as one
 * everywhere it surfaces — the agents are instructed never to present these
 * as measured values. */
const PERSONS_PER_HOUSEHOLD = 4.3;

/** Not every household in a ward is affected by a ward-wide issue. Without
 * a defensible way to estimate reach, we take a conservative fraction rather
 * than claiming the whole ward — overstating impact to a department is how
 * a tool loses credibility on first contact. */
const WARD_COVERAGE_FRACTION = 0.25;

/** Cap on `weeklyCounts` keys. 26 weeks is half a year — enough to see a
 * monsoon pattern, bounded so a long-lived cluster can't grow its document
 * without limit. */
const MAX_WEEK_KEYS = 26;

/** Cap on stored reporter hashes. Above this, `uniqueReporterCount` becomes
 * a lower bound, which is fine: the agents care about "many distinct people"
 * vs "one persistent person", and 500 already answers that. */
const MAX_REPORTER_HASHES = 500;

/** June–September. Used to flag monsoon-driven clusters, which is often the
 * single most useful causal signal for drainage, waterlogging and road
 * damage in Indian cities. */
const MONSOON_MONTHS = new Set([5, 6, 7, 8]); // zero-indexed

export interface AggregateInput {
  submissionId: string;
  /** Raw uid — hashed immediately and never stored. */
  userId?: string;
  createdAt: Date;
  wardId?: string | null;
  talukId?: string | null;
  lat?: number | null;
  lng?: number | null;
  /** Ward population, when the ward is known and seeded. */
  wardPopulation?: number | null;
  /** Booth-level household estimate, used when no ward resolved. */
  boothHouseholds?: number | null;
  /** Booth coordinates, the fallback centroid when the ticket has no GPS. */
  boothLat?: number | null;
  boothLng?: number | null;
}

/** ISO-8601 week key, e.g. "2026-W30". Firestore map keys can't contain
 * "/", and a sortable string key keeps the sparkline trivial to build. */
export function isoWeekKey(date: Date): string {
  const d = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  // Thursday of the current week determines the ISO year.
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

/** Salted digest of a uid, scoped to one cluster.
 *
 * Scoping to the cluster matters: a single global salt would let anyone with
 * read access to two clusters tell that the same (unknown) person reported
 * in both. Including the clusterId means the hashes are only ever countable
 * *within* one cluster, which is all the agents need. */
export function reporterHash(
  userId: string,
  clusterId: string,
  salt: string,
): string {
  return createHash("sha256")
    .update(`${salt}:${clusterId}:${userId}`)
    .digest("hex")
    .slice(0, 32);
}

function trimWeeks(weekly: Record<string, number>): Record<string, number> {
  const keys = Object.keys(weekly).sort();
  if (keys.length <= MAX_WEEK_KEYS) return weekly;
  const keep = keys.slice(-MAX_WEEK_KEYS);
  return Object.fromEntries(keep.map((k) => [k, weekly[k]]));
}

function estimateHouseholds(input: AggregateInput): number | null {
  if (typeof input.wardPopulation === "number" && input.wardPopulation > 0) {
    return Math.round(
      (input.wardPopulation / PERSONS_PER_HOUSEHOLD) * WARD_COVERAGE_FRACTION,
    );
  }
  if (typeof input.boothHouseholds === "number" && input.boothHouseholds > 0) {
    return input.boothHouseholds;
  }
  // Deliberately null rather than a guess. The Solution agent is instructed
  // to say "unknown" rather than invent a number, and it can only honour
  // that if we don't hand it a fabricated one.
  return null;
}

/**
 * Builds the field patch for a cluster gaining one more ticket.
 *
 * Pure apart from the timestamp conversion, so it can be reasoned about (and
 * tested) without Firestore. [existing] is the cluster's current data, or an
 * empty object when the cluster is being created.
 */
export function buildClusterAggregatePatch(args: {
  clusterId: string;
  existing: FirebaseFirestore.DocumentData;
  input: AggregateInput;
  salt: string;
}): Record<string, unknown> {
  const {clusterId, existing, input, salt} = args;

  const submissionCount = (existing.submissionCount ?? 0) + 1;

  // --- reporter diversity -------------------------------------------------
  const hashes: string[] = Array.isArray(existing.reporterHashes) ?
    [...existing.reporterHashes] :
    [];
  if (input.userId) {
    const h = reporterHash(input.userId, clusterId, salt);
    if (!hashes.includes(h) && hashes.length < MAX_REPORTER_HASHES) {
      hashes.push(h);
    }
  }
  const uniqueReporterCount = Math.max(hashes.length, 1);

  // --- geo: O(1) running mean --------------------------------------------
  const lat = typeof input.lat === "number" ? input.lat : input.boothLat;
  const lng = typeof input.lng === "number" ? input.lng : input.boothLng;
  const hasPoint = typeof lat === "number" && typeof lng === "number";

  const prevSum = existing.centroidSum ?? {lat: 0, lng: 0};
  const prevCount = existing.centroidCount ?? 0;
  const centroidSum = hasPoint ?
    {lat: prevSum.lat + lat, lng: prevSum.lng + lng} :
    prevSum;
  const centroidCount = hasPoint ? prevCount + 1 : prevCount;
  const centroid = centroidCount > 0 ?
    {lat: centroidSum.lat / centroidCount, lng: centroidSum.lng / centroidCount} :
    (existing.centroid ?? null);
  const centroidSource = centroidCount > 0 ?
    (typeof input.lat === "number" ? "submissions" : "booth") :
    (existing.centroidSource ?? null);

  // --- time series --------------------------------------------------------
  const createdAt = input.createdAt;
  const weekly: Record<string, number> = {...(existing.weeklyCounts ?? {})};
  const week = isoWeekKey(createdAt);
  weekly[week] = (weekly[week] ?? 0) + 1;

  const isMonsoon = MONSOON_MONTHS.has(createdAt.getMonth());
  const monsoonReportCount = (existing.monsoonReportCount ?? 0) + (isMonsoon ? 1 : 0);

  const existingFirst: admin.firestore.Timestamp | undefined = existing.firstReportedAt;
  const firstReportedAt =
    existingFirst && existingFirst.toDate() <= createdAt ?
      existingFirst :
      admin.firestore.Timestamp.fromDate(createdAt);

  return {
    submissionCount,

    wardId: input.wardId ?? existing.wardId ?? null,
    talukId: input.talukId ?? existing.talukId ?? null,

    centroidSum,
    centroidCount,
    centroid,
    centroidSource,

    firstReportedAt,
    lastReportedAt: admin.firestore.Timestamp.fromDate(createdAt),
    weeklyCounts: trimWeeks(weekly),
    monsoonReportCount,
    monsoonShare: monsoonReportCount / submissionCount,

    reporterHashes: hashes,
    uniqueReporterCount,
    repeatReporterCount: Math.max(submissionCount - uniqueReporterCount, 0),

    estimatedAffectedHouseholds: estimateHouseholds(input),
    estimatedAffectedPeople: (() => {
      const households = estimateHouseholds(input);
      return households === null ?
        null :
        Math.round(households * PERSONS_PER_HOUSEHOLD);
    })(),
  };
}

/** Zero-valued status rollup, set when a cluster is created. Maintained
 * thereafter by the public-projection trigger, which is the only place that
 * observes a ticket's status *changing*. */
export function emptyStatusCounts(): Record<string, number> {
  return {new: 0, reviewed: 0, inProgress: 0, resolved: 0};
}
