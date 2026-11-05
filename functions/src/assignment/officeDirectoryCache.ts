import type {firestore} from "firebase-admin";
import {DepartmentDoc, loadDirectory} from "../agents/departmentDirectory";
import {DEPARTMENTS} from "../agents/departmentSeed";

const TTL_MS = 10 * 60 * 1000;
let cached: {at: number; rows: DepartmentDoc[]} | null = null;

/**
 * The `departments` collection, reused across tickets for ten minutes — it
 * is a few dozen rows read on every ticket, and contact edits made in the
 * console don't need to show up within the minute. Falls back to the
 * bundled seed when the collection is empty or unreadable, so a ticket
 * never goes without a suggestion because seeding hasn't been run.
 */
export async function officeDirectory(
  db: firestore.Firestore,
): Promise<DepartmentDoc[]> {
  if (cached && Date.now() - cached.at < TTL_MS) return cached.rows;
  let rows: DepartmentDoc[] = [];
  try {
    rows = await loadDirectory(db);
  } catch (err) {
    console.error("departments read failed; using bundled directory", err);
  }
  if (!rows.length) rows = DEPARTMENTS;
  cached = {at: Date.now(), rows};
  return rows;
}
