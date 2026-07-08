import * as crypto from "crypto";

/** Generates a fresh random password for a credential-reset email — never
 * stored in Firestore in plaintext, only ever set on the Firebase Auth
 * account and emailed once. */
export function generatePassword(): string {
  const rand = crypto.randomBytes(9).toString("base64").replace(/[+/=]/g, "").slice(0, 10);
  return `Mp${rand}!7`;
}
