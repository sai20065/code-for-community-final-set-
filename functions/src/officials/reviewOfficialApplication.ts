import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {JURISDICTION_FOR, OFFICIAL_TYPES, OfficialType} from "./scope";

interface Request {
  applicantUid: string;
  decision: "approve" | "reject";
  reason?: string;
}

/**
 * Admin-only: approve or reject a self-registered MLA / officer.
 *
 * Approval is the ONLY way an account becomes `role: 'official'` —
 * firestore.rules forbid any client from writing `role`, so a registrant
 * can never grant themselves dashboard access. The jurisdiction written to
 * `users/{uid}` comes from the application the admin just reviewed.
 */
export const reviewOfficialApplication = onCall({region: REGION}, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Sign in required.");
  const db = admin.firestore();
  const caller = (await db.collection("users").doc(callerUid).get()).data();
  if (caller?.role !== "admin") {
    throw new HttpsError("permission-denied", "Only a Prajadhwani admin can review applications.");
  }

  const {applicantUid, decision, reason} = (request.data ?? {}) as Request;
  if (typeof applicantUid !== "string" || !["approve", "reject"].includes(decision)) {
    throw new HttpsError("invalid-argument", "applicantUid and decision are required.");
  }
  const appRef = db.collection("officialApplications").doc(applicantUid);
  const app = (await appRef.get()).data();
  if (!app) throw new HttpsError("not-found", "Application not found.");

  const reviewed = {
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedBy: callerUid,
  };

  if (decision === "reject") {
    const why = (reason ?? "").trim();
    if (!why) throw new HttpsError("invalid-argument", "A reason is required to reject.");
    await appRef.update({status: "rejected", rejectionReason: why.slice(0, 500), ...reviewed});
    return {ok: true, status: "rejected"};
  }

  const type = app.officialType as OfficialType;
  if (!(OFFICIAL_TYPES as readonly string[]).includes(type) || type === "mp") {
    throw new HttpsError("failed-precondition", "Unsupported official type.");
  }
  const j = app.jurisdiction;
  if (!j?.id || j.type !== JURISDICTION_FOR[type]) {
    throw new HttpsError("failed-precondition", "Application has no valid area.");
  }

  const batch = db.batch();
  batch.set(db.collection("users").doc(applicantUid), {
    role: "official",
    officialType: type,
    jurisdiction: {type: j.type, id: j.id, name: j.name ?? j.id},
    // The parent Lok Sabha seat, when known, so map views can frame it.
    ...(j.constituencyId ? {constituencyId: j.constituencyId} : {}),
    name: app.name,
    designation: app.designation ?? null,
    officialEmail: app.officialEmail,
    preferredLanguage: "en",
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    signupCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: app.submittedAt ?? admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.update(appRef, {status: "approved", rejectionReason: null, ...reviewed});
  await batch.commit();
  return {ok: true, status: "approved"};
});
