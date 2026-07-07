/**
 * One-off admin script — NOT deployed as a Cloud Function. Provisions a
 * real Firebase Auth account + matching `users/{uid}` doc (role: official)
 * for every Karnataka constituency already seeded in `constituencies`
 * (see `seedConstituencies.ts`) that doesn't have one yet.
 *
 * Reuses the exact login scheme `AuthService.signInOfficial` already
 * expects — email = `{constituencyId}@mp.prajadhwani.app` — so no client
 * changes are needed. `blr-north` is skipped since that account already
 * exists (created manually before this script existed).
 *
 * Generates a fresh random password per account and writes the full
 * constituencyId -> password list to the given output file — hand that
 * file to whoever needs to log in as each MP, then delete it; passwords
 * are never stored anywhere else (Firebase Auth only stores the hash) and
 * this script does not commit that output file anywhere.
 *
 * Run with a service account that has Firebase Auth + Firestore write access:
 *   cd functions
 *   npm install
 *   npx ts-node src/scripts/seedKarnatakaOfficials.ts path/to/output-credentials.json
 */
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import * as fs from "fs";

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

const EMAIL_SUFFIX = "@mp.prajadhwani.app";

function genPassword(): string {
  const rand = crypto.randomBytes(9).toString("base64").replace(/[+/=]/g, "").slice(0, 10);
  return `Mp${rand}!7`;
}

async function main() {
  const outputPath = process.argv[2];
  if (!outputPath) {
    console.error("Usage: ts-node seedKarnatakaOfficials.ts <output-credentials.json>");
    process.exit(1);
  }

  const snapshot = await db.collection("constituencies").where("state", "==", "Karnataka").get();
  console.log(`Found ${snapshot.size} Karnataka constituencies.`);

  const results: Array<{constituencyId: string; name: string; mpName?: string; email: string; password: string; uid: string}> = [];

  for (const doc of snapshot.docs) {
    const constituencyId = doc.id;
    if (constituencyId === "blr-north") {
      console.log(`Skipping ${constituencyId} (${doc.data().name}) — account already exists.`);
      continue;
    }
    const data = doc.data();
    const email = `${constituencyId}${EMAIL_SUFFIX}`;
    const password = genPassword();

    try {
      const userRecord = await auth.createUser({email, password});
      await db.collection("users").doc(userRecord.uid).set({
        role: "official",
        constituencyId,
        name: `MP Office — ${data.name}`,
        preferredLanguage: "en",
        createdAt: admin.firestore.Timestamp.now(),
        signupCompletedAt: admin.firestore.Timestamp.now(),
      });
      console.log(`Provisioned ${constituencyId} (${data.name}) — uid ${userRecord.uid}`);
      results.push({constituencyId, name: data.name, mpName: data.mpName, email, password, uid: userRecord.uid});
    } catch (err) {
      console.error(`FAILED for ${constituencyId} (${data.name}):`, err);
    }
  }

  fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));
  console.log(`\nWrote ${results.length} credentials to ${outputPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
