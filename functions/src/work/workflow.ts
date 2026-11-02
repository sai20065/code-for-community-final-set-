import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {generatePassword} from "../lib/passwordGen";
import {scopeForCaller} from "../officials/scope";
import {
  OFFICIAL_STATUSES,
  WORKER_STATUSES,
  canChangeStatus,
  citizenMayRespond,
  closeState,
} from "./workflowMath";

const db = () => admin.firestore();
const ts = () => admin.firestore.FieldValue.serverTimestamp();
const MAX_HISTORY = 30;
const MAX_BULK = 100;

type Doc = FirebaseFirestore.DocumentData;

interface Caller {
  uid: string;
  role: "admin" | "official" | "worker";
  name: string;
  /** Null for admins (statewide) and workers (no area-wide access). */
  field: string | null;
  areaId: string | null;
}

function str(v: unknown, max: number): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}

/** Who is calling, from their OWN user doc. Workers are recognised here and
 * deliberately kept out of `scopeForCaller`, which gives area-wide data. */
async function callerOf(uid: string | undefined): Promise<Caller> {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const user = (await db().collection("users").doc(uid).get()).data();
  if (user?.role === "official" && user.officialType === "fieldWorker") {
    if (user.disabled) throw new HttpsError("permission-denied", "This worker account is switched off.");
    return {uid, role: "worker", name: user.name ?? "Worker", field: null, areaId: null};
  }
  const scope = await scopeForCaller(uid);
  return {
    uid,
    role: scope.field ? "official" : "admin",
    name: user?.name ?? scope.typeLabel,
    field: scope.field,
    areaId: scope.id,
  };
}

function inScope(c: Caller, ticket: Doc): boolean {
  if (c.role === "admin") return true;
  if (c.role === "worker") return ticket.assignment?.toUid === c.uid;
  return c.field != null && ticket.location?.[c.field] === c.areaId;
}

function millis(v: unknown): number | null {
  const t = v as {toMillis?: () => number} | null | undefined;
  return t && typeof t.toMillis === "function" ? t.toMillis() : null;
}

function historyEntry(status: string, c: {uid: string; role: string}, note: string): Doc {
  return {status, byUid: c.uid, byRole: c.role, note: note || null, at: admin.firestore.Timestamp.now()};
}

function appendHistory(ticket: Doc, entry: Doc): Doc[] {
  return [...((ticket.statusHistory as Doc[]) ?? []), entry].slice(-MAX_HISTORY);
}

// ---------------------------------------------------------------- workers

/**
 * A DC / MLA / MP (or an admin) adds a field worker for their own area.
 * No admin approval: the assigner vouches for the person, and the worker only
 * ever sees tickets assigned to them. A temporary password is returned once
 * for the assigner to hand over; it is never stored.
 */
export const createWorker = onCall({region: REGION}, async (request) => {
  const caller = await callerOf(request.auth?.uid);
  if (caller.role === "worker") throw new HttpsError("permission-denied", "Workers cannot add workers.");
  const name = str(request.data?.name, 80);
  const email = str(request.data?.email, 120).toLowerCase();
  if (name.length < 2) throw new HttpsError("invalid-argument", "Enter the worker's name.");
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address for sign-in.");
  }

  const parent = (await db().collection("users").doc(caller.uid).get()).data() ?? {};
  // Admin-created workers belong to the whole state, so they need an area.
  const jurisdiction = caller.role === "admin" ?
    request.data?.jurisdiction as {type?: string; id?: string; name?: string} | undefined :
    parent.jurisdiction ?? (parent.constituencyId ?
      {type: "constituency", id: parent.constituencyId, name: parent.constituencyId} : null);
  if (!jurisdiction?.id || !jurisdiction.type) {
    throw new HttpsError("failed-precondition", "An area is required for the worker.");
  }

  const password = generatePassword();
  let uid: string;
  try {
    uid = (await admin.auth().createUser({email, password, displayName: name})).uid;
  } catch (err) {
    const code = (err as {code?: string}).code ?? "";
    if (code.includes("email-already-exists")) {
      throw new HttpsError("already-exists", "That email already has an account.");
    }
    throw new HttpsError("internal", "Could not create the account.");
  }
  await db().collection("users").doc(uid).set({
    role: "official",
    officialType: "fieldWorker",
    parentUid: caller.uid,
    parentName: caller.name,
    jurisdiction: {type: jurisdiction.type, id: jurisdiction.id, name: jurisdiction.name ?? jurisdiction.id},
    name,
    officialEmail: email,
    preferredLanguage: "en",
    disabled: false,
    approvedAt: ts(),
    signupCompletedAt: ts(),
    createdAt: ts(),
  });
  return {uid, email, tempPassword: password};
});

