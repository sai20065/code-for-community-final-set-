/**
 * Assertion script for `resolveDepartment` — the department routing table.
 *
 *   npm run verify:routing
 *
 * This is the one piece of the civic intelligence layer that is fully
 * deterministic, so it is the one piece that can be checked without a
 * network call, a Firestore emulator or a model. It is also the piece where
 * being wrong is most visible to a citizen: routing a Bengaluru water
 * complaint to the state board instead of BWSSB sends them to an office
 * that will tell them it isn't theirs.
 *
 * Deliberately dependency-free rather than a Jest suite — the repo has no
 * test harness, and adding one to check a pure function's scoring would be
 * a heavier change than the thing being tested.
 */
import {
  DepartmentDoc,
  resolveDepartment,
  ResolveArgs,
} from "../agents/departmentDirectory";

const KA = "Karnataka";

const DIRECTORY: DepartmentDoc[] = [
  ref("KA-BWSSB", ["water", "sanitation"], KA, ["Bengaluru"], "municipal", "KA-KUWSDB"),
  ref("KA-KUWSDB", ["water", "sanitation"], KA, null, "state", null),
  ref("KA-GBA-BBMP", ["roads", "sanitation"], KA, ["Bengaluru"], "municipal", "KA-UDD"),
  ref("KA-PWD", ["roads"], KA, null, "state", null),
  ref("KA-UDD", ["roads", "water"], KA, null, "state", null),
  ref("IN-GENERIC-water", ["water"], "*", null, "central", null),
  ref("IN-GENERIC-roads", ["roads"], "*", null, "central", null),
];

function ref(
  departmentId: string,
  themes: string[],
  state: string,
  cities: string[] | null,
  jurisdictionLevel: DepartmentDoc["jurisdictionLevel"],
  escalationDepartmentId: string | null,
): DepartmentDoc {
  return {
    departmentId,
    name: departmentId,
    shortName: departmentId,
    themes,
    state,
    cities,
    jurisdictionLevel,
    email: null,
    phone: null,
    grievancePortalUrl: null,
    escalationDepartmentId,
    sdgGoals: [],
    sourceNote: "fixture",
  };
}

interface Case {
  name: string;
  args: ResolveArgs;
  expectId: string | null;
  expectQuality?: string;
  expectEscalation?: string | null;
}

const CASES: Case[] = [
  {
    name: "Bengaluru water goes to BWSSB, not the state board",
    args: {theme: "water", state: KA, city: "Bengaluru", preferredLevel: "municipal"},
    expectId: "KA-BWSSB",
    expectQuality: "exact",
    expectEscalation: "KA-KUWSDB",
  },
  {
    name: "Mysuru water falls back to the state board (BWSSB has no jurisdiction)",
    args: {theme: "water", state: KA, city: "Mysuru", preferredLevel: "state"},
    expectId: "KA-KUWSDB",
    expectQuality: "state-fallback",
  },
  {
    name: "'Bengaluru Urban' still matches the 'Bengaluru' city entry",
    args: {theme: "water", state: KA, city: "Bengaluru Urban", preferredLevel: "municipal"},
    expectId: "KA-BWSSB",
    expectQuality: "exact",
  },
  {
    name: "An out-of-state road issue reaches the national fallback",
    args: {theme: "roads", state: "Maharashtra", city: "Pune", preferredLevel: "municipal"},
    expectId: "IN-GENERIC-roads",
    expectQuality: "national-fallback",
  },
  {
    name: "A state-level road preference picks PWD over BBMP",
    args: {theme: "roads", state: KA, city: null, preferredLevel: "state"},
    expectId: "KA-PWD",
    expectQuality: "state-fallback",
  },
  {
    name: "A theme with no directory entry resolves to nothing, not a guess",
    args: {theme: "education", state: KA, city: "Bengaluru", preferredLevel: "state"},
    expectId: null,
  },
];

let failures = 0;

for (const testCase of CASES) {
  const result = resolveDepartment(DIRECTORY, testCase.args);
  const actualId = result?.primary.departmentId ?? null;
  const problems: string[] = [];

  if (actualId !== testCase.expectId) {
    problems.push(`expected ${testCase.expectId}, got ${actualId}`);
  }
  if (testCase.expectQuality && result?.matchQuality !== testCase.expectQuality) {
    problems.push(
      `expected matchQuality ${testCase.expectQuality}, got ${result?.matchQuality}`,
    );
  }
  if (testCase.expectEscalation !== undefined) {
    const actualEscalation = result?.escalation?.departmentId ?? null;
    if (actualEscalation !== testCase.expectEscalation) {
      problems.push(
        `expected escalation ${testCase.expectEscalation}, got ${actualEscalation}`,
      );
    }
  }

  if (problems.length) {
    failures++;
    console.error(`FAIL  ${testCase.name}\n      ${problems.join("\n      ")}`);
  } else {
    console.log(`ok    ${testCase.name}`);
  }
}

console.log(`\n${CASES.length - failures}/${CASES.length} passed`);
process.exit(failures ? 1 : 0);
