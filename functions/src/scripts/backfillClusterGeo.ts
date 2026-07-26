/**
 * One-off, idempotent backfill for clusters written before the grounding
 * fields existed (`centroid`, `wardId`/`talukId`, `priorityScore`, the time
 * series). NOT deployed as a Cloud Function.
 *
 * Two defects motivated this:
 *
 * 1. The map derived hotspot markers only from ward/taluk polygon centroids,
 *    so every cluster without a resolved ward — which is all seeded ones and
 *    everything outside Bengaluru — rendered no marker despite a high
 *    priority score.
 * 2. `orderBy('priorityScore')` silently *excludes* documents missing that
 *    field, so any cluster created without it vanished from queries with no
 *    error anywhere.
 *
 * Safe to re-run: only writes fields that are missing.
 *
 *   npm run backfill:cluster-geo -- --dry-run
 *   npm run backfill:cluster-geo
 */
import * as admin from "firebase-admin";
import {resolveTalukForPoint} from "../lib/talukGeo";
import {resolveWardForPoint} from "../lib/wardGeo";
import {isoWeekKey} from "../submissions/clusterAggregates";

admin.initializeApp();
const db = admin.firestore();

const DRY_RUN = process.argv.includes("--dry-run");

/** Priority given to a cluster that has none. Mid-scale on purpose: it must
 * not be high enough to fake a hotspot, nor zero, which would bury a real
 * issue at the bottom of every ranking. */
const DEFAULT_PRIORITY_SCORE = 50;

interface Point {
  lat: number;
  lng: number;
}

/** Average of a GeoJSON ring's vertices. Not a true polygon centroid (which
 * would weight by area), but ward and taluk boundaries here are compact
 * enough that the difference is well under the ~330 m the map cares about. */
function ringCenter(geoJson: unknown): Point | null {
  const rings = extractRings(geoJson);
  if (!rings.length) return null;
  const ring = rings[0];
  let lat = 0;
  let lng = 0;
  for (const [x, y] of ring) {
    lng += x;
    lat += y;
  }
  return {lat: lat / ring.length, lng: lng / ring.length};
}

