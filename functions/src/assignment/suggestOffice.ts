import {
  DepartmentDoc,
  matchesCity,
  rankDepartments,
} from "../agents/departmentDirectory";
import {JurisdictionLevel} from "../agents/types";
import {ROUTER_MIN_CONFIDENCE} from "../config";
import {parseJsonObject} from "../lib/gemmaClient";
import {examplesFor} from "./routerExamples";

/**
 * The per-ticket "Suggested office to file the problem" line.
 *
 * Same contract as the cluster Routing agent: **the model only chooses an id
 * from a candidate list the rules built.** The office's name, email and
 * website are always copied from the directory row, so a model reply can
 * never put a contact in front of a citizen — at worst it picks the
 * second-best real office, and an unusable reply falls back to the rules'
 * own first choice.
 */

/** What the app reads from `submissions/{id}.suggestedOffice`. */
export interface SuggestedOffice {
  departmentId: string;
  name: string;
  shortName: string | null;
  officerDesignation: string | null;
  email: string | null;
  websiteUrl: string | null;
  phone: string | null;
  matchQuality: "exact" | "state-fallback" | "national-fallback";
  reason: string | null;
  source: "gemma" | "rules";
  modelId: string | null;
  confidence: number | null;
}

export interface SuggestInput {
  theme: string | null;
  /** The PII-free `publicSummary` — the only report text that leaves for
   * the free model. */
  summary: string;
  districtId: string | null;
  districtName: string | null;
  talukName: string | null;
  /** Resolved to a BBMP/GBA ward, i.e. inside Bengaluru city. */
  inBengaluruWard: boolean;
  lat?: number | null;
  lng?: number | null;
}

/** Rough city limits of Karnataka's city corporations outside Bengaluru —
 * centre and radius in km. Only the urban/rural call depends on these; a
 * taluk named after a city is mostly villages, so the taluk alone can't
 * say whether a point is in town. */
const CITY_CENTRES: Array<[name: string, lat: number, lng: number, km: number]> = [
  ["Mysuru", 12.3052, 76.6551, 9],
  ["Mangaluru", 12.8698, 74.8430, 8],
  ["Hubballi", 15.3647, 75.1240, 8],
  ["Dharwad", 15.4589, 75.0078, 6],
  ["Belagavi", 15.8497, 74.4977, 7],
  ["Kalaburagi", 17.3297, 76.8343, 7],
  ["Davanagere", 14.4644, 75.9218, 6],
  ["Ballari", 15.1394, 76.9214, 6],
  ["Vijayapura", 16.8302, 75.7100, 6],
  ["Shivamogga", 13.9299, 75.5681, 6],
  ["Tumakuru", 13.3409, 77.1010, 6],
];

function kmBetween(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(a));
}

/** Anything that turns a prompt into text — `GemmaClient` in production, a
 * stub in tests. */
export interface TextModel {
  generate(prompt: string): Promise<{text: string; modelId: string}>;
}

const MAX_CANDIDATES = 6;

/** Locality for the directory's city match: Bengaluru wards are "Bengaluru"
 * whatever their taluk is called; elsewhere the taluk name, which is what
 * city-corporation rows are keyed on. */
function localityOf(input: SuggestInput): string | null {
  return input.inBengaluruWard ? "Bengaluru" : input.talukName;
}

/** Inside a city corporation: a Bengaluru ward, or a taluk an urban body
 * covers. */
export function isUrban(directory: DepartmentDoc[], input: SuggestInput): boolean {
  if (input.inBengaluruWard) return true;
  if (typeof input.lat === "number" && typeof input.lng === "number") {
    const {lat, lng} = input as {lat: number; lng: number};
    return CITY_CENTRES.some(([, cLat, cLng, km]) => kmBetween(lat, lng, cLat, cLng) <= km);
  }
  // No coordinates: fall back to "the taluk carries a city corporation".
  const locality = localityOf(input);
  if (!locality) return false;
  return directory.some((d) =>
    d.areaType === "urban" && (d.cities ?? []).some((c) => matchesCity(c, locality)),
  );
}

/** The rules' ranked shortlist; the head is the rules-only answer. */
export function officeCandidates(
  directory: DepartmentDoc[],
  input: SuggestInput,
): Array<{doc: DepartmentDoc; score: number}> {
  const urban = isUrban(directory, input);
  const preferredLevel: JurisdictionLevel = urban ? "municipal" : "state";
  return rankDepartments(directory.filter((d) => !d.escalationOnly), {
    theme: input.theme ?? "",
    state: "Karnataka",
    city: localityOf(input),
    districtId: input.districtId,
    urban,
    preferredLevel,
  }).slice(0, MAX_CANDIDATES);
}

function describe(doc: DepartmentDoc): string {
  const scope = doc.catchAll ?
    "state-wide grievance portal for any department, use only if nothing else fits" :
    `${doc.jurisdictionLevel}; handles ${doc.themes.join(", ")}` +
      (doc.areaType && doc.areaType !== "any" ? `; ${doc.areaType} areas` : "") +
      (doc.cities ? `; serves ${doc.cities.slice(0, 4).join(", ")}` : "");
  return `- ${doc.departmentId}: ${doc.name} (${scope})`;
}

