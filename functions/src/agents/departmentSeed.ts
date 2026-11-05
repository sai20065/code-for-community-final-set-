/**
 * The office directory behind department routing and the per-ticket
 * "suggested office" line. Pure data, so the routing tests and the router
 * dataset builder can import it; `scripts/seedDepartments.ts` writes it to
 * Firestore.
 *
 * Contact rules: a website is listed only after it was fetched and answered;
 * an email only when it sits on the body's own government domain. Every row
 * says where its contact came from in `sourceNote`.
 */
import {DepartmentDoc} from "./departmentDirectory";

const CHECKED = "seeded 2026-07, contact fields pending verification";
/** Rows re-checked for the per-ticket "suggested office" line: the site
 * was fetched and answered on this date. */
const LIVE = "site checked live 2026-10-25";
/** Emails are only ever on a government domain (gov.in / nic.in), which
 * cannot belong to a stranger even if the specific inbox is wrong. */
const GOV_EMAIL_NOTE =
  "email from public helpline listings, on the body's own gov.in domain";

/** ESCOM service areas by KGIS district id (karnataka_taluks.json). */
const ESCOM_DISTRICTS = {
  BESCOM: ["20", "21", "28", "19", "29", "18", "13", "14"],
  MESCOM: ["24", "16", "15", "17"],
  CESC: ["26", "27", "22", "23", "25"],
  HESCOM: ["01", "02", "03", "09", "08", "11", "10"],
  GESCOM: ["04", "05", "06", "07", "12", "30"],
};

function escom(
  id: keyof typeof ESCOM_DISTRICTS,
  name: string,
  url: string,
  districtNames: string[],
): DepartmentDoc {
  return {
    departmentId: `KA-${id}`,
    name,
    shortName: id,
    themes: ["electricity"],
    state: "Karnataka",
    // District names keep the cluster agents (which only know a district
    // name) matching; per-ticket routing uses `districtIds`.
    cities: districtNames,
    districtIds: ESCOM_DISTRICTS[id],
    jurisdictionLevel: "municipal",
    email: null,
    phone: null,
    grievancePortalUrl: url,
    escalationDepartmentId: "KA-KPTCL",
    officerDesignation: "Section Officer (O&M), local sub-division",
    sdgGoals: [7, 11],
    sourceNote: `${id} official site, ${url} — ${LIVE}`,
  };
}

/** One state-level body with a single verified site. */
function stateBody(
  d: Pick<DepartmentDoc, "departmentId" | "name" | "shortName" | "themes" | "grievancePortalUrl"> &
    Partial<DepartmentDoc>,
): DepartmentDoc {
  return {
    state: "Karnataka",
    cities: null,
    jurisdictionLevel: "state",
    email: null,
    phone: null,
    escalationDepartmentId: null,
    sdgGoals: [],
    sourceNote: `${d.grievancePortalUrl} — ${LIVE}`,
    ...d,
  };
}

