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
 * First-time MP onboarding: instead of being handed a password directly,
 * an MP enters the unique identification code assigned to their
 * constituency (see seedKarnatakaOfficials.ts / the `mpCredentials/{id}.
 * uniqueId` field — deliberately NOT stored on the publicly-readable
 * `constituencies` doc, since that would let any signed-in citizen read
 * every MP's verification code) plus their own email. If the code is
 * valid and this constituency hasn't been claimed yet, a fresh password
 * is generated, set on the existing Firebase Auth account (created by the
 * admin provisioning script), the email is recorded (so "forgot
 * credentials" can verify against it later), and the login id + new
 * password are emailed — never returned in the API response itself.
 *
 * Deliberately NOT gated behind `request.auth` — an MP setting up their
 * account for the first time has no session yet. The `uniqueId` itself is
 * the out-of-band shared secret that stands in for authentication here.
 */
export const mpFirstTimeSetup = onCall(
  {region: REGION, secrets: [emailUser, emailAppPassword]},
  async (request) => {
    const data = request.data as Request;
    const uniqueId = data?.uniqueId?.trim().toUpperCase();
    const email = data?.email?.trim().toLowerCase();
    if (!uniqueId || !email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "A valid unique ID and email are required.");
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
    if (credential.mpEmail) {
      throw new HttpsError(
        "already-exists",
        "This account has already been set up. Use \"Forgot credentials\" instead.",
      );
    }
    const mpUserId = credential.mpUserId as string | undefined;
    if (!mpUserId) {
      throw new HttpsError("failed-precondition", "This MP account isn't fully provisioned yet.");
    }

    const constituencyDoc = await db.collection("constituencies").doc(doc.id).get();
    const constituencyName = (constituencyDoc.data()?.name as string | undefined) ?? doc.id;
    const newPassword = generatePassword();

    // Send BEFORE committing anything — if SMTP fails (bad secret, Gmail
    // outage, etc.), nothing has changed yet and the MP can just retry,
    // rather than ending up with a silently-changed password and no email
    // telling them what it is.
    const emailClient = new EmailClient(emailUser.value(), emailAppPassword.value());
    await emailClient.sendCredentials({
      to: email,
      constituencyName,
      loginId: doc.id,
      password: newPassword,
    });

    await admin.auth().updateUser(mpUserId, {password: newPassword});
    await doc.ref.update({mpEmail: email});

    return {success: true};
  },
);
