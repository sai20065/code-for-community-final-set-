import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {REGION} from "../config";
import {projectTicket} from "./projection";

/** Statuses tracked in a cluster's rollup. Anything else is ignored rather
 * than creating a stray counter key. */
const TRACKED_STATUSES = new Set(["new", "reviewed", "inProgress", "resolved"]);

/**
 * Maintains `publicTickets/{submissionId}` — the anonymised projection the
 * public dashboard reads.
 *
 * A **separate function** from `onSubmissionCreated` on purpose. The AI
 * pipeline and the public projection have completely different failure
 * modes and completely different consequences when they fail: a Gemini
 * outage should degrade enrichment, not stop the dashboard updating, and a
 * projection bug should never be able to take the classification pipeline
 * down with it.
 *
 * Triggered on *write* rather than on create because the pipeline sets
 * `theme` and `publicSummary` some seconds AFTER the document is created —
 * a create-only projection would publish a permanently empty summary for
 * every ticket. Written-triggered projection converges naturally instead.
 * The pipeline's own updates re-fire this, which is fine: the work is one
 * small document write, and an equality check skips even that when nothing
 * user-visible changed.
 */
export const onSubmissionWrittenPublicProjection = onDocumentWritten(
  {document: "submissions/{submissionId}", region: REGION},
  async (event) => {
    const submissionId = event.params.submissionId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const db = admin.firestore();
    const publicRef = db.collection("publicTickets").doc(submissionId);

    if (!after) {
      await publicRef.delete().catch(() => undefined);
      return;
    }

    const clusterId = after.clusterId as string | undefined;
    const [clusterSnap, wardSnap] = await Promise.all([
      clusterId ?
        db.collection("clusters").doc(clusterId).get() :
        Promise.resolve(null),
      after.location?.wardId ?
        db.collection("wards").doc(after.location.wardId).get() :
        Promise.resolve(null),
    ]);

    const cluster = clusterSnap?.data();
    const ward = wardSnap?.data();
    const wardCentroid =
      typeof ward?.centroidLat === "number" && typeof ward?.centroidLng === "number" ?
        {lat: ward.centroidLat, lng: ward.centroidLng} :
        null;

    const projected = projectTicket({
      submissionId,
      submission: after,
      clusterSubmissionCount: cluster?.submissionCount ?? 0,
      wardCentroid,
    });

    if (!projected) {
      // Not publishable (no token, no constituency yet). Remove any stale
      // projection rather than leaving one behind.
      await publicRef.delete().catch(() => undefined);
    } else {
      const existing = await publicRef.get();
      // Skip the write when nothing changed. The AI pipeline touches a
      // submission several times per ticket and each touch re-fires this.
      if (
        !existing.exists ||
        JSON.stringify(existing.data()) !== JSON.stringify(projected)
      ) {
        await publicRef.set(projected);
      }
    }

    // Cluster status rollup. This trigger is the only place that observes a
    // ticket's status *transition*, so it owns the counters.
    const beforeStatus = before?.status as string | undefined;
    const afterStatus = after.status as string | undefined;
    if (
      clusterId &&
      before &&
      beforeStatus !== afterStatus &&
      afterStatus &&
      TRACKED_STATUSES.has(afterStatus)
    ) {
      const patch: Record<string, unknown> = {
        [`statusCounts.${afterStatus}`]: admin.firestore.FieldValue.increment(1),
      };
      if (beforeStatus && TRACKED_STATUSES.has(beforeStatus)) {
        patch[`statusCounts.${beforeStatus}`] =
          admin.firestore.FieldValue.increment(-1);
      }
      await db
        .collection("clusters")
        .doc(clusterId)
        .update(patch)
        .catch((err) => console.error("status rollup failed", err));
    }
  },
);
