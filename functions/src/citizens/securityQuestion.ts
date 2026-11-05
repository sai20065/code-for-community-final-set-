import * as admin from "firebase-admin";
import {createHash, randomBytes, scryptSync, timingSafeEqual} from "crypto";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  CITIZEN_EMAIL_SUFFIX,
  RECOVERY_LOCK_MINUTES,
  RECOVERY_MAX_ATTEMPTS,
  REGION,
  SECURITY_QUESTION_IDS,
} from "../config";

/**
 * Password recovery for citizens, who have no email or phone on file.
 *
 * At Sign Up a citizen picks one of [SECURITY_QUESTION_IDS] and answers it.
 * The answer is normalised (trimmed, lowercased, inner whitespace collapsed
 * — so "Govt School " and "govt  school" match) and stored only as a salted
 * scrypt hash in `userSecrets/{uid}`, which firestore.rules make unreadable
 * and unwritable from any client.
 *
 * Brute-force protection: after RECOVERY_MAX_ATTEMPTS wrong answers the
 * account's recovery is locked for RECOVERY_LOCK_MINUTES. The counter resets
 * on a correct answer.
 *
 * Enumeration protection: `getSecurityQuestion` returns a question for
 * *every* well-formed username — for one that doesn't exist (or never set
 * a question) it returns a question derived from a hash of the name, so the
 * response looks identical either way. The reset then simply fails with
 * the same "didn't match" error as a wrong answer.
 */

const USERNAME_RE = /^[a-z0-9_.]{4,20}$/;
const MIN_PASSWORD_LENGTH = 6;

function normaliseUsername(raw: unknown): string {
  const u = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (!USERNAME_RE.test(u)) {
    throw new HttpsError("invalid-argument", "Invalid username.");
  }
  return u;
}

function normaliseAnswer(raw: unknown): string {
  const a = typeof raw === "string" ?
    raw.trim().toLowerCase().replace(/\s+/g, " ") :
    "";
  if (a.length < 2 || a.length > 100) {
    throw new HttpsError("invalid-argument", "Invalid answer.");
  }
  return a;
}

function hashAnswer(answer: string, salt: Buffer): Buffer {
  return scryptSync(answer, salt, 32);
}

async function uidForUsername(username: string): Promise<string | null> {
  try {
    const user = await admin.auth().getUserByEmail(`${username}${CITIZEN_EMAIL_SUFFIX}`);
    return user.uid;
  } catch {
    return null;
  }
}

/** Stable decoy question for usernames with nothing real to ask. */
function decoyQuestionId(username: string): string {
  const digest = createHash("sha256").update(`decoy:${username}`).digest();
  return SECURITY_QUESTION_IDS[digest[0] % SECURITY_QUESTION_IDS.length];
}

/** Signed-in citizen sets or replaces their question + answer. */
export const setSecurityQuestion = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  const questionId = request.data?.questionId;
  if (!SECURITY_QUESTION_IDS.includes(questionId)) {
    throw new HttpsError("invalid-argument", "Unknown question.");
  }
  const answer = normaliseAnswer(request.data?.answer);
  const salt = randomBytes(16);
  const db = admin.firestore();
  // Public-to-its-owner flag so the profile can show "password recovery is
  // set up" without anyone ever reading userSecrets.
  await db.collection("users").doc(uid)
    .set({hasSecurityQuestion: true}, {merge: true});
  await db.collection("userSecrets").doc(uid).set({
    questionId,
    answerHash: hashAnswer(answer, salt).toString("base64"),
    answerSalt: salt.toString("base64"),
    failedAttempts: 0,
    lockedUntil: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

/** Which question to ask for a username (always answers; see above). */
export const getSecurityQuestion = onCall({region: REGION}, async (request) => {
  const username = normaliseUsername(request.data?.username);
  const uid = await uidForUsername(username);
  if (uid) {
    const secret = await admin.firestore().collection("userSecrets").doc(uid).get();
    const questionId = secret.data()?.questionId;
    if (typeof questionId === "string") return {questionId};
  }
  return {questionId: decoyQuestionId(username)};
});

/** Username + correct answer → sets a new password. */
export const resetPasswordWithSecurityQuestion = onCall(
  {region: REGION},
  async (request) => {
    const username = normaliseUsername(request.data?.username);
    const answer = normaliseAnswer(request.data?.answer);
    const newPassword = request.data?.newPassword;
    if (typeof newPassword !== "string" || newPassword.length < MIN_PASSWORD_LENGTH) {
      throw new HttpsError("invalid-argument", "Password too short.");
    }

    const notMatched = new HttpsError("permission-denied", "Answer did not match.");
    const uid = await uidForUsername(username);
    if (!uid) throw notMatched;

    const db = admin.firestore();
    const ref = db.collection("userSecrets").doc(uid);

    // Check-and-count inside a transaction so parallel guesses can't each
    // read failedAttempts = 0 and slip past the lockout.
    const matched = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data();
      if (!data?.answerHash || !data?.answerSalt) return false;

      const lockedUntil = data.lockedUntil as admin.firestore.Timestamp | null;
      if (lockedUntil && lockedUntil.toMillis() > Date.now()) {
        throw new HttpsError("resource-exhausted", "Too many attempts. Try later.");
      }

      const expected = Buffer.from(data.answerHash as string, "base64");
      const actual = hashAnswer(answer, Buffer.from(data.answerSalt as string, "base64"));
      const ok = expected.length === actual.length && timingSafeEqual(expected, actual);

      if (ok) {
        tx.update(ref, {failedAttempts: 0, lockedUntil: null});
        return true;
      }
      const attempts = ((data.failedAttempts as number) ?? 0) + 1;
      tx.update(ref, attempts >= RECOVERY_MAX_ATTEMPTS ? {
        failedAttempts: 0,
        lockedUntil: admin.firestore.Timestamp.fromMillis(
          Date.now() + RECOVERY_LOCK_MINUTES * 60_000,
        ),
      } : {failedAttempts: attempts});
      return false;
    });

    if (!matched) throw notMatched;

    await admin.auth().updateUser(uid, {password: newPassword});
    // Sign out every other device that was using the old password.
    await admin.auth().revokeRefreshTokens(uid);
    return {ok: true};
  },
);
