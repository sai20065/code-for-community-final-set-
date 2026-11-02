/**
 * Ticket workflow rules as pure functions, so they are testable without
 * Firestore (`npm run verify:workflow`).
 *
 * Lifecycle: new → reviewed → inProgress → resolved (worker says fixed) →
 *   - citizen confirms          → closed
 *   - citizen says "not fixed"  → inProgress again
 *   - 48 h of silence           → an admin / worker / in-scope official may
 *                                 close it by hand. Nothing closes itself.
 */

export const CLOSE_WINDOW_MS = 48 * 3600 * 1000;

export const STATUSES = ["new", "reviewed", "inProgress", "resolved", "closed"] as const;
export type Status = typeof STATUSES[number];

export type CloseState = "none" | "awaiting_citizen" | "closeable";

export interface CitizenResponse {
  kind: "confirmed" | "not_fixed";
}

/** Where a fixed ticket stands in the 48-hour window. */
export function closeState(
  status: string,
  fixedAtMs: number | null,
  response: CitizenResponse | null | undefined,
  nowMs: number,
): CloseState {
  if (status !== "resolved" || fixedAtMs == null || response) return "none";
  return nowMs - fixedAtMs >= CLOSE_WINDOW_MS ? "closeable" : "awaiting_citizen";
}

/** Milliseconds left for the citizen to answer; 0 once the window is over. */
export function windowRemainingMs(fixedAtMs: number, nowMs: number): number {
  return Math.max(0, CLOSE_WINDOW_MS - (nowMs - fixedAtMs));
}

/** Statuses a field worker may set. They can never close or skip back to new. */
export const WORKER_STATUSES: readonly Status[] = ["inProgress", "resolved"];

/** Statuses an in-scope official may set by hand. `closed` goes through
 * closeTicket, which enforces the 48-hour rule. */
export const OFFICIAL_STATUSES: readonly Status[] = ["new", "reviewed", "inProgress", "resolved"];

/** A closed ticket stays closed; everything else may move. */
export function canChangeStatus(from: string, to: string, allowed: readonly Status[]): boolean {
  if (from === "closed") return false;
  if (!(allowed as readonly string[]).includes(to)) return false;
  return from !== to;
}

/** May the citizen still answer "was it fixed?" */
export function citizenMayRespond(
  status: string,
  fixedAtMs: number | null,
  response: CitizenResponse | null | undefined,
  nowMs: number,
): boolean {
  return status === "resolved" && fixedAtMs != null && !response &&
    nowMs - fixedAtMs < CLOSE_WINDOW_MS;
}

/** Both fixed-and-closed count as "fixed" in every public tally. */
export function isFixed(status: string): boolean {
  return status === "resolved" || status === "closed";
}
