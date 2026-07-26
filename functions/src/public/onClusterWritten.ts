import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {REGION} from "../config";
import {projectCluster} from "./projection";

/**
 * Maintains `publicClusters/{clusterId}` — the anonymised hotspot/aggregate
 * projection behind the public dashboard's map, leaderboard and sparklines.
 *
 * Same reasoning as the ticket projection: a separate function with an
 * independent failure domain, written-triggered so it converges as the AI
 * pipeline fills in summaries and scores, and skipping the write entirely
 * when nothing publishable changed (the agent chain's own bookkeeping
 * updates touch this document without changing anything a reader sees).
 */
export const onClusterWrittenPublicProjection = onDocumentWritten(
  {document: "clusters/{clusterId}", region: REGION},
  async (event) => {
    const clusterId = event.params.clusterId;
    const after = event.data?.after?.data();
    const db = admin.firestore();
    const publicRef = db.collection("publicClusters").doc(clusterId);

    if (!after) {
      await publicRef.delete().catch(() => undefined);
      return;
    }

    let constituencyName: string | null = null;
    if (after.constituencyId) {
      const snap = await db
        .collection("constituencies")
        .doc(after.constituencyId)
        .get();
      constituencyName = (snap.data()?.name as string | undefined) ?? null;
    }

    const projected = projectCluster(clusterId, after, constituencyName);
    if (!projected) {
      await publicRef.delete().catch(() => undefined);
      return;
    }

    const existing = await publicRef.get();
    if (
      existing.exists &&
      JSON.stringify(existing.data()) === JSON.stringify(projected)
    ) {
      return;
    }
    await publicRef.set(projected);
  },
);
