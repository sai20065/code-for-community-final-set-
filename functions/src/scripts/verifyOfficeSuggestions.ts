/**
 * Assertion script for the per-ticket "suggested office" — the real
 * bundled directory, with a stub in place of Gemma. No network, Firestore
 * or API key needed.
 *
 *   npm run verify:offices
 *
 * Same dependency-free style as `verifyRouting.ts`.
 */
import {DEPARTMENTS} from "../agents/departmentSeed";
import {ROUTER_EXAMPLES} from "../assignment/routerExamples";
import {
  SuggestInput,
  TextModel,
  officeCandidates,
  suggestOffice,
} from "../assignment/suggestOffice";

const place = (
  talukName: string | null,
  districtId: string | null,
  districtName: string | null,
  inBengaluruWard = false,
) => ({talukName, districtId, districtName, inBengaluruWard});

interface Case {
  name: string;
  input: SuggestInput;
  model?: TextModel;
  expectId: string;
  expectSource?: "gemma" | "rules";
  check?: (office: NonNullable<Awaited<ReturnType<typeof suggestOffice>>>) => string | null;
}

const reply = (text: string): TextModel => ({
  generate: async () => ({text, modelId: "stub-gemma"}),
});

const CASES: Case[] = [
  {
    name: "Bengaluru ward water goes to BWSSB, with its gov.in email",
    input: {theme: "water", summary: "No water for days", ...place("Bangalore (North)", "20", "Bengaluru (Urban)", true)},
    expectId: "KA-BWSSB",
    check: (o) => o.email === "callcenter@bwssb.gov.in" && o.matchQuality === "exact" ?
      null : `email/matchQuality wrong: ${o.email} ${o.matchQuality}`,
  },
  {
    name: "Rural Mandya road goes to the Gram Panchayat (RDPR)",
    input: {theme: "roads", summary: "Village road broken", ...place("Malavalli", "22", "Mandya")},
    expectId: "KA-RDPR",
  },
  {
    name: "Rural Tumakuru water goes to RDWSD, not the urban board",
    input: {theme: "water", summary: "Borewell dry", ...place("Pavagada", "18", "Tumakuru")},
    expectId: "KA-RDWSD",
  },
  {
    name: "Hubballi city road goes to HDMC",
    input: {theme: "roads", summary: "Potholes", ...place("Hubballi Nagara", "09", "Dharwad")},
    expectId: "KA-HDMC",
  },
  {
    name: "Electricity follows the ESCOM district map (Koppal → GESCOM)",
    input: {theme: "electricity", summary: "Transformer sparking", ...place("Gangavathi", "07", "Koppal")},
    expectId: "KA-GESCOM",
  },
  {
    name: "Mysuru electricity → CESC",
    input: {theme: "electricity", summary: "Power cuts", ...place("Mysuru", "26", "Mysuru")},
    expectId: "KA-CESC",
  },
  {
    name: "Mysuru city road (by coordinates) is urban: not the Gram Panchayat",
    input: {theme: "roads", summary: "Potholes near the market", ...place("Mysuru", "26", "Mysuru"), lat: 12.3051, lng: 76.6551},
    expectId: "KA-IPGRS",
  },
  {
    name: "Mysuru city water → urban water board",
    input: {theme: "water", summary: "No water", ...place("Mysuru", "26", "Mysuru"), lat: 12.31, lng: 76.64},
    expectId: "KA-KUWSDB",
  },
  {
    name: "A village in a city-named taluk stays rural",
    input: {theme: "roads", summary: "Village road broken", ...place("Hubli", "09", "Dharwad"), lat: 15.25, lng: 75.30},
    expectId: "KA-RDPR",
  },
  {
    name: "Escalation-only UDD is never the first suggestion",
    input: {theme: "roads", summary: "Potholes", ...place("Kalburgi", "04", "Kalburgi"), lat: 17.33, lng: 76.83},
    expectId: "KA-IPGRS",
  },
  {
    name: "No theme and no place still gets the state grievance portal",
    input: {theme: null, summary: "civic issue reported in this area", ...place(null, null, null)},
    expectId: "KA-IPGRS",
    check: (o) => o.websiteUrl === "https://ipgrs.karnataka.gov.in/" ? null : `url ${o.websiteUrl}`,
  },
  {
    name: "Gemma may pick NHAI from the shortlist for a national-highway report",
    input: {theme: "roads", summary: "National highway service road flooded", ...place("Nelamangala", "21", "Bengaluru (Rural)")},
    model: reply('```json\n{"departmentId": "IN-NHAI", "confidence": 0.86, "reason": "National highway asset."}\n```'),
    expectId: "IN-NHAI",
    expectSource: "gemma",
  },
  {
    name: "A model-invented id falls back to the rules' pick",
    input: {theme: "roads", summary: "Village road broken", ...place("Malavalli", "22", "Mandya")},
    model: reply('{"departmentId": "KA-MANDYA-ROADS-CELL", "confidence": 0.99, "reason": "x"}'),
    expectId: "KA-RDPR",
    expectSource: "rules",
  },
  {
    name: "Contacts always come from the directory, never the model's reply",
    input: {theme: "water", summary: "No water", ...place("Bangalore-South", "20", "Bengaluru (Urban)", true)},
    model: reply('{"departmentId": "KA-BWSSB", "confidence": 0.9, "reason": "x", "email": "fake@example.com", "websiteUrl": "https://evil.example"}'),
    expectId: "KA-BWSSB",
    expectSource: "gemma",
    check: (o) => o.email === "callcenter@bwssb.gov.in" && o.websiteUrl === "https://bwssb.karnataka.gov.in/" ?
      null : `contact leaked from model: ${o.email} ${o.websiteUrl}`,
  },
  {
    name: "Low confidence falls back to the rules",
    input: {theme: "electricity", summary: "Power cuts", ...place("Mysuru", "26", "Mysuru")},
    model: reply('{"departmentId": "KA-KPTCL", "confidence": 0.2, "reason": "unsure"}'),
    expectId: "KA-CESC",
    expectSource: "rules",
  },
  {
    name: "A failing model call falls back to the rules",
    input: {theme: "health", summary: "No doctor", ...place("Sira", "18", "Tumakuru")},
    model: {generate: async () => {
      throw new Error("429 quota");
    }},
    expectId: "KA-HFW",
    expectSource: "rules",
  },
];

