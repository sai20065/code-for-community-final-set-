import * as admin from "firebase-admin";
import type {Scope} from "../officials/scope";

export interface AreaCluster {
  id: string;
  theme: string;
  summaryText: string;
  priorityScore?: number;
  demandScore?: number;
  demographicScore?: number;
  infraGapScore?: number;
  submissionCount?: number;
  weeklyCounts?: Record<string, number>;
}

export interface AreaData {
  clusters: AreaCluster[]; // highest priority first
  submissions: FirebaseFirestore.DocumentData[];
  stats: {
    total: number;
    open: number;
    inProgress: number;
    resolved: number;
    urgent: number;
    newThisWeek: number;
  };
}

/** priorityScore at/above which a cluster counts as urgent (0–100 scale). */
export const URGENT_THRESHOLD = 70;

/**
 * Everything a briefing or report about one official's area needs: its
 * clusters (sorted in code, so no composite index per scope field is
 * required) and its tickets. `scope.field === null` = the whole state.
 * Reads the private collections with the Admin SDK — only aggregate
 * counts and AI cluster summaries ever leave this function, never a
 * citizen's own words or identity.
 */
export async function loadAreaData(scope: Scope): Promise<AreaData> {
  const db = admin.firestore();
  let clustersQ: FirebaseFirestore.Query = db.collection("clusters");
  let subsQ: FirebaseFirestore.Query = db.collection("submissions");
  if (scope.field && scope.id) {
    clustersQ = clustersQ.where(scope.field, "==", scope.id);
    subsQ = subsQ.where(`location.${scope.field}`, "==", scope.id);
  } else {
    clustersQ = clustersQ.limit(2000);
    subsQ = subsQ.limit(5000);
  }
  const [clustersSnap, subsSnap] = await Promise.all([clustersQ.get(), subsQ.get()]);

  const clusters = clustersSnap.docs
    .map((d) => ({...(d.data() as Omit<AreaCluster, "id">), id: d.id}))
    .sort((a, b) => (b.priorityScore ?? 0) - (a.priorityScore ?? 0));
  const submissions = subsSnap.docs.map((d) => d.data());

  const weekAgo = Date.now() - 7 * 24 * 3600 * 1000;
  const count = (status: string) => submissions.filter((s) => s.status === status).length;
  return {
    clusters,
    submissions,
    stats: {
      total: submissions.length,
      open: count("new") + count("reviewed"),
      inProgress: count("inProgress"),
      resolved: count("resolved"),
      urgent: clusters.filter((c) => (c.priorityScore ?? 0) >= URGENT_THRESHOLD).length,
      newThisWeek: submissions.filter((s) => {
        const t = s.createdAt?.toDate?.() as Date | undefined;
        return t && t.getTime() >= weekAgo;
      }).length,
    },
  };
}
