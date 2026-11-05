import * as admin from "firebase-admin";
import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {REPORTS_TO_HIDE, moderateComment, overRateLimit} from "./commentModeration";

/**
 * Feed comments live in `feedComments/{id}` — created by the client under
 * strict rules (own uid and username, 1–280 chars, born visible), then
 * screened here. A comment that fails screening is hidden, not deleted.
 * Only visible comments count towards a report's `commentCount`.
 */
export const onFeedCommentCreated = onDocumentCreated(
  {document: "feedComments/{commentId}", region: REGION},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const c = snap.data();
    const db = admin.firestore();

    let reason: string | null = null;
    const verdict = moderateComment(String(c.text ?? ""));
    if (!verdict.ok) reason = verdict.reason;

    if (!reason) {
      // Flood check only — if it can't run (an index still building, a
      // transient error), the comment has already passed content screening
      // and must still be counted.
      try {
        const since = admin.firestore.Timestamp.fromMillis(Date.now() - 3600 * 1000);
        const recent = await db.collection("feedComments")
          .where("uid", "==", c.uid)
          .where("createdAt", ">=", since)
          .count()
          .get();
        if (overRateLimit(recent.data().count)) reason = "rate limit";
      } catch (err) {
        console.warn("comment rate-limit check skipped", err);
      }
    }

    const ticket = db.collection("submissions").doc(String(c.ticketId));
    if (reason) {
      await snap.ref.update({hidden: true, hiddenReason: reason});
      return;
    }
    // The ticket may be a seeded trial doc with no submission behind it.
    if ((await ticket.get()).exists) {
      await ticket.update({commentCount: admin.firestore.FieldValue.increment(1)});
    }
  },
);

export const onFeedCommentDeleted = onDocumentDeleted(
  {document: "feedComments/{commentId}", region: REGION},
  async (event) => {
    const c = event.data?.data();
    if (!c || c.hidden) return;
    const ticket = admin.firestore().collection("submissions").doc(String(c.ticketId));
    if ((await ticket.get()).exists) {
      await ticket.update({commentCount: admin.firestore.FieldValue.increment(-1)});
    }
  },
);

/** One report per citizen per comment; [REPORTS_TO_HIDE] hide it. */
export const reportFeedComment = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to report a comment.");
  const commentId = request.data?.commentId;
  if (typeof commentId !== "string" || !commentId) {
    throw new HttpsError("invalid-argument", "commentId required");
  }
  const db = admin.firestore();
  const ref = db.collection("feedComments").doc(commentId);
  const reporter = ref.collection("reports").doc(uid);

  await db.runTransaction(async (tx) => {
    const [snap, already] = await Promise.all([tx.get(ref), tx.get(reporter)]);
    if (!snap.exists) throw new HttpsError("not-found", "Comment not found.");
    if (already.exists) return;
    const data = snap.data()!;
    const count = (data.reportCount ?? 0) + 1;
    const hide = count >= REPORTS_TO_HIDE && !data.hidden;
    // Every read before any write — a Firestore transaction rule.
    const ticket = db.collection("submissions").doc(String(data.ticketId));
    const ticketExists = hide ? (await tx.get(ticket)).exists : false;
    tx.set(reporter, {at: admin.firestore.FieldValue.serverTimestamp()});
    tx.update(ref, {
      reportCount: count,
      ...(hide ? {hidden: true, hiddenReason: "reported"} : {}),
    });
    if (ticketExists) {
      tx.update(ticket, {commentCount: admin.firestore.FieldValue.increment(-1)});
    }
  });
  return {ok: true};
});
