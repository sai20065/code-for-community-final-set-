import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {closeState} from "../work/workflowMath";

/** What a group can be formed on. Several can be combined. */
export const GROUP_KEYS = ["district", "taluk", "assembly", "theme", "status", "assigned", "cluster"] as const;
type GroupKey = typeof GROUP_KEYS[number];

const MAX_ROWS = 2000;
const MAX_TICKETS_OUT = 300;

export interface Row {
  id: string;
  tokenId: string;
  theme: string;
  status: string;
  districtId: string;
  taluk: string;
  assemblyId: string;
  clusterId: string;
  priority: number;
  createdMs: number;
  assignedToUid: string | null;
  assignedToName: string | null;
  closeState: string;
  reopened: boolean;
  summary: string;
}

export interface Filters {
  status?: string;
  theme?: string;
  districtId?: string;
  assigned?: "yes" | "no";
  closeable?: boolean;
  reopened?: boolean;
  minAgeDays?: number;
  sinceDays?: number;
}

/** Pure: does a row pass the admin's filters? */
export function matches(r: Row, f: Filters, nowMs: number): boolean {
  if (f.status && r.status !== f.status) return false;
  if (f.theme && r.theme !== f.theme) return false;
  if (f.districtId && r.districtId !== f.districtId) return false;
  if (f.assigned === "yes" && !r.assignedToUid) return false;
  if (f.assigned === "no" && r.assignedToUid) return false;
  if (f.closeable && r.closeState !== "closeable") return false;
  if (f.reopened && !r.reopened) return false;
  const ageDays = (nowMs - r.createdMs) / 86400000;
  if (f.minAgeDays != null && ageDays < f.minAgeDays) return false;
  if (f.sinceDays != null && ageDays > f.sinceDays) return false;
  return true;
}

function keyValue(r: Row, k: GroupKey): string {
  switch (k) {
  case "district": return r.districtId || "unknown";
  case "taluk": return r.taluk || "unknown";
  case "assembly": return r.assemblyId || "unknown";
  case "theme": return r.theme || "other";
  case "status": return r.status;
  case "assigned": return r.assignedToName || "unassigned";
  case "cluster": return r.clusterId || "none";
  }
}

export interface Group {
  key: string;
  parts: Record<string, string>;
  count: number;
  open: number;
  fixed: number;
  unassigned: number;
  closeable: number;
  reopened: number;
  avgAgeDays: number;
  maxPriority: number;
  ticketIds: string[];
}

/** Pure: group rows on the chosen keys, biggest and oldest first. */
export function groupRows(rows: Row[], keys: GroupKey[], nowMs: number): Group[] {
  const map = new Map<string, {g: Group; ageSum: number}>();
  for (const r of rows) {
    const parts = Object.fromEntries(keys.map((k) => [k, keyValue(r, k)]));
    const key = keys.map((k) => parts[k]).join("|") || "all";
    let e = map.get(key);
    if (!e) {
      e = {g: {key, parts, count: 0, open: 0, fixed: 0, unassigned: 0, closeable: 0, reopened: 0,
        avgAgeDays: 0, maxPriority: 0, ticketIds: []}, ageSum: 0};
      map.set(key, e);
    }
    const fixed = r.status === "resolved" || r.status === "closed";
    e.g.count++;
    if (fixed) e.g.fixed++; else e.g.open++;
    if (!r.assignedToUid && !fixed) e.g.unassigned++;
    if (r.closeState === "closeable") e.g.closeable++;
    if (r.reopened) e.g.reopened++;
    e.g.maxPriority = Math.max(e.g.maxPriority, r.priority);
    e.ageSum += Math.max(0, (nowMs - r.createdMs) / 86400000);
    if (e.g.ticketIds.length < 200) e.g.ticketIds.push(r.id);
  }
  return [...map.values()]
    .map(({g, ageSum}) => ({...g, avgAgeDays: Math.round((ageSum / g.count) * 10) / 10}))
    .sort((a, b) => b.open - a.open || b.avgAgeDays - a.avgAgeDays || b.count - a.count);
}

async function names(col: string): Promise<Record<string, string>> {
  const snap = await admin.firestore().collection(col).select("name").get();
  return Object.fromEntries(snap.docs.map((d) => [d.id, (d.data().name as string) || d.id]));
}