function extractRings(geoJson: unknown): Array<Array<[number, number]>> {
  if (!geoJson) return [];
  const parsed = typeof geoJson === "string" ? safeJson(geoJson) : geoJson;
  const geometry = (parsed as {geometry?: unknown})?.geometry ?? parsed;
  const g = geometry as {type?: string; coordinates?: unknown};
  if (g?.type === "Polygon") return (g.coordinates as Array<Array<[number, number]>>) ?? [];
  if (g?.type === "MultiPolygon") {
    return ((g.coordinates as Array<Array<Array<[number, number]>>>) ?? []).flat();
  }
  return [];
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

async function main(): Promise<void> {
  const snapshot = await db.collection("clusters").get();
  const stats = {
    scanned: 0,
    updated: 0,
    skipped: 0,
    bySource: {} as Record<string, number>,
  };

  for (const doc of snapshot.docs) {
    stats.scanned++;
    const cluster = doc.data();
    const patch: Record<string, unknown> = {};

    // --- centroid, in fallback order ------------------------------------
    let point: Point | null = cluster.centroid ?? null;
    let source: string | null = cluster.centroidSource ?? null;

    if (!point) {
      // 1. Mean of the cluster's own member tickets — the most faithful
      //    answer to "where is this problem", when we have it.
      const ids: string[] = cluster.sampleSubmissionIds ?? [];
      const points: Point[] = [];
      for (const id of ids.slice(0, 10)) {
        const sub = await db.collection("submissions").doc(id).get();
        const loc = sub.data()?.location;
        if (typeof loc?.lat === "number" && typeof loc?.lng === "number") {
          points.push({lat: loc.lat, lng: loc.lng});
        }
      }
      if (points.length) {
        point = {
          lat: points.reduce((a, p) => a + p.lat, 0) / points.length,
          lng: points.reduce((a, p) => a + p.lng, 0) / points.length,
        };
        source = "submissions";
      }
    }

    if (!point && cluster.boothId) {
      const booth = await db.collection("booths").doc(cluster.boothId).get();
      const b = booth.data();
      if (typeof b?.lat === "number" && typeof b?.lng === "number") {
        point = {lat: b.lat, lng: b.lng};
        source = "booth";
      }
    }

    if (!point && cluster.wardId) {
      const ward = await db.collection("wards").doc(cluster.wardId).get();
      const center = ringCenter(ward.data()?.boundaryGeoJson);
      if (center) {
        point = center;
        source = "ward";
      }
    }

    if (!point && cluster.talukId) {
      const taluk = await db.collection("taluks").doc(cluster.talukId).get();
      const center = ringCenter(taluk.data()?.boundaryGeoJson);
      if (center) {
        point = center;
        source = "taluk";
      }
    }

    if (point && !cluster.centroid) {
      patch.centroid = point;
      patch.centroidSource = source;
      patch.centroidSum = point;
      patch.centroidCount = 1;
    }

    // --- administrative units, resolved from the centroid ----------------
    if (point) {
      if (!cluster.wardId) {
        const ward = resolveWardForPoint(point.lat, point.lng);
        if (ward) patch.wardId = ward.wardId;
      }
      if (!cluster.talukId) {
        const taluk = resolveTalukForPoint(point.lat, point.lng);
        if (taluk) patch.talukId = taluk.talukId;
      }
    }

    // --- fields whose absence silently removes the doc from queries ------
    if (typeof cluster.priorityScore !== "number") {
      patch.priorityScore = DEFAULT_PRIORITY_SCORE;
    }

    // --- time series, recomputed from members where possible -------------
    if (!cluster.weeklyCounts || !cluster.firstReportedAt) {
      const ids: string[] = cluster.sampleSubmissionIds ?? [];
      const dates: Date[] = [];
      for (const id of ids.slice(0, 10)) {
        const sub = await db.collection("submissions").doc(id).get();
        const createdAt = sub.data()?.createdAt;
        if (createdAt?.toDate) dates.push(createdAt.toDate());
      }
      if (dates.length) {
        dates.sort((a, b) => a.getTime() - b.getTime());
        if (!cluster.firstReportedAt) {
          patch.firstReportedAt = admin.firestore.Timestamp.fromDate(dates[0]);
        }
        if (!cluster.lastReportedAt) {
          patch.lastReportedAt =
            admin.firestore.Timestamp.fromDate(dates[dates.length - 1]);
        }
        if (!cluster.weeklyCounts) {
          const weekly: Record<string, number> = {};
          for (const d of dates) {
            const key = isoWeekKey(d);
            weekly[key] = (weekly[key] ?? 0) + 1;
          }
          patch.weeklyCounts = weekly;
        }
      }
    }

    if (!cluster.statusCounts) {
      patch.statusCounts = {
        new: cluster.submissionCount ?? 0,
        reviewed: 0,
        inProgress: 0,
        resolved: 0,
      };
    }
    if (typeof cluster.hasSolutionCard !== "boolean") {
      patch.hasSolutionCard = false;
      patch.agentRunCount = 0;
      patch.solutionCardVersion = 0;
      patch.lastAgentRunAt = null;
    }

    if (!Object.keys(patch).length) {
      stats.skipped++;
      continue;
    }

    stats.updated++;
    if (source) stats.bySource[source] = (stats.bySource[source] ?? 0) + 1;

    if (DRY_RUN) {
      console.log(`[dry-run] ${doc.id}:`, Object.keys(patch).join(", "));
    } else {
      await doc.ref.update(patch);
    }
  }

  console.log(DRY_RUN ? "DRY RUN — nothing written" : "Backfill complete");
  console.log(JSON.stringify(stats, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