/** The caller's workers (admins see every worker in the state). */
export const listMyWorkers = onCall({region: REGION}, async (request) => {
  const caller = await callerOf(request.auth?.uid);
  if (caller.role === "worker") throw new HttpsError("permission-denied", "Not for workers.");
  let q: FirebaseFirestore.Query = db().collection("users").where("officialType", "==", "fieldWorker");
  if (caller.role === "official") q = q.where("parentUid", "==", caller.uid);
  const snap = await q.limit(300).get();
  const open = await Promise.all(snap.docs.map(async (d) => (await db().collection("submissions")
    .where("assignment.toUid", "==", d.id)
    .where("status", "in", ["new", "reviewed", "inProgress"]).count().get()).data().count));
  return {
    workers: snap.docs.map((d, i) => ({
      uid: d.id,
      name: d.data().name ?? "",
      email: d.data().officialEmail ?? "",
      areaName: d.data().jurisdiction?.name ?? "",
      parentName: d.data().parentName ?? "",
      disabled: d.data().disabled === true,
      openTickets: open[i],
    })),
  };
});

export const setWorkerActive = onCall({region: REGION}, async (request) => {
  const caller = await callerOf(request.auth?.uid);
  if (caller.role === "worker") throw new HttpsError("permission-denied", "Not for workers.");
  const workerUid = str(request.data?.workerUid, 128);
  const active = request.data?.active === true;
  const ref = db().collection("users").doc(workerUid);
  const w = (await ref.get()).data();
  if (w?.officialType !== "fieldWorker") throw new HttpsError("not-found", "Worker not found.");
  if (caller.role === "official" && w.parentUid !== caller.uid) {
    throw new HttpsError("permission-denied", "That is not your worker.");
  }
  await ref.update({disabled: !active});
  await admin.auth().updateUser(workerUid, {disabled: !active});
  return {ok: true};
});

// ------------------------------------------------------------- assignment

/** Assign one or more tickets to a worker. */
export const assignTicket = onCall({region: REGION}, async (request) => {
  const caller = await callerOf(request.auth?.uid);
  if (caller.role === "worker") throw new HttpsError("permission-denied", "Workers cannot assign.");
  const ids: string[] = Array.isArray(request.data?.ticketIds) ?
    [...new Set((request.data.ticketIds as unknown[]).filter((x): x is string => typeof x === "string"))] : [];
  const workerUid = str(request.data?.workerUid, 128);
  const note = str(request.data?.note, 280);
  if (!ids.length || ids.length > MAX_BULK) {
    throw new HttpsError("invalid-argument", `Choose 1 to ${MAX_BULK} tickets.`);
  }
  const worker = (await db().collection("users").doc(workerUid).get()).data();
  if (worker?.officialType !== "fieldWorker" || worker.disabled) {
    throw new HttpsError("failed-precondition", "Choose an active worker.");
  }
  if (caller.role === "official" && worker.parentUid !== caller.uid) {
    throw new HttpsError("permission-denied", "You can only assign to your own workers.");
  }

  let assigned = 0;
  const skipped: string[] = [];
  for (const id of ids) {
    const ref = db().collection("submissions").doc(id);
    const ok = await db().runTransaction(async (tx) => {
      const t = (await tx.get(ref)).data();
      if (!t || !inScope(caller, t) || t.status === "closed" || t.submissionCategory === "feedback") return false;
      const update: Doc = {
        assignment: {
          toUid: workerUid, toName: worker.name ?? "", byUid: caller.uid, byName: caller.name,
          at: admin.firestore.Timestamp.now(), note: note || null,
        },
        updatedAt: ts(),
      };
      if (t.status === "new") {
        update.status = "reviewed";
        update.statusHistory = appendHistory(t, historyEntry("reviewed", {uid: caller.uid, role: caller.role}, "Assigned"));
      }
      tx.update(ref, update);
      return true;
    });
    if (ok) assigned++; else skipped.push(id);
  }
  return {assigned, skipped};
});

