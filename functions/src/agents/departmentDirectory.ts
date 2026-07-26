// Imported as a type rather than relying on the ambient `FirebaseFirestore`
// global: the verification script runs this module through ts-node, whose
// narrower program doesn't pick up firebase-admin's ambient declarations.
import type {firestore} from "firebase-admin";
import {ThemeId} from "../config";
import {DepartmentRef, JurisdictionLevel} from "./types";

/**
 * Department routing is a **table lookup, not a generation task**.
 *
 * The model is never shown, and never asked for, a phone number, an email
 * address or a portal URL. It cannot hallucinate a contact it was never
 * given. A wrong department name is an annoyance; a plausible-looking but
 * fabricated grievance-cell phone number sent to a citizen is a real harm,
 * and no amount of prompt engineering makes a language model a reliable
 * contact database.
 *
 * The model's only job in routing is one genuinely judgement-shaped
 * question — municipal, state or central jurisdiction — and even that
 * degrades to the Solution agent's `ownerHint`.
 */

export interface DepartmentDoc {
  departmentId: string;
  name: string;
  shortName: string | null;
  themes: string[];
  /** Two-letter state code, or "*" for a national fallback. */
  state: string;
  /** Cities this body actually covers; null means the whole state. */
  cities: string[] | null;
  jurisdictionLevel: JurisdictionLevel;
  email: string | null;
  phone: string | null;
  grievancePortalUrl: string | null;
  escalationDepartmentId: string | null;
  /** The post accountable for grievances here — "Executive Engineer (Roads)",
   * "Assistant Commissioner", etc. A *designation*, never a person's name:
   * postings change constantly, and printing a named individual in a report
   * that stays on file for months would be wrong within weeks. Null falls
   * back to a jurisdiction-level generic in the printed briefing. */
  officerDesignation?: string | null;
  sdgGoals: number[];
  /** Where this contact came from and when it was checked. Government
   * contact details go stale constantly; a row without provenance is
   * indistinguishable from one somebody invented. */
  sourceNote: string;
}

export function toRef(doc: DepartmentDoc): DepartmentRef {
  return {
    departmentId: doc.departmentId,
    name: doc.name,
    shortName: doc.shortName,
    jurisdictionLevel: doc.jurisdictionLevel,
    email: doc.email,
    phone: doc.phone,
    grievancePortalUrl: doc.grievancePortalUrl,
  };
}

export interface ResolveArgs {
  theme: ThemeId | string;
  state: string | null;
  city: string | null;
  preferredLevel: JurisdictionLevel;
}

export interface ResolveResult {
  primary: DepartmentDoc;
  escalation: DepartmentDoc | null;
  matchQuality: "exact" | "state-fallback" | "national-fallback";
}

/** Scores one candidate against the request. Pure and total, so the whole
 * routing decision is unit-testable without Firestore or an LLM. */
export function scoreDepartment(doc: DepartmentDoc, args: ResolveArgs): number {
  let score = 0;

  if (doc.state === "*") {
    // National fallbacks exist so routing always produces *something*, but
    // "file it on the central portal" is a much weaker answer than naming
    // the local body, and should lose to any real match.
    score -= 100;
  } else if (args.state && doc.state === args.state) {
    score += 100;
  } else if (args.state && doc.state !== args.state) {
    // Wrong state entirely — never route here.
    return Number.NEGATIVE_INFINITY;
  }

  if (doc.cities === null) {
    // Covers the whole state; fine, but a city-specific body beats it.
    score += 10;
  } else if (args.city && doc.cities.some((c) => matchesCity(c, args.city!))) {
    score += 50;
  } else if (doc.cities.length > 0) {
    // Scoped to cities that don't include ours — this body has no
    // jurisdiction here at all.
    return Number.NEGATIVE_INFINITY;
  }

  if (doc.jurisdictionLevel === args.preferredLevel) score += 25;

  return score;
}

function matchesCity(candidate: string, city: string): boolean {
  const a = candidate.trim().toLowerCase();
  const b = city.trim().toLowerCase();
  // Substring both ways: "Bengaluru" should match "Bengaluru Urban", and
  // KGIS district names don't agree with colloquial city names.
  return a.includes(b) || b.includes(a);
}

/**
 * Picks the department for a theme and location from [directory].
 *
 * Falls back progressively: an exact state+city body, then any body for the
 * state, then the national grievance portal. The chosen tier is returned as
 * `matchQuality` and shown in the UI, because a citizen deserves to know
 * whether they are being pointed at the actual local water board or at a
 * catch-all portal.
 */
export function resolveDepartment(
  directory: DepartmentDoc[],
  args: ResolveArgs,
): ResolveResult | null {
  const candidates = directory
    .filter((d) => d.themes.includes(args.theme))
    .map((d) => ({doc: d, score: scoreDepartment(d, args)}))
    .filter((c) => Number.isFinite(c.score))
    .sort((a, b) => b.score - a.score);

  if (!candidates.length) return null;

  const primary = candidates[0].doc;
  const escalation = primary.escalationDepartmentId ?
    directory.find((d) => d.departmentId === primary.escalationDepartmentId) ??
      null :
    null;

  let matchQuality: ResolveResult["matchQuality"];
  if (primary.state === "*") {
    matchQuality = "national-fallback";
  } else if (
    primary.cities !== null &&
    args.city &&
    primary.cities.some((c) => matchesCity(c, args.city!))
  ) {
    matchQuality = "exact";
  } else {
    matchQuality = "state-fallback";
  }

  return {primary, escalation, matchQuality};
}

/** Loads the directory. Small (tens of documents) and read on every agent
 * run, so it is fetched whole rather than queried per theme — one read of a
 * tiny collection beats a composite index and a filtered query here. */
export async function loadDirectory(
  db: firestore.Firestore,
): Promise<DepartmentDoc[]> {
  const snap = await db.collection("departments").get();
  return snap.docs.map((d): DepartmentDoc => d.data() as DepartmentDoc);
}
