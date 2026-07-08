import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION, emailAppPassword, emailUser} from "../config";
import {EmailClient} from "../lib/emailClient";
import {generatePassword} from "../lib/passwordGen";

interface Request {
  uniqueId: string;
  email: string;
}

/**
 * MP credential recovery: enter the constituency's unique ID (see
 * `mpCredentials/{id}.uniqueId`) plus the email registered during first-
 * time setup — if they match, a fresh password is generated, set on the
 * Firebase Auth account, and emailed. The old password stops working
 * immediately (Firebase Auth only ever holds one password per account),
 * so a forgotten-password recovery also silently revokes a leaked one.
 *
 * Deliberately NOT gated behind `request.auth`, same reasoning as
 * `mpFirstTimeSetup` — a locked-out MP has no session to authenticate
 * with.
 */
export const mpForgotCredentials = onCall(
  {region: REGION, secrets: [emailUser, emailAppPassword]},
  async (request) => {
    const data = request.data as Request;
    const uniqueId = data?.uniqueId?.trim().toUpperCase();
    const email = data?.email?.trim().toLowerCase();
    if (!uniqueId || !email) {
      throw new HttpsError("invalid-argument", "A unique ID and email are required.");
    }

    const db = admin.firestore();
    const snapshot = await db.collection("mpCredentials")
      .where("uniqueId", "==", uniqueId)
      .limit(1)
      .get();
    if (snapshot.empty) {
      throw new HttpsError("not-found", "That unique ID wasn't recognized.");
    }

    const doc = snapshot.docs[0];
    const credential = doc.data();
    if (!credential.mpEmail) {
      throw new HttpsError(
        "failed-precondition",
        "This account hasn't been set up yet — use first-time setup instead.",
      );
    }
    if (credential.mpEmail !== email) {
      throw new HttpsError("permission-denied", "That email doesn't match our records for this unique ID.");
    }
    const mpUserId = credential.mpUserId as string | undefined;
    if (!mpUserId) {
      throw new HttpsError("failed-precondition", "This MP account isn't fully provisioned yet.");
    }

    const constituencyDoc = await db.collection("constituencies").doc(doc.id).get();
    const constituencyName = (constituencyDoc.data()?.name as string | undefined) ?? doc.id;
    const newPassword = generatePassword();

    // Send BEFORE committing the password change — see mpFirstTimeSetup
    // for why (a failed send must never leave the MP locked out with no
    // email telling them the new password).
    const emailClient = new EmailClient(emailUser.value(), emailAppPassword.value());
    await emailClient.sendCredentials({
      to: email,
      constituencyName,
      loginId: doc.id,
      password: newPassword,
    });

    await admin.auth().updateUser(mpUserId, {password: newPassword});

    return {success: true};
  },
);
