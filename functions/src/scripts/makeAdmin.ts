/**
 * Grants the Prajadhwani Admin role to an existing Firebase Auth account
 * (looked up by email). NOT deployed — run by the project owner only.
 * Creates the account first if it doesn't exist (prints a one-time
 * password; change it via "Forgot password" on the Admin sign-in).
 *
 *   npx ts-node src/scripts/makeAdmin.ts you@example.com
 */
import * as admin from "firebase-admin";
import {randomBytes} from "crypto";

admin.initializeApp({projectId: "code-for-community-e2cf2"});

async function main() {
  const email = process.argv[2]?.trim().toLowerCase();
  if (!email || !email.includes("@")) {
    console.error("usage: ts-node makeAdmin.ts <email>");
    process.exit(1);
  }
  let user: admin.auth.UserRecord;
  try {
    user = await admin.auth().getUserByEmail(email);
  } catch {
    const password = randomBytes(9).toString("base64url");
    user = await admin.auth().createUser({email, password});
    console.log(`Created ${email} with one-time password: ${password}`);
  }
  await admin.firestore().collection("users").doc(user.uid).set({
    role: "admin",
    name: "Prajadhwani Admin",
    preferredLanguage: "en",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    signupCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  console.log(`${email} (uid ${user.uid}) is now a Prajadhwani admin.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
