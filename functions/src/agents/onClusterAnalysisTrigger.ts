import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {
  AGENT_LOCK_MINUTES,
  AGENT_MIN_RERUN_HOURS,
  AGENT_PRIORITY_THRESHOLD,
  AGENT_TRIGGER_COUNTS,
  REGION,
} from "../config";
import {runAgentChain} from "./orchestrator";

/**
 * Runs the four-agent civic intelligence chain when a cluster becomes worth
 * analysing.
 *
 * Every guard below is cheap and runs **before** any Gemini call. That
 * ordering is the whole safety story: this function writes back to the very
 * document that triggers it, so without the self-trigger guard it would
 * invoke itself forever, four Vertex calls at a time, until somebody noticed
 * the bill. Verify guard 2 before deploying, not after.
 */
export const onClusterAnalysis = onDocumentWritten(
  {
    document: "clusters/{clusterId}",
    region: REGION,
    // The chain makes four sequential model calls; the v2 default of 60s
    // is not enough, and a timeout mid-chain loses the agents that already
    // succeeded.
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (event) => {
    const clusterId = event.params.clusterId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // 1. Deleted.
    if (!after) return;

    const beforeCount = (before?.submissionCount as number) ?? 0;
    const afterCount = (after.submissionCount as number) ?? 0;
    const beforePriority = (before?.priorityScore as number) ?? 0;
    const afterPriority = (after.priorityScore as number) ?? 0;

    // 2. SELF-TRIGGER GUARD. The orchestrator's own writeback
    //    (hasSolutionCard, lastAgentRunAt, agentRunCount) changes the
    //    cluster document and re-fires this trigger. Neither of the two
    //    fields that can justify a run changed, so there is nothing to do.
    //    This single comparison is what stands between a bounded cost and a
    //    runaway loop.
    if (beforeCount === afterCount && beforePriority === afterPriority) return;

    // 3. Threshold crossing. Superlinear on purpose — the analysis barely
    //    differs between 5 and 6 tickets, and each run is four model calls.
    const crossedCount = AGENT_TRIGGER_COUNTS.some(
      (n) => beforeCount < n && afterCount >= n,
    );
    const crossedPriority =
      beforePriority < AGENT_PRIORITY_THRESHOLD &&
      afterPriority >= AGENT_PRIORITY_THRESHOLD;
    if (!crossedCount && !crossedPriority) return;

    // 4. Cooldown. A burst of tickets can cross several thresholds within
    //    minutes; one analysis covers all of them.
    const lastRun = after.lastAgentRunAt as admin.firestore.Timestamp | undefined;
    if (lastRun) {
      const hoursSince = (Date.now() - lastRun.toDate().getTime()) / 3_600_000;
      if (hoursSince < AGENT_MIN_RERUN_HOURS) return;
    }

    // 5. Lock. Two tickets landing simultaneously can cross the same
    //    threshold in two concurrent invocations; without this they'd both
    //    run the full chain and race on the same card. The lock is taken
    //    transactionally and self-heals after AGENT_LOCK_MINUTES so a
    //    crashed run doesn't wedge the cluster permanently.
    const db = admin.firestore();
    const clusterRef = db.collection("clusters").doc(clusterId);
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
      console.log(`Cluster ${clusterId}: agent run already in progress`);
      return;
    }

    try {
      const result = await runAgentChain(
        db,
        clusterId,
        crossedPriority ? "priority" : "threshold",
      );
      console.log(
        `Agent chain for ${clusterId}: ` +
          (result ?
            `v${result.card.version}, degraded=${result.card.degraded}` :
            "cluster not found"),
      );
    } catch (err) {
      // The orchestrator is designed not to throw, but if it ever does, the
      // lock must not outlive the failure.
      console.error(`Agent chain failed for ${clusterId}`, err);
      await clusterRef.update({agentRunLockAt: null});
    }
  },
);
