/**
 * Rebuilds `publicTickets` and `publicClusters` from scratch, and audits
 * what is about to become world-readable. NOT deployed as a Cloud Function.
 *
 *   npm run backfill:public -- --dry-run   # inspect first, always
 *   npm run backfill:public
 *   npm run backfill:public -- --audit     # audit existing projections only
 *
 * The `--audit` mode is the important one and should be run after every
 * change to `projection.ts`. It enumerates every distinct field key present
 * across the projections and diffs it against the reviewed allowlist, then
 * greps the values for anything identifier-shaped. Reading the projection
 * code and concluding it looks right is not the same as checking what is
 * actually in the collection — a single stray spread operator is all it
 * takes, and the failure is silent.
 */
import * as admin from "firebase-admin";
import {
  PublicClusterDoc,
  PublicTicketDoc,
  projectCluster,
  projectTicket,
} from "../public/projection";

admin.initializeApp();
const db = admin.firestore();

const DRY_RUN = process.argv.includes("--dry-run");
const AUDIT_ONLY = process.argv.includes("--audit");
const BATCH_SIZE = 400;

/** Must match `PublicTicketDoc` exactly. Kept as a literal list so that
 * adding a field to the interface without consciously adding it here fails
 * the audit — which is the point. */
const TICKET_ALLOWLIST: Array<keyof PublicTicketDoc> = [
  "tokenId", "theme", "submissionCategory", "status", "publicSummary",
  "constituencyId", "constituencyName", "wardId", "talukId", "boothId",
  "clusterId", "supporterCount", "createdDate", "createdWeek", "updatedDate",
  "resolvedDate", "geo", "geoPrecision",
];

const CLUSTER_ALLOWLIST: Array<keyof PublicClusterDoc> = [
  "clusterId", "constituencyId", "constituencyName", "theme", "boothId",
  "wardId", "talukId", "submissionCount", "uniqueReporterCount",
  "priorityScore", "demandScore", "demographicScore", "infraGapScore",
  "summaryText", "title", "affectedBoothRange", "localContext",
  "centroid", "firstReportedDate", "lastReportedDate",
  "weeklyCounts", "statusCounts", "hasSolutionCard", "solutionCardVersion",
];

/** Identifier shapes that must never appear in a public value. */
const LEAK_PATTERNS: Array<{name: string; pattern: RegExp}> = [
  {name: "6-digit run (pincode)", pattern: /\b\d{6}\b/},
  {name: "phone number", pattern: /\b(?:\+?91[-\s]?)?[6-9]\d{9}\b/},
  {name: "aadhaar-shaped", pattern: /\b\d{4}\s?\d{4}\s?\d{4}\b/},
  {name: "email address", pattern: /\S+@\S+\.\S+/},
];

async function rebuild(): Promise<void> {
  // --- tickets ------------------------------------------------------------
  const submissions = await db.collection("submissions").get();
  const clusterCounts = new Map<string, number>();
  const clusters = await db.collection("clusters").get();
  for (const doc of clusters.docs) {
    clusterCounts.set(doc.id, doc.data().submissionCount ?? 0);
  }

  let batch = db.batch();
  let pending = 0;
  let written = 0;
  let skipped = 0;
  let shown = 0;

  for (const doc of submissions.docs) {
    const data = doc.data();
    const wardId = data.location?.wardId;
    let wardCentroid: {lat: number; lng: number} | null = null;
    if (wardId) {
      const ward = await db.collection("wards").doc(wardId).get();
      const w = ward.data();
      if (typeof w?.centroidLat === "number" && typeof w?.centroidLng === "number") {
        wardCentroid = {lat: w.centroidLat, lng: w.centroidLng};
      }
    }

    const projected = projectTicket({
      submissionId: doc.id,
      submission: data,
      clusterSubmissionCount: clusterCounts.get(data.clusterId ?? "") ?? 0,
      wardCentroid,
    });

    if (!projected) {
      skipped++;
      continue;
    }

    // Print the first few in full so a human can actually look at what is
    // about to be published, rather than trusting a summary count.
    if (shown < 5) {
      shown++;
      console.log(`\n--- publicTickets/${doc.id} ---`);
      console.log(JSON.stringify(projected, null, 2));
    }

    if (!DRY_RUN) {
      batch.set(db.collection("publicTickets").doc(doc.id), projected);
      pending++;
      if (pending >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
    written++;
  }
  if (pending && !DRY_RUN) await batch.commit();

  // --- clusters -----------------------------------------------------------
  let clusterBatch = db.batch();
  let clusterPending = 0;
  let clusterWritten = 0;
  const nameCache = new Map<string, string | null>();

  for (const doc of clusters.docs) {
    const data = doc.data();
    const cid = data.constituencyId as string | undefined;
    let name: string | null = null;
    if (cid) {
      if (!nameCache.has(cid)) {
        const snap = await db.collection("constituencies").doc(cid).get();
        nameCache.set(cid, (snap.data()?.name as string | undefined) ?? null);
      }
      name = nameCache.get(cid) ?? null;
    }
    const projected = projectCluster(doc.id, data, name);
    if (!projected) continue;
    if (!DRY_RUN) {
      clusterBatch.set(db.collection("publicClusters").doc(doc.id), projected);
      clusterPending++;
      if (clusterPending >= BATCH_SIZE) {
        await clusterBatch.commit();
        clusterBatch = db.batch();
        clusterPending = 0;
      }
    }
    clusterWritten++;
  }
  if (clusterPending && !DRY_RUN) await clusterBatch.commit();

  console.log(
    `\n${DRY_RUN ? "[dry-run] would write" : "wrote"} ${written} public ` +
      `tickets (${skipped} unpublishable) and ${clusterWritten} public clusters.`,
  );
}

async function audit(): Promise<number> {
  let problems = 0;

  for (const [collection, allowlist] of [
    ["publicTickets", TICKET_ALLOWLIST as string[]],
    ["publicClusters", CLUSTER_ALLOWLIST as string[]],
  ] as const) {
    const snap = await db.collection(collection).get();
    const allowed = new Set<string>(allowlist);
    const seen = new Set<string>();

    for (const doc of snap.docs) {
      const data = doc.data();
      for (const key of Object.keys(data)) {
        seen.add(key);
        if (!allowed.has(key)) {
          problems++;
          console.error(
            `LEAK  ${collection}/${doc.id} has un-allowlisted field "${key}"`,
          );
        }
      }
      // Value-level check. The allowlist catches a field that shouldn't be
      // there; this catches an allowed field carrying something it
      // shouldn't — a `publicSummary` the model wrote a phone number into.
      for (const [key, value] of Object.entries(data)) {
        if (typeof value !== "string") continue;
        for (const {name, pattern} of LEAK_PATTERNS) {
          if (pattern.test(value)) {
            problems++;
            console.error(
              `LEAK  ${collection}/${doc.id}.${key} contains a ${name}: ` +
                `"${value.slice(0, 120)}"`,
            );
          }
        }
      }
    }

    const missing = allowlist.filter((k) => !seen.has(k));
    console.log(
      `${collection}: ${snap.size} docs, ${seen.size} distinct fields` +
        (missing.length ? `, never populated: ${missing.join(", ")}` : ""),
    );
  }

  console.log(
    problems === 0 ?
      "\nAudit clean — every published field is on the allowlist." :
      `\nAudit FAILED with ${problems} problem(s).`,
  );
  return problems;
}

async function main(): Promise<void> {
  if (!AUDIT_ONLY) await rebuild();
  if (!DRY_RUN) {
    const problems = await audit();
    if (problems) process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
