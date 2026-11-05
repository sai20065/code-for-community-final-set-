/**
 * Seeds the `departments` reference collection used by the Routing agent.
 * NOT deployed as a Cloud Function.
 *
 *   npm run seed:departments
 *
 * Every row carries a `sourceNote` recording where the contact came from and
 * when it was last checked. Government contact details go stale constantly,
 * and a row without provenance is indistinguishable from one somebody made
 * up — which is the whole reason department contacts are a seeded table
 * rather than something the model produces.
 *
 * **Phone numbers and email addresses are left null unless verified.** A
 * `grievancePortalUrl` that turns out to be a redirect is a mild
 * inconvenience; a citizen calling a fabricated grievance-cell number and
 * getting a stranger is a real harm and destroys trust in everything else
 * on the report. Fill these in from the official sites before a public
 * launch, and update `sourceNote` when you do.
 */
import * as admin from "firebase-admin";
import {DEPARTMENTS} from "../agents/departmentSeed";

admin.initializeApp();
const db = admin.firestore();

async function main(): Promise<void> {
  const batch = db.batch();
  for (const dept of DEPARTMENTS) {
    batch.set(db.collection("departments").doc(dept.departmentId), {
      ...dept,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Seeded ${DEPARTMENTS.length} departments.`);
  console.log(
    "Reminder: email/phone are null pending verification — fill them in " +
      "from the official sites and update sourceNote before a public launch.",
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