async function main(): Promise<void> {
  let failures = 0;
  for (const c of CASES) {
    const office = await suggestOffice(DEPARTMENTS, c.input, c.model ?? null);
    const problems: string[] = [];
    if (!office) {
      problems.push("no suggestion");
    } else {
      if (office.departmentId !== c.expectId) {
        problems.push(`expected ${c.expectId}, got ${office.departmentId}`);
      }
      if (c.expectSource && office.source !== c.expectSource) {
        problems.push(`expected source ${c.expectSource}, got ${office.source}`);
      }
      const extra = c.check?.(office);
      if (extra) problems.push(extra);
    }
    if (problems.length) {
      failures++;
      console.error(`FAIL  ${c.name}\n      ${problems.join("\n      ")}`);
    } else {
      console.log(`ok    ${c.name}`);
    }
  }

  // Every hand-labelled example must be reachable: its office has to be on
  // the shortlist the model is shown, or the example teaches an answer the
  // model is never allowed to give.
  const ids = new Set(DEPARTMENTS.map((d) => d.departmentId));
  for (const e of ROUTER_EXAMPLES) {
    if (!ids.has(e.departmentId)) {
      failures++;
      console.error(`FAIL  example label ${e.departmentId} is not in the directory`);
    }
  }

  // Emails only on government domains.
  for (const d of DEPARTMENTS) {
    if (d.email && !/@([a-z0-9-]+\.)*(gov\.in|nic\.in)$/i.test(d.email)) {
      failures++;
      console.error(`FAIL  ${d.departmentId} email ${d.email} is not on a gov.in/nic.in domain`);
    }
  }

  const sample = officeCandidates(DEPARTMENTS, CASES[1].input).map((c) => c.doc.departmentId);
  console.log(`\nShortlist for a rural Mandya road: ${sample.join(", ")}`);
  console.log(`${CASES.length - failures}/${CASES.length} cases passed`);
  process.exit(failures ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
