/**
 * Assertion script for the ticket workflow: the 48-hour window, who may do
 * what, and the admin grouping. Pure — no Firestore.  npm run verify:workflow
 */
import {Row, groupRows, matches} from "../officials/adminIssues";
import {isFixed} from "../work/workflowMath";
import {buildLeaderboard} from "../public/leaderboardMath";
import {
  CLOSE_WINDOW_MS,
  OFFICIAL_STATUSES,
  WORKER_STATUSES,
  canChangeStatus,
  citizenMayRespond,
  closeState,
  windowRemainingMs,
} from "../work/workflowMath";

const H = 3600 * 1000;
const NOW = Date.UTC(2026, 10, 2, 12, 0, 0);
const checks: Array<[string, boolean]> = [];
const check = (name: string, ok: boolean) => checks.push([name, ok]);

// ---- the 48-hour boundary
check("47h59m after fixing: still awaiting the citizen", closeState("resolved", NOW - 48 * H + 60000, null, NOW) === "awaiting_citizen");
check("exactly 48h: closeable", closeState("resolved", NOW - 48 * H, null, NOW) === "closeable");
check("49h: closeable", closeState("resolved", NOW - 49 * H, null, NOW) === "closeable");
check("citizen already answered: never closeable", closeState("resolved", NOW - 60 * H, {kind: "not_fixed"}, NOW) === "none");
check("not resolved: no close state", closeState("inProgress", NOW - 60 * H, null, NOW) === "none");
check("already closed: no close state", closeState("closed", NOW - 60 * H, null, NOW) === "none");
check("no fixedAt: no close state", closeState("resolved", null, null, NOW) === "none");
check("window length is 48h", CLOSE_WINDOW_MS === 48 * H);
check("remaining time counts down", windowRemainingMs(NOW - 10 * H, NOW) === 38 * H);
check("remaining time floors at 0", windowRemainingMs(NOW - 100 * H, NOW) === 0);

// ---- citizen answer window
check("citizen may answer inside window", citizenMayRespond("resolved", NOW - 5 * H, null, NOW));
check("citizen cannot answer after window", !citizenMayRespond("resolved", NOW - 49 * H, null, NOW));
check("citizen cannot answer twice", !citizenMayRespond("resolved", NOW - 5 * H, {kind: "confirmed"}, NOW));
check("citizen cannot answer an open ticket", !citizenMayRespond("inProgress", NOW - 5 * H, null, NOW));

// ---- who can set what
check("worker may mark in progress", canChangeStatus("reviewed", "inProgress", WORKER_STATUSES));
check("worker may mark fixed", canChangeStatus("inProgress", "resolved", WORKER_STATUSES));
check("worker cannot close", !canChangeStatus("resolved", "closed", WORKER_STATUSES));
check("worker cannot reset to new", !canChangeStatus("inProgress", "new", WORKER_STATUSES));
check("official cannot set closed by hand", !canChangeStatus("resolved", "closed", OFFICIAL_STATUSES));
check("closed tickets stay closed", !canChangeStatus("closed", "inProgress", OFFICIAL_STATUSES));
check("no-op change refused", !canChangeStatus("new", "new", OFFICIAL_STATUSES));

// ---- fixed tally
check("closed counts as fixed", isFixed("closed") && isFixed("resolved") && !isFixed("inProgress"));
const reps = new Map([["A", {name: "Rep A", seat: "Seat A", vacant: false}]]);
const lt = (status: string) => ({
  repId: "A", status, submissionCategory: "problem", createdDate: "2026-10-20", resolvedDate: "2026-10-22",
});
const board = buildLeaderboard([lt("closed"), lt("resolved"), lt("new"), lt("inProgress"), lt("closed")], reps, "2026-10-25");
check("leaderboard counts closed as fixed", board[0].fixed === 3 && board[0].open === 2);

// ---- admin grouping
const row = (over: Partial<Row>): Row => ({
  id: "x", tokenId: "T", theme: "water", status: "new", districtId: "D1", taluk: "T1", assemblyId: "A1",
  clusterId: "C1", priority: 3, createdMs: NOW - 5 * 86400000, assignedToUid: null, assignedToName: null,
  closeState: "none", reopened: false, summary: "", ...over,
});
const rows = [
  row({id: "1"}), row({id: "2", assignedToUid: "w", assignedToName: "Ravi"}),
  row({id: "3", status: "closed"}), row({id: "4", theme: "roads", districtId: "D2", priority: 9}),
  row({id: "5", status: "resolved", closeState: "closeable"}),
];
const byDistrictTheme = groupRows(rows, ["district", "theme"], NOW);
const d1water = byDistrictTheme.find((g) => g.key === "D1|water");
check("groups by district and theme", byDistrictTheme.length === 2 && d1water?.count === 4);
check("group splits open and fixed", d1water?.open === 2 && d1water?.fixed === 2);
check("group counts unassigned open tickets", d1water?.unassigned === 1);
check("group counts closeable tickets", d1water?.closeable === 1);
check("group keeps highest priority", byDistrictTheme.find((g) => g.key === "D2|roads")?.maxPriority === 9);
check("filter: unassigned only", rows.filter((r) => matches(r, {assigned: "no"}, NOW)).length === 4);
check("filter: closeable only", rows.filter((r) => matches(r, {closeable: true}, NOW)).length === 1);
check("filter: district", rows.filter((r) => matches(r, {districtId: "D2"}, NOW)).length === 1);
check("filter: older than 10 days finds none", rows.filter((r) => matches(r, {minAgeDays: 10}, NOW)).length === 0);

let failures = 0;
for (const [name, ok] of checks) {
  console.log(`${ok ? "ok  " : "FAIL"}  ${name}`);
  if (!ok) failures++;
}
console.log(`\n${checks.length - failures}/${checks.length} passed`);
process.exit(failures ? 1 : 0);