/**
 * Admin-only, statewide: similar issues grouped by place, type and other
 * parameters. Returns summaries and ticket rows with NO reporter identity.
 */
export const getAdminIssueGroups = onCall({region: REGION, memory: "512MiB"}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const db = admin.firestore();
  if ((await db.collection("users").doc(uid).get()).data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }
  const rawKeys: unknown[] = Array.isArray(request.data?.groupBy) ? request.data.groupBy : ["district", "theme"];
  const keys = rawKeys.filter((k): k is GroupKey => (GROUP_KEYS as readonly unknown[]).includes(k)).slice(0, 3);
  const f = (request.data?.filters ?? {}) as Filters;
  const wantGroupKey: string | undefined =
    typeof request.data?.openGroup === "string" ? request.data.openGroup : undefined;

  const snap = await db.collection("submissions").where("submissionCategory", "==", "problem")
    .orderBy("createdAt", "desc").limit(MAX_ROWS).get();
  const now = Date.now();
  const rows: Row[] = snap.docs.map((d) => {
    const t = d.data();
    const loc = t.location ?? {};
    const fixedAt = (t.fixedAt as {toMillis?: () => number} | undefined)?.toMillis?.() ?? null;
    return {
      id: d.id,
      tokenId: t.tokenId ?? d.id,
      theme: t.theme ?? "other",
      status: t.status ?? "new",
      districtId: loc.districtId ?? "",
      taluk: loc.talukId ?? "",
      assemblyId: loc.assemblyId ?? "",
      clusterId: t.clusterId ?? "",
      priority: Number(t.aiScores?.priorityHint ?? 0),
      createdMs: (t.createdAt as {toMillis?: () => number} | undefined)?.toMillis?.() ?? now,
      assignedToUid: t.assignment?.toUid ?? null,
      assignedToName: t.assignment?.toName ?? null,
      closeState: closeState(t.status, fixedAt, t.citizenResponse, now),
      reopened: (t.reopenCount ?? 0) > 0,
      summary: t.publicSummary ?? "",
    };
  }).filter((r) => matches(r, f, now));

  const [districts, taluks, assemblies] = await Promise.all([names("districts"), names("taluks"), names("assemblies")]);
  const label = (k: string, v: string) =>
    k === "district" ? districts[v] ?? v : k === "taluk" ? taluks[v] ?? v : k === "assembly" ? assemblies[v] ?? v : v;

  const groups = groupRows(rows, keys, now).slice(0, 200).map((g) => ({
    key: g.key,
    parts: Object.fromEntries(Object.entries(g.parts).map(([k, v]) => [k, label(k, v)])),
    count: g.count, open: g.open, fixed: g.fixed, unassigned: g.unassigned,
    closeable: g.closeable, reopened: g.reopened, avgAgeDays: g.avgAgeDays, maxPriority: g.maxPriority,
  }));

  const totals = {
    tickets: rows.length,
    open: rows.filter((r) => r.status !== "resolved" && r.status !== "closed").length,
    unassigned: rows.filter((r) => !r.assignedToUid && r.status !== "resolved" && r.status !== "closed").length,
    closeable: rows.filter((r) => r.closeState === "closeable").length,
    awaitingCitizen: rows.filter((r) => r.closeState === "awaiting_citizen").length,
    reopened: rows.filter((r) => r.reopened).length,
  };

  let tickets: unknown[] = [];
  if (wantGroupKey) {
    const open = groupRows(rows, keys, now).find((g) => g.key === wantGroupKey);
    const ids = new Set(open?.ticketIds ?? []);
    tickets = rows.filter((r) => ids.has(r.id)).slice(0, MAX_TICKETS_OUT).map((r) => ({
      id: r.id, tokenId: r.tokenId, theme: r.theme, status: r.status, summary: r.summary,
      district: label("district", r.districtId), taluk: label("taluk", r.taluk),
      ageDays: Math.round((now - r.createdMs) / 86400000),
      assignedTo: r.assignedToName, closeState: r.closeState, reopened: r.reopened,
    }));
  }
  return {totals, groups, tickets, capped: snap.size >= MAX_ROWS};
});
