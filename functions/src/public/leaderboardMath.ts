/**
 * The representative leaderboard, as pure functions over public tickets —
 * so the ranking rules are testable without Firestore
 * (`npm run verify:leaderboard`).
 *
 * Fairness rules, each deliberate:
 *  - **Ranked on the share of reports that were fixed**, not on how many
 *    problems an area has. A dense ward files more reports; that says
 *    nothing about its MLA.
 *  - **Trial data is never counted.** Seeded demo tickets sit next to real
 *    names here, and fabricated numbers about a real person are a harm.
 *  - **At least [MIN_REPORTS] reports** before a rank is given; below that
 *    one fixed pothole would read as "100%".
 *  - Problems only — suggestions have no "fixed" state.
 *  - A vacant seat is listed but never ranked: there is no one to credit
 *    or blame for it.
 */

export const WINDOW_DAYS = 90;
export const MIN_REPORTS = 5;

export interface LeaderboardTicket {
  repId: string | null;
  status: string;
  submissionCategory: string;
  createdDate: string;
  resolvedDate: string | null;
  isTrialData?: boolean;
}

export interface Representative {
  name: string | null;
  seat: string;
  vacant: boolean;
}

export interface LeaderboardRow {
  repId: string;
  name: string | null;
  seat: string;
  vacant: boolean;
  reports: number;
  open: number;
  fixed: number;
  /** 0–100, one decimal. */
  fixedPct: number;
  medianDaysToFix: number | null;
  oldestOpenDays: number | null;
  /** 1-based; null below [MIN_REPORTS] or for a vacant seat. */
  rank: number | null;
}

function daysBetween(from: string, to: string): number {
  return Math.max(0, Math.round((Date.parse(to) - Date.parse(from)) / 86400000));
}

function median(values: number[]): number | null {
  if (!values.length) return null;
  const s = [...values].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : Math.round((s[m - 1] + s[m]) / 2);
}

export function buildLeaderboard(
  tickets: LeaderboardTicket[],
  reps: Map<string, Representative>,
  today: string,
): LeaderboardRow[] {
  const since = new Date(Date.parse(today) - WINDOW_DAYS * 86400000).toISOString().slice(0, 10);
  const groups = new Map<string, LeaderboardTicket[]>();
  for (const t of tickets) {
    if (t.isTrialData || !t.repId || t.submissionCategory !== "problem") continue;
    if (t.createdDate < since || !reps.has(t.repId)) continue;
    const list = groups.get(t.repId) ?? [];
    list.push(t);
    groups.set(t.repId, list);
  }

  const rows: LeaderboardRow[] = [];
  for (const [repId, list] of groups) {
    const rep = reps.get(repId)!;
    const fixedList = list.filter((t) => t.status === "resolved");
    const openList = list.filter((t) => t.status !== "resolved");
    rows.push({
      repId,
      name: rep.name,
      seat: rep.seat,
      vacant: rep.vacant,
      reports: list.length,
      open: openList.length,
      fixed: fixedList.length,
      fixedPct: Math.round((fixedList.length / list.length) * 1000) / 10,
      medianDaysToFix: median(
        fixedList.map((t) => daysBetween(t.createdDate, t.resolvedDate ?? t.createdDate)),
      ),
      oldestOpenDays: openList.length ?
        Math.max(...openList.map((t) => daysBetween(t.createdDate, today))) :
        null,
      rank: null,
    });
  }

  // Ranked first: higher share fixed, then faster median fix, then more
  // reports (more evidence behind the same share).
  const rankable = (r: LeaderboardRow) => r.reports >= MIN_REPORTS && !r.vacant;
  rows.sort((a, b) => {
    const ra = rankable(a) ? 1 : 0;
    const rb = rankable(b) ? 1 : 0;
    if (ra !== rb) return rb - ra;
    if (b.fixedPct !== a.fixedPct) return b.fixedPct - a.fixedPct;
    const ma = a.medianDaysToFix ?? Number.POSITIVE_INFINITY;
    const mb = b.medianDaysToFix ?? Number.POSITIVE_INFINITY;
    if (ma !== mb) return ma - mb;
    return b.reports - a.reports;
  });
  let rank = 0;
  for (const r of rows) {
    if (rankable(r)) r.rank = ++rank;
  }
  return rows;
}