export const DEPARTMENTS: DepartmentDoc[] = [
  // ---- Karnataka: municipal bodies -------------------------------------
  {
    departmentId: "KA-GBA-BBMP",
    name: "Greater Bengaluru Authority (BBMP)",
    shortName: "BBMP",
    themes: ["roads", "sanitation", "health"],
    state: "Karnataka",
    cities: ["Bengaluru", "Bangalore"],
    areaType: "urban",
    jurisdictionLevel: "municipal",
    email: "comm@bbmp.gov.in",
    phone: null,
    grievancePortalUrl: "https://bbmp.gov.in/",
    escalationDepartmentId: "KA-UDD",
    officerDesignation: "Assistant Executive Engineer, ward office",
    sdgGoals: [3, 9, 11],
    sourceNote: `BBMP, bbmp.gov.in — ${LIVE}; ${GOV_EMAIL_NOTE}`,
  },
  {
    departmentId: "KA-BWSSB",
    name: "Bangalore Water Supply and Sewerage Board",
    shortName: "BWSSB",
    themes: ["water", "sanitation"],
    state: "Karnataka",
    cities: ["Bengaluru", "Bangalore"],
    areaType: "urban",
    jurisdictionLevel: "municipal",
    email: "callcenter@bwssb.gov.in",
    phone: null,
    grievancePortalUrl: "https://bwssb.karnataka.gov.in/",
    escalationDepartmentId: "KA-KUWSDB",
    officerDesignation: "Assistant Executive Engineer, service station",
    sdgGoals: [6, 11],
    sourceNote: `BWSSB, bwssb.karnataka.gov.in — ${LIVE}; ${GOV_EMAIL_NOTE}`,
  },
  {
    departmentId: "KA-HDMC",
    name: "Hubballi-Dharwad Municipal Corporation",
    shortName: "HDMC",
    themes: ["roads", "water", "sanitation"],
    state: "Karnataka",
    cities: ["Hubballi", "Hubli", "Dharwad"],
    areaType: "urban",
    jurisdictionLevel: "municipal",
    email: null,
    phone: null,
    grievancePortalUrl: "http://www.hdmc.mrc.gov.in/",
    escalationDepartmentId: "KA-UDD",
    officerDesignation: "Zonal Assistant Commissioner",
    sdgGoals: [6, 9, 11],
    sourceNote: `HDMC, hdmc.mrc.gov.in — ${LIVE}`,
  },
  {
    departmentId: "KA-BELAGAVI-CC",
    name: "Belagavi City Corporation",
    shortName: "BCC",
    themes: ["roads", "water", "sanitation"],
    state: "Karnataka",
    cities: ["Belagavi", "Belgaum"],
    areaType: "urban",
    jurisdictionLevel: "municipal",
    email: null,
    phone: null,
    grievancePortalUrl: "http://www.belagavicity.mrc.gov.in/",
    escalationDepartmentId: "KA-UDD",
    officerDesignation: "Zonal Assistant Commissioner",
    sdgGoals: [6, 9, 11],
    sourceNote: `Belagavi City Corporation, belagavicity.mrc.gov.in — ${LIVE}`,
  },
  escom(
    "BESCOM", "Bangalore Electricity Supply Company",
    "https://bescom.karnataka.gov.in/",
    [
      "Bengaluru", "Bangalore", "Kolar", "Tumakuru", "Chitradurga",
      "Davanagere", "Ramanagara", "Chikkaballapura",
    ],
  ),
  escom(
    "MESCOM", "Mangalore Electricity Supply Company",
    "https://mescom.karnataka.gov.in/",
    ["Dakshina Kannada", "Udupi", "Shivamogga", "Chikkamagaluru"],
  ),
  escom(
    "CESC", "Chamundeshwari Electricity Supply Corporation",
    "https://cescmysore.karnataka.gov.in/",
    ["Mysuru", "Chamarajanagara", "Mandya", "Hassan", "Kodagu"],
  ),
  escom(
    "HESCOM", "Hubli Electricity Supply Company",
    "https://hescom.karnataka.gov.in/",
    [
      "Belagavi", "Bagalkot", "Vijayapura", "Dharwad", "Gadag", "Haveri",
      "Uttara Kannada",
    ],
  ),
  escom(
    "GESCOM", "Gulbarga Electricity Supply Company",
    "https://gescom.karnataka.gov.in/",
    ["Kalburgi", "Kalaburagi", "Bidar", "Raichur", "Koppal", "Ballari", "Yadgir"],
  ),

  // ---- Karnataka: state bodies -----------------------------------------
  stateBody({
    departmentId: "KA-IPGRS",
    name: "Karnataka Integrated Public Grievance Redressal System (Janaspandana)",
    shortName: "IPGRS",
    themes: ["roads", "water", "electricity", "health", "sanitation", "education"],
    catchAll: true,
    phone: "1902",
    grievancePortalUrl: "https://ipgrs.karnataka.gov.in/",
    sdgGoals: [16],
    sourceNote: `IPGRS, ipgrs.karnataka.gov.in (helpline 1902 shown there) — ${LIVE}`,
  }),
  stateBody({
    departmentId: "KA-KPTCL",
    name: "Karnataka Power Transmission Corporation Limited",
    shortName: "KPTCL",
    themes: ["electricity"],
    grievancePortalUrl: "https://kptcl.karnataka.gov.in/",
    sdgGoals: [7, 9],
    sourceNote: `KPTCL official site, kptcl.karnataka.gov.in — ${CHECKED}`,
  }),
  stateBody({
    departmentId: "KA-PWD",
    name: "Karnataka Public Works Department",
    shortName: "KPWD",
    themes: ["roads"],
    // Highways between towns, not city streets: inside a city the model
    // can still pick it from the shortlist for a "state highway" report.
    areaType: "rural",
    ticketTieBreak: -5,
    grievancePortalUrl: "https://kpwd.karnataka.gov.in/",
    escalationDepartmentId: "IN-MORTH",
    officerDesignation: "Assistant Executive Engineer, PWD sub-division",
    sdgGoals: [9, 11],
  }),
  stateBody({
    departmentId: "KA-HFW",
    name: "Department of Health and Family Welfare, Karnataka",
    shortName: "DHFW",
    themes: ["health"],
    grievancePortalUrl: "https://hfwcom.karnataka.gov.in/",
    officerDesignation: "Taluk Health Officer",
    sdgGoals: [3],
  }),
  stateBody({
    departmentId: "KA-DDPI",
    name: "Department of School Education and Literacy, Karnataka",
    shortName: "DSEL",
    themes: ["education"],
    grievancePortalUrl: "https://schooleducation.karnataka.gov.in/",
    officerDesignation: "Block Education Officer",
    sdgGoals: [4],
  }),
  stateBody({
    departmentId: "KA-KSPCB",
    name: "Karnataka State Pollution Control Board",
    shortName: "KSPCB",
    themes: ["sanitation"],
    grievancePortalUrl: "https://kspcb.karnataka.gov.in/",
    officerDesignation: "Environmental Officer, regional office",
    sdgGoals: [6, 11],
  }),
  stateBody({
    departmentId: "KA-KUWSDB",
    name: "Karnataka Urban Water Supply and Drainage Board",
    shortName: "KUWSDB",
    themes: ["water", "sanitation"],
    areaType: "urban",
    grievancePortalUrl: "https://kuwsdb.karnataka.gov.in/",
    officerDesignation: "Assistant Executive Engineer, KUWSDB division",
    sdgGoals: [6],
  }),
  stateBody({
    departmentId: "KA-UDD",
    name: "Urban Development Department, Karnataka",
    shortName: "UDD",
    themes: ["roads", "sanitation", "water"],
    areaType: "urban",
    escalationOnly: true,
    grievancePortalUrl: "https://uddkar.gov.in/",
    sdgGoals: [9, 11],
    sourceNote: `Karnataka UDD — escalation target for municipal bodies — ${CHECKED}`,
  }),

  // ---- Karnataka: rural bodies -----------------------------------------
  // After the state bodies on purpose: ranking ties keep directory order,
  // and the cluster agents (which don't know urban/rural) should keep
  // their earlier answers. RDWSD before RDPR, so rural drinking water goes
  // to the specialist rather than the Gram Panchayat.
  stateBody({
    departmentId: "KA-RDWSD",
    name: "Rural Drinking Water and Sanitation Department",
    shortName: "RDWSD",
    themes: ["water"],
    areaType: "rural",
    grievancePortalUrl: "https://rdwsd.karnataka.gov.in/",
    escalationDepartmentId: "KA-RDPR",
    officerDesignation: "Assistant Executive Engineer, RDWSD sub-division",
    sdgGoals: [6],
  }),

  stateBody({
    departmentId: "KA-RDPR",
    name: "Rural Development and Panchayat Raj Department (Gram Panchayat)",
    shortName: "RDPR",
    themes: ["roads", "water", "sanitation"],
    areaType: "rural",
    grievancePortalUrl: "https://rdpr.karnataka.gov.in/",
    officerDesignation: "Panchayat Development Officer (PDO), Gram Panchayat",
    sdgGoals: [6, 9, 11],
  }),

  // ---- National bodies -------------------------------------------------
  // Scored well below any state match: reached as fallbacks, or when the
  // per-ticket model reads "national highway" in the report.
  {
    departmentId: "IN-NHAI",
    name: "National Highways Authority of India",
    shortName: "NHAI",
    themes: ["roads"],
    state: "*",
    cities: null,
    jurisdictionLevel: "central",
    email: null,
    phone: null,
    grievancePortalUrl: "https://nhai.gov.in/",
    escalationDepartmentId: "IN-MORTH",
    officerDesignation: "Project Director, NHAI project implementation unit",
    sdgGoals: [9],
    sourceNote: `NHAI, nhai.gov.in — ${LIVE}`,
  },
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
    sourceNote: `CPGRAMS central grievance portal — ${LIVE}`,
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
      sourceNote: `CPGRAMS central grievance portal — ${LIVE}`,
    }),
  ),
];
