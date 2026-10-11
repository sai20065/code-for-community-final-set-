import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";

/**
 * Platform-wide numbers for the Prajadhwani Admin console. Admin-only.
 * Aggregate counts only — no citizen record ever leaves this function.
 */
export const getAdminOverview = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const db = admin.firestore();
  if ((await db.collection("users").doc(uid).get()).data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }
  const count = async (q: FirebaseFirestore.Query) => (await q.count().get()).data().count;
  const users = db.collection("users");
  const subs = db.collection("submissions");
  const apps = db.collection("officialApplications");
  const weekAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 7 * 24 * 3600 * 1000);

  const types = ["mp", "mla", "wardOfficer", "tahsildar", "districtOfficer"];
  const [citizens, officials, pending, reports, reportsThisWeek, resolved, ...byType] = await Promise.all([
    count(users.where("role", "==", "citizen")),
    count(users.where("role", "==", "official")),
    count(apps.where("status", "==", "pending")),
    count(subs),
    count(subs.where("createdAt", ">=", weekAgo)),
    count(subs.where("status", "==", "resolved")),
    ...types.map((t) => count(users.where("officialType", "==", t))),
  ]);
  // Legacy MP accounts predate officialType; count them as MPs.
  const typed = byType.reduce((a, b) => a + b, 0);
  const officialsByType = Object.fromEntries(types.map((t, i) => [t, byType[i]]));
  officialsByType.mp += Math.max(0, officials - typed);

  return {citizens, officials, officialsByType, pendingApplications: pending, reports, reportsThisWeek, resolved};
});