/** [withExamples] is off for fine-tuning data: a tuned model learns from
 * the dataset, not from examples pasted into every prompt. */
export function buildRouterPrompt(
  input: SuggestInput,
  candidates: DepartmentDoc[],
  urban: boolean,
  withExamples = true,
): string {
  const place = [
    input.talukName && `${input.talukName} taluk`,
    input.districtName,
  ].filter(Boolean).join(", ") || "Karnataka (exact place unknown)";
  const examples = (withExamples ? examplesFor(input.theme, urban) : []).map((e) =>
    `Report: "${e.summary}" | Category: ${e.theme} | Place: ${e.place}` +
      `${e.urban ? " (city)" : " (outside city limits)"}\n` +
      `Answer: {"departmentId": "${e.departmentId}", "confidence": 0.9, ` +
      `"reason": "${e.reason}"}`,
  );
  return [
    "You route a civic complaint from Karnataka, India to the one government " +
      "office that should handle it. Choose exactly one office from CANDIDATES " +
      "by its id. Never invent an office or an id.",
    "",
    "CANDIDATES:",
    ...candidates.map(describe),
    "",
    ...(examples.length ? ["EXAMPLES:", ...examples, ""] : []),
    `Report: "${input.summary}" | Category: ${input.theme ?? "unknown"} | ` +
      `Place: ${place}${urban ? " (city)" : " (outside city limits)"}`,
    "",
    "Reply with ONLY this JSON object:",
    '{"departmentId": "<an id from CANDIDATES>", "confidence": <0 to 1>, ' +
      '"reason": "<at most 20 words>"}',
  ].join("\n");
}

/** Validates a model reply against the shortlist. Null means "use the
 * rules" — an unknown id, a missing confidence or a low one. */
export function parseRouterReply(
  text: string,
  candidateIds: string[],
): {departmentId: string; confidence: number; reason: string} | null {
  const raw = parseJsonObject(text);
  if (!raw) return null;
  const id = typeof raw.departmentId === "string" ? raw.departmentId.trim() : "";
  if (!candidateIds.includes(id)) return null;
  const confidence = Number(raw.confidence);
  if (!Number.isFinite(confidence) || confidence < ROUTER_MIN_CONFIDENCE) {
    return null;
  }
  const reason = typeof raw.reason === "string" ?
    raw.reason.trim().split(/\s+/).slice(0, 25).join(" ") :
    "";
  return {departmentId: id, confidence: Math.min(confidence, 1), reason};
}

function matchQualityOf(
  doc: DepartmentDoc,
  input: SuggestInput,
): SuggestedOffice["matchQuality"] {
  if (doc.state === "*") return "national-fallback";
  if (doc.catchAll) return "state-fallback";
  const locality = localityOf(input);
  const cityMatch = locality && (doc.cities ?? []).some((c) => matchesCity(c, locality));
  const districtMatch = input.districtId && doc.districtIds?.includes(input.districtId);
  return cityMatch || districtMatch ? "exact" : "state-fallback";
}

export function toSuggestedOffice(
  doc: DepartmentDoc,
  input: SuggestInput,
  pick: {source: "gemma" | "rules"; modelId?: string | null; confidence?: number | null; reason?: string | null},
): SuggestedOffice {
  return {
    departmentId: doc.departmentId,
    name: doc.name,
    shortName: doc.shortName,
    officerDesignation: doc.officerDesignation ?? null,
    email: doc.email,
    websiteUrl: doc.grievancePortalUrl,
    phone: doc.phone,
    matchQuality: matchQualityOf(doc, input),
    reason: pick.reason ?? null,
    source: pick.source,
    modelId: pick.modelId ?? null,
    confidence: pick.confidence ?? null,
  };
}

/**
 * Picks the office for one ticket. Never throws for a model problem: with no
 * model, a failed call or an unusable reply, the rules' first candidate is
 * the answer. Null only when the directory has nothing at all for Karnataka.
 */
export async function suggestOffice(
  directory: DepartmentDoc[],
  input: SuggestInput,
  model: TextModel | null,
): Promise<SuggestedOffice | null> {
  const candidates = officeCandidates(directory, input).map((c) => c.doc);
  if (!candidates.length) return null;
  const rulesPick = toSuggestedOffice(candidates[0], input, {source: "rules"});
  // One candidate leaves nothing to decide.
  if (!model || candidates.length === 1) return rulesPick;

  try {
    const urban = isUrban(directory, input);
    const {text, modelId} = await model.generate(
      buildRouterPrompt(input, candidates, urban),
    );
    const reply = parseRouterReply(text, candidates.map((c) => c.departmentId));
    if (!reply) {
      console.warn("Gemma router reply unusable; using rules", text.slice(0, 200));
      return rulesPick;
    }
    const chosen = candidates.find((c) => c.departmentId === reply.departmentId)!;
    return toSuggestedOffice(chosen, input, {
      source: "gemma",
      modelId,
      confidence: reply.confidence,
      reason: reply.reason,
    });
  } catch (err) {
    console.error("Gemma router failed; using rules", err);
    return rulesPick;
  }
}