// ----------------------------------------------------------------- status

/** Official or assigned worker changes a ticket's status. Replaces the old
 * direct client write, so every change is checked and recorded. */
export const updateTicketStatus = onCall({region: REGION}, async (request) => {
  const caller = await callerOf(request.auth?.uid);
  const ids: string[] = Array.isArray(request.data?.ticketIds) ?
    (request.data.ticketIds as unknown[]).filter((x): x is string => typeof x === "string") :
    typeof request.data?.ticketId === "string" ? [request.data.ticketId] : [];
  const status = str(request.data?.status, 20);
  const note = str(request.data?.note, 280);
  if (!ids.length || ids.length > MAX_BULK) throw new HttpsError("invalid-argument", "No tickets chosen.");
  const allowed = caller.role === "worker" ? WORKER_STATUSES : OFFICIAL_STATUSES;
  if (!(allowed as readonly string[]).includes(status)) {
    throw new HttpsError("invalid-argument", "That status is not allowed for you.");
  }

  let changed = 0;
  const skipped: string[] = [];
  for (const id of ids) {
    const ref = db().collection("submissions").doc(id);
    const ok = await db().runTransaction(async (tx) => {
      const t = (await tx.get(ref)).data();
      if (!t || !inScope(caller, t) || !canChangeStatus(t.status, status, allowed)) return false;
      const update: Doc = {
        status,
        updatedAt: ts(),
        statusHistory: appendHistory(t, historyEntry(status, caller, note)),
      };
      if (status === "resolved") {
        // Server clock, never the client's: this starts the citizen's 48 hours.
        update.resolvedAt = ts();
        update.fixedAt = ts();
        update.citizenResponse = admin.firestore.FieldValue.delete();
      }
      tx.update(ref, update);
      return true;
    });
    if (ok) changed++; else skipped.push(id);
  }
  return {changed, skipped};
});

// ------------------------------------------------------ citizen: fixed?

/** The reporter answers "was it fixed?" during the 48-hour window. */
export const citizenRespondFix = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const id = str(request.data?.ticketId, 128);
  const kind = request.data?.kind;
  const note = str(request.data?.note, 280);
  if (!id || (kind !== "confirmed" && kind !== "not_fixed")) {
    throw new HttpsError("invalid-argument", "ticketId and kind are required.");
  }
  const ref = db().collection("submissions").doc(id);
  const result = await db().runTransaction(async (tx) => {
    const t = (await tx.get(ref)).data();
    if (!t || t.userId !== uid) throw new HttpsError("permission-denied", "This is not your report.");
    if (!citizenMayRespond(t.status, millis(t.fixedAt), t.citizenResponse, Date.now())) {
      throw new HttpsError("failed-precondition", "This report is not waiting for your answer.");
    }
    const actor = {uid, role: "citizen"};
    const response = {kind, at: admin.firestore.Timestamp.now(), note: note || null};
    if (kind === "confirmed") {
      tx.update(ref, {
        status: "closed", closedAt: ts(), closedBy: "citizen", closeReason: "Citizen confirmed it is fixed",
        citizenResponse: response, updatedAt: ts(),
        statusHistory: appendHistory(t, historyEntry("closed", actor, "Citizen confirmed it is fixed")),
      });
    } else {
      tx.update(ref, {
        status: "inProgress", citizenResponse: response, reopenCount: admin.firestore.FieldValue.increment(1),
        updatedAt: ts(),
        statusHistory: appendHistory(t, historyEntry("inProgress", actor, note || "Citizen says it is not fixed")),
      });
    }
    return kind;
  });
  return {ok: true, result};
});

