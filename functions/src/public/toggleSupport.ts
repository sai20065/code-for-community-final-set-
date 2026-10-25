import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";

/**
 * "Me too" on any report in the public feed.
 *
 * Server-side because supporters are uids, which must never be readable by
 * other citizens: the count reaches the public through `publicTickets`, and
 * each citizen's own supports are mirrored to `users/{uid}/supports/{id}`
 * (readable only by them) so the feed can show a filled heart.
 */
export const toggleReportSupport = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to say Me too.");
  const ticketId = request.data?.ticketId;
  if (typeof ticketId !== "string" || !ticketId) {
    throw new HttpsError("invalid-argument", "ticketId required");
  }

  const db = admin.firestore();
  const ref = db.collection("submissions").doc(ticketId);
  const mine = db.collection("users").doc(uid).collection("supports").doc(ticketId);

  const supported = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Report not found.");
    const data = snap.data()!;
    // Agreeing with yourself adds no evidence.
    if (data.userId === uid) {
      throw new HttpsError("failed-precondition", "This is your own report.");
    }
    const ids: string[] = data.supporterIds ?? [];
    if (ids.includes(uid)) {
      tx.update(ref, {
        supporterIds: admin.firestore.FieldValue.arrayRemove(uid),
        supporterCount: admin.firestore.FieldValue.increment(-1),
      });
      tx.delete(mine);
      return false;
    }
    tx.update(ref, {
      supporterIds: admin.firestore.FieldValue.arrayUnion(uid),
      supporterCount: admin.firestore.FieldValue.increment(1),
    });
    tx.set(mine, {at: admin.firestore.FieldValue.serverTimestamp()});
    return true;
  });
  return {supported};
});
