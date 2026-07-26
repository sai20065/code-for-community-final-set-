import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {AGENT_LOCK_MINUTES, REGION} from "../config";
import {runAgentChain} from "./orchestrator";

interface Request {
  clusterId: string;
}

/**
 * Manual regeneration of a cluster's Solution Card.
 *
 * Officials only, and only for their own constituency — the same trust
 * boundary as `generateConstituencyReport`. Bypasses the automatic
 * cooldown (that exists to control cost, and a human asking for a rerun is
 * a deliberate decision) but still honours the concurrency lock, because
 * two simultaneous chains racing on one card is a correctness problem
 * rather than a cost one.
 */
export const runClusterAgents = onCall(
  {region: REGION, timeoutSeconds: 300, memory: "512MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const {clusterId} = (request.data ?? {}) as Request;
    if (!clusterId) {
      throw new HttpsError("invalid-argument", "clusterId is required.");
    }

    const db = admin.firestore();
    const [userSnap, clusterSnap] = await Promise.all([
      db.collection("users").doc(request.auth.uid).get(),
      db.collection("clusters").doc(clusterId).get(),
    ]);

    const user = userSnap.data();
    if (user?.role !== "official") {
      throw new HttpsError(
        "permission-denied",
        "Only officials can regenerate an analysis.",
      );
    }
    if (!clusterSnap.exists) {
      throw new HttpsError("not-found", "Cluster not found.");
    }
    if (clusterSnap.data()?.constituencyId !== user.constituencyId) {
      throw new HttpsError(
        "permission-denied",
        "That cluster is outside your constituency.",
      );
    }

    const clusterRef = clusterSnap.ref;
    const acquired = await db.runTransaction(async (tx) => {
      const snap = await tx.get(clusterRef);
      const lock = snap.data()?.agentRunLockAt as
        | admin.firestore.Timestamp
        | undefined;
      if (lock) {
        const minutesHeld = (Date.now() - lock.toDate().getTime()) / 60_000;
        if (minutesHeld < AGENT_LOCK_MINUTES) return false;
      }
      tx.update(clusterRef, {
        agentRunLockAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!acquired) {
      throw new HttpsError(
        "already-exists",
        "An analysis is already running for this issue — try again shortly.",
      );
    }

    try {
      const result = await runAgentChain(db, clusterId, "manual");
      if (!result) throw new HttpsError("not-found", "Cluster not found.");
      return {
        version: result.card.version,
        degraded: result.card.degraded,
        failedAgents: result.card.failedAgents,
        headline: result.card.headline,
      };
    } catch (err) {
      await clusterRef.update({agentRunLockAt: null});
      if (err instanceof HttpsError) throw err;
      console.error("Manual agent run failed", err);
      throw new HttpsError("internal", "The analysis could not be completed.");
    }
  },
);