// -------------------------------------------------------------- close

/**
 * Close a fixed ticket the citizen never answered. Allowed only once 48 hours
 * have passed since it was marked fixed. Nothing calls this automatically.
 */
export const closeTicket = onCall({region: REGION}, async (request) => {
  const caller = await callerOf(request.auth?.uid);
  const ids: string[] = Array.isArray(request.data?.ticketIds) ?
    (request.data.ticketIds as unknown[]).filter((x): x is string => typeof x === "string") :
    typeof request.data?.ticketId === "string" ? [request.data.ticketId] : [];
  const reason = str(request.data?.reason, 280);
  if (!ids.length || ids.length > MAX_BULK) throw new HttpsError("invalid-argument", "No tickets chosen.");

  let closed = 0;
  const skipped: string[] = [];
  for (const id of ids) {
    const ref = db().collection("submissions").doc(id);
    const ok = await db().runTransaction(async (tx) => {
      const t = (await tx.get(ref)).data();
      if (!t || !inScope(caller, t)) return false;
      if (closeState(t.status, millis(t.fixedAt), t.citizenResponse, Date.now()) !== "closeable") return false;
      const why = reason || "Closed: citizen did not respond within 48 hours";
      tx.update(ref, {
        status: "closed", closedAt: ts(), closedBy: caller.role, closedByUid: caller.uid, closeReason: why,
        updatedAt: ts(),
        statusHistory: appendHistory(t, historyEntry("closed", caller, why)),
      });
      return true;
    });
    if (ok) closed++; else skipped.push(id);
  }
  return {closed, skipped};
});

// --------------------------------------------------------- worker tasks

/**
 * A worker's assigned tickets. Returned by a function (not read directly) so
 * the worker never receives the reporter's identity: only the public summary,
 * place and the assignment note.
 */
export const getWorkerTasks = onCall({region: REGION}, async (request) => {
  const caller = await callerOf(request.auth?.uid);
  if (caller.role !== "worker") throw new HttpsError("permission-denied", "Workers only.");
  const snap = await db().collection("submissions")
    .where("assignment.toUid", "==", caller.uid).limit(200).get();
  const now = Date.now();
  const tasks = snap.docs.map((d) => {
    const t = d.data();
    const fixedAt = millis(t.fixedAt);
    return {
      id: d.id,
      tokenId: t.tokenId ?? d.id,
      summary: t.publicSummary ?? t.translatedText ?? "",
      theme: t.theme ?? null,
      status: t.status,
      area: t.location?.talukName ?? t.location?.wardName ?? t.location?.constituencyName ?? "",
      lat: typeof t.location?.lat === "number" ? t.location.lat : null,
      lng: typeof t.location?.lng === "number" ? t.location.lng : null,
      note: t.assignment?.note ?? null,
      assignedBy: t.assignment?.byName ?? "",
      assignedAt: millis(t.assignment?.at),
      fixedAt,
      closeState: closeState(t.status, fixedAt, t.citizenResponse, now),
      reopened: (t.reopenCount ?? 0) > 0,
    };
  });
  tasks.sort((a, b) => (b.assignedAt ?? 0) - (a.assignedAt ?? 0));
  return {tasks};
});
