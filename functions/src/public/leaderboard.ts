import * as admin from "firebase-admin";
import type {firestore} from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {REGION} from "../config";
import {
  LeaderboardTicket,
  MIN_REPORTS,
  Representative,
  WINDOW_DAYS,
  buildLeaderboard,
} from "./leaderboardMath";

/**
 * Rebuilds `publicLeaderboards/{mla,mp}` from `publicTickets`. Only
 * already-public data goes in, and one document per board keeps the app's
 * read to a single doc. See `leaderboardMath.ts` for the ranking rules.
 */
export async function rebuildLeaderboards(db: firestore.Firestore): Promise<{mla: number; mp: number}> {
  // The compact roster index written by `seedMlaRoster.ts` — the same
  // names the public report card shows.
  const [ticketsSnap, repsSnap] = await Promise.all([
    db.collection("publicTickets").get(),
    db.collection("publicReps").doc("karnataka").get(),
  ]);
  const reps = repsSnap.data() ?? {};
  type Entry = {seat?: string; name?: string | null; vacant?: boolean};
  const toMap = (index: Record<string, Entry> | undefined) => new Map<string, Representative>(
    Object.entries(index ?? {}).map(([id, e]) => [id, {name: e.name ?? null, seat: e.seat ?? id, vacant: e.vacant === true}]),
  );
  const mlas = toMap(reps.mla);
  const mps = toMap(reps.mp);

  const base = ticketsSnap.docs.map((d) => d.data());
  const ticketsFor = (key: "assemblyId" | "constituencyId"): LeaderboardTicket[] =>
    base.map((t) => ({
      repId: typeof t[key] === "string" ? t[key] : null,
      status: t.status ?? "new",
      submissionCategory: t.submissionCategory ?? "problem",
      createdDate: t.createdDate ?? "",
      resolvedDate: t.resolvedDate ?? null,
      isTrialData: t.isTrialData === true,
    }));

  const today = new Date().toISOString().slice(0, 10);
  const mla = buildLeaderboard(ticketsFor("assemblyId"), mlas, today);
  const mp = buildLeaderboard(ticketsFor("constituencyId"), mps, today);
  const rosterAsOf = reps.rosterAsOf ?? null;
  const meta = {
    computedAt: admin.firestore.FieldValue.serverTimestamp(),
    windowDays: WINDOW_DAYS,
    minReports: MIN_REPORTS,
  };
  await Promise.all([
    db.collection("publicLeaderboards").doc("mla").set({...meta, rosterAsOf, rows: mla}),
    db.collection("publicLeaderboards").doc("mp").set({...meta, rows: mp}),
  ]);
  return {mla: mla.length, mp: mp.length};
}

/** Every 6 hours — status changes trickle in, and a leaderboard that moves
 * hourly invites reading noise as news. One of the three free Cloud
 * Scheduler jobs. */
export const refreshLeaderboards = onSchedule(
  {schedule: "every 6 hours", region: REGION, timeZone: "Asia/Kolkata"},
  async () => {
    const counts = await rebuildLeaderboards(admin.firestore());
    console.log("Leaderboards rebuilt", counts);
  },
);
