/**
 * Assertion script for the representative leaderboard's ranking rules.
 * Pure — no Firestore.  npm run verify:leaderboard
 */
import {LeaderboardTicket, Representative, buildLeaderboard} from "../public/leaderboardMath";

const TODAY = "2026-10-25";
const reps = new Map<string, Representative>([
  ["A", {name: "Rep A", seat: "Seat A", vacant: false}],
  ["B", {name: "Rep B", seat: "Seat B", vacant: false}],
  ["C", {name: "Rep C", seat: "Seat C", vacant: false}],
  ["D", {name: null, seat: "Seat D", vacant: true}],
]);

const t = (
  repId: string, status: string, created: string, resolved: string | null = null,
  extra: Partial<LeaderboardTicket> = {},
): LeaderboardTicket => ({
  repId, status, submissionCategory: "problem", createdDate: created, resolvedDate: resolved, ...extra,
});

const tickets: LeaderboardTicket[] = [
  // A: 6 reports, 3 fixed (50%), fixes took 2, 4, 10 days → median 4
  t("A", "resolved", "2026-10-01", "2026-10-03"),
  t("A", "resolved", "2026-10-01", "2026-10-05"),
  t("A", "resolved", "2026-10-01", "2026-10-11"),
  t("A", "new", "2026-10-05"), t("A", "new", "2026-10-20"), t("A", "inProgress", "2026-10-22"),
  // B: 5 reports, 4 fixed (80%)
  t("B", "resolved", "2026-10-10", "2026-10-12"), t("B", "resolved", "2026-10-10", "2026-10-12"),
  t("B", "resolved", "2026-10-10", "2026-10-12"), t("B", "resolved", "2026-10-10", "2026-10-12"),
  t("B", "new", "2026-10-24"),
  // C: 2 real reports (unranked) + lots of trial data and a suggestion that must not count
  t("C", "resolved", "2026-10-10", "2026-10-11"), t("C", "new", "2026-10-10"),
  ...Array.from({length: 20}, () => t("C", "resolved", "2026-10-10", "2026-10-11", {isTrialData: true})),
  t("C", "resolved", "2026-10-10", "2026-10-11", {submissionCategory: "feedback"}),
  // Outside the 90-day window
  ...Array.from({length: 10}, () => t("C", "resolved", "2026-01-01", "2026-01-02")),
  // D: vacant seat, 5 open
  ...Array.from({length: 5}, () => t("D", "new", "2026-10-01")),
  // Unknown rep id is ignored
  t("Z", "new", "2026-10-01"),
];

const rows = buildLeaderboard(tickets, reps, TODAY);
const get = (id: string) => rows.find((r) => r.repId === id);
const checks: Array<[string, boolean]> = [
  ["B (80%) ranks first", rows[0]?.repId === "B" && rows[0].rank === 1],
  ["A (50%) ranks second", get("A")?.rank === 2],
  ["A's percentage and median", get("A")?.fixedPct === 50 && get("A")?.medianDaysToFix === 4],
  ["A's oldest open report is 20 days", get("A")?.oldestOpenDays === 20],
  ["A vacant seat is listed but never ranked", get("D")?.rank === null && get("D")?.vacant === true && get("D")?.reports === 5],
  ["C is unranked: trial data, suggestions and old tickets excluded", get("C")?.reports === 2 && get("C")?.rank === null],
  ["Unranked rows come after ranked ones",
    rows.findIndex((r) => r.rank === null) === rows.filter((r) => r.rank !== null).length],
  ["Unknown representative ids are dropped", !get("Z")],
];

let failures = 0;
for (const [name, ok] of checks) {
  if (!ok) failures++;
  console.log(`${ok ? "ok  " : "FAIL"}  ${name}`);
}
if (failures) console.log(JSON.stringify(rows, null, 1));
console.log(`\n${checks.length - failures}/${checks.length} passed`);
process.exit(failures ? 1 : 0);
