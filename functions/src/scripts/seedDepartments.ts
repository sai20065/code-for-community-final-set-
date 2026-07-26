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
import {DepartmentDoc} from "../agents/departmentDirectory";

admin.initializeApp();
const db = admin.firestore();

const CHECKED = "seeded 2026-07, contact fields pending verification";

const DEPARTMENTS: DepartmentDoc[] = [
  // ---- Karnataka: municipal bodies -------------------------------------
  {
    departmentId: "KA-GBA-BBMP",
    name: "Greater Bengaluru Authority (BBMP)",
    shortName: "BBMP",
    themes: ["roads", "sanitation", "health"],
    state: "Karnataka",
    cities: ["Bengaluru", "Bangalore"],
    jurisdictionLevel: "municipal",
    email: null,
    phone: null,
    grievancePortalUrl: "https://bbmp.gov.in/",
    escalationDepartmentId: "KA-UDD",
    sdgGoals: [3, 9, 11],
    sourceNote: `BBMP public grievance portal, bbmp.gov.in — ${CHECKED}`,
  },
  {
    departmentId: "KA-BWSSB",
    name: "Bangalore Water Supply and Sewerage Board",
    shortName: "BWSSB",
    themes: ["water", "sanitation"],
    state: "Karnataka",
    cities: ["Bengaluru", "Bangalore"],
    jurisdictionLevel: "municipal",
    email: null,
    phone: null,
    grievancePortalUrl: "https://bwssb.karnataka.gov.in/",
    escalationDepartmentId: "KA-KUWSDB",
    sdgGoals: [6, 11],
    sourceNote: `BWSSB official site, bwssb.karnataka.gov.in — ${CHECKED}`,
  },
  {
    departmentId: "KA-BESCOM",
    name: "Bangalore Electricity Supply Company",
    shortName: "BESCOM",
    themes: ["electricity"],
    state: "Karnataka",
    cities: [
      "Bengaluru", "Bangalore", "Kolar", "Tumakuru", "Chitradurga",
      "Davanagere", "Ramanagara", "Chikkaballapura",
    ],
    jurisdictionLevel: "municipal",
    email: null,
    phone: null,
    grievancePortalUrl: "https://bescom.karnataka.gov.in/",
    escalationDepartmentId: "KA-KPTCL",
    sdgGoals: [7, 11],
    sourceNote: `BESCOM official site, bescom.karnataka.gov.in — ${CHECKED}`,
  },

  // ---- Karnataka: state bodies -----------------------------------------
  {
    departmentId: "KA-KPTCL",
    name: "Karnataka Power Transmission Corporation Limited",
    shortName: "KPTCL",
    themes: ["electricity"],
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    grievancePortalUrl: "https://kptcl.karnataka.gov.in/",
    escalationDepartmentId: null,
    sdgGoals: [7, 9],
    sourceNote: `KPTCL official site, kptcl.karnataka.gov.in — ${CHECKED}`,
  },
  {
    departmentId: "KA-PWD",
    name: "Karnataka Public Works Department",
    shortName: "KPWD",
    themes: ["roads"],
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    grievancePortalUrl: "https://kpwd.karnataka.gov.in/",
    escalationDepartmentId: "IN-MORTH",
    sdgGoals: [9, 11],
    sourceNote: `Karnataka PWD, kpwd.karnataka.gov.in — ${CHECKED}`,
  },
  {
    departmentId: "KA-HFW",
    name: "Department of Health and Family Welfare, Karnataka",
    shortName: "DHFW",
    themes: ["health"],
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    grievancePortalUrl: "https://karunadu.karnataka.gov.in/hfw/",
    escalationDepartmentId: null,
    sdgGoals: [3],
    sourceNote: `Karnataka DHFW — ${CHECKED}`,
  },
  {
    departmentId: "KA-DDPI",
    name: "Department of School Education and Literacy, Karnataka",
    shortName: "DSEL",
    themes: ["education"],
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    grievancePortalUrl: "https://schooleducation.karnataka.gov.in/",
    escalationDepartmentId: null,
    sdgGoals: [4],
    sourceNote: `Karnataka School Education dept — ${CHECKED}`,
  },
  {
    departmentId: "KA-KSPCB",
    name: "Karnataka State Pollution Control Board",
    shortName: "KSPCB",
    themes: ["sanitation"],
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    grievancePortalUrl: "https://kspcb.karnataka.gov.in/",
    escalationDepartmentId: null,
    sdgGoals: [6, 11],
    sourceNote: `KSPCB official site — ${CHECKED}`,
  },
  {
    departmentId: "KA-KUWSDB",
    name: "Karnataka Urban Water Supply and Drainage Board",
    shortName: "KUWSDB",
    themes: ["water", "sanitation"],
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    grievancePortalUrl: "https://kuwsdb.karnataka.gov.in/",
    escalationDepartmentId: null,
    sdgGoals: [6],
    sourceNote: `KUWSDB official site — ${CHECKED}`,
  },
  {
    departmentId: "KA-UDD",
    name: "Urban Development Department, Karnataka",
    shortName: "UDD",
    themes: ["roads", "sanitation", "water"],
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    grievancePortalUrl: "https://uddkar.gov.in/",
    escalationDepartmentId: null,
    sdgGoals: [9, 11],
    sourceNote: `Karnataka UDD — escalation target for municipal bodies — ${CHECKED}`,
  },

  // ---- National fallbacks ----------------------------------------------
  // Reached only when no state/city body matches. Deliberately scored well
  // below any real match: "file it on the central portal" is a much weaker
  // answer than naming the local body, and the UI shows that difference.
  {
    departmentId: "IN-MORTH",
    name: "Ministry of Road Transport and Highways",
    shortName: "MoRTH",
    themes: ["roads"],
    state: "*",
    cities: null,
    jurisdictionLevel: "central",
    email: null,
    phone: null,
    grievancePortalUrl: "https://pgportal.gov.in/",
    escalationDepartmentId: null,
    sdgGoals: [9, 11],
    sourceNote: `CPGRAMS central grievance portal — ${CHECKED}`,
  },
  ...(["water", "electricity", "health", "sanitation", "education"] as const).map(
    (theme): DepartmentDoc => ({
      departmentId: `IN-GENERIC-${theme}`,
      name: "Central Public Grievance Redress and Monitoring System",
      shortName: "CPGRAMS",
      themes: [theme],
      state: "*",
      cities: null,
      jurisdictionLevel: "central",
      email: null,
      phone: null,
      grievancePortalUrl: "https://pgportal.gov.in/",
      escalationDepartmentId: null,
      sdgGoals: [],
      sourceNote: `CPGRAMS central grievance portal — ${CHECKED}`,
    }),
  ),
];

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
