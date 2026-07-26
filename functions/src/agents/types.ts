import {ThemeId} from "../config";

/**
 * Contracts for the civic intelligence layer — four agents that turn a
 * cluster of citizen tickets into an actionable, cited, routed proposal.
 *
 * They form a **conversation**, not four independent prompts: each agent
 * receives the previous agents' outputs as prior turns, so the Solution
 * agent argues from the Root-Cause agent's actual reasoning rather than
 * re-deriving it, and the Compiler writes from all three.
 *
 * Two rules run through every type here:
 *
 * 1. **Nothing identifying.** The only identifier that ever appears is a
 *    `tokenId` (`PD-BLRN-PRB-260706-0007`) — the public receipt code the
 *    citizen already sees. No uid, no name, no address, no phone.
 * 2. **Claims carry citations.** A causal claim without a `tokenId` or a
 *    named statistic behind it is rejected in code, not merely discouraged
 *    in a prompt. An uncited assertion about why a neighbourhood floods is
 *    exactly the sort of confident-sounding invention that would get this
 *    tool dismissed on first contact with an engineer who knows the area.
 */

export type AgentName = "rootCause" | "solution" | "routing" | "reportCompiler";

export type JurisdictionLevel = "municipal" | "state" | "central";

/** One message in the shared inter-agent conversation. */
export interface AgentMessage {
  role: "user" | "model";
  text: string;
}

/** Persisted, auditable record of a single agent's turn. Stored under
 * `solutionCards/{clusterId}/agentTranscripts/{runId}` and readable only by
 * officials — transcripts quote ticket text that the public card doesn't. */
export interface AgentTurn {
  agent: AgentName;
  systemRole: string;
  /** Truncated before storage — transcripts are for auditing the reasoning,
   * not for reconstructing the full prompt. */
  promptText: string;
  rawResponse: string;
  parsedOutput: unknown;
  ok: boolean;
  usedFallback: boolean;
  errorMessage?: string;
  attempts: number;
  latencyMs: number;
  modelId: string;
  startedAt: FirebaseFirestore.Timestamp;
}

/** Evidence behind a single claim. Exactly one of `tokenId` or `stat` is
 * expected; `stat` names a field of the cluster context (e.g.
 * "monsoonShare") so a reader can check the number themselves. */
export interface Citation {
  tokenId?: string;
  stat?: string;
  value?: string;
}

/* ------------------------------------------------------------------ *
 * Agent 1 — Root Cause
 * ------------------------------------------------------------------ */

export interface RootCauseOutput {
  /** At most ~60 words. Why this keeps happening, not what happened. */
  rootCauseSummary: string;
  /** Ordered contributing factors, upstream first. */
  causalChain: string[];
  /** Each claim must carry at least one citation. Enforced by `validate`. */
  claims: Array<{claim: string; citations: Citation[]}>;
  seasonality: "monsoon-driven" | "summer-driven" | "year-round" | "unclear";
  /** What the agent could NOT determine from the data. Populating this
   * honestly is more valuable than a confident guess — it tells the
   * department what to go and measure. */
  dataGaps: string[];
  confidence: number;
}

/* ------------------------------------------------------------------ *
 * Agent 2 — Solution
 * ------------------------------------------------------------------ */

export interface CostBand {
  min: number;
  max: number;
  /** Human-readable, e.g. "₹8–12 lakh". Always a range: presenting a model
   * estimate as a precise figure would be a misrepresentation. */
  label: string;
}

export interface Intervention {
  title: string;
  description: string;
  interventionType: "maintenance" | "capital-works" | "policy" | "service-delivery";
  costBandInr: CostBand;
  timelineWeeks: {min: number; max: number};
  impact: {
    /** Null when the affected population is genuinely unknown. The agent is
     * instructed to say so rather than invent a number. */
    householdsAddressed: number | null;
    peopleAddressed: number | null;
    rationale: string;
  };
  prerequisites: string[];
  ownerHint: JurisdictionLevel;
}

export interface SolutionOutput {
  /** One or two. More than two is a wish list, not a recommendation. */
  interventions: Intervention[];
  /** Something deliverable in under two weeks, when one exists. */
  quickWin: string | null;
  confidence: number;
}

/* ------------------------------------------------------------------ *
 * Agent 3 — Routing
 * ------------------------------------------------------------------ */

export interface DepartmentRef {
  departmentId: string;
  name: string;
  shortName: string | null;
  jurisdictionLevel: JurisdictionLevel;
  email: string | null;
  phone: string | null;
  grievancePortalUrl: string | null;
}

export interface RoutingOutput {
  jurisdictionLevel: JurisdictionLevel;
  jurisdictionRationale: string;
  primary: DepartmentRef;
  escalation: DepartmentRef | null;
  mp: {
    constituencyId: string;
    constituencyName: string;
    mpName: string | null;
  };
  /** How well the directory matched. Surfaced in the UI: routing to a
   * national fallback portal is a materially weaker answer than naming the
   * actual local body, and hiding that difference would be misleading. */
  matchQuality: "exact" | "state-fallback" | "national-fallback";
}

/* ------------------------------------------------------------------ *
 * Agent 4 — Report Compiler
 * ------------------------------------------------------------------ */

export interface SdgMapping {
  goal: number;
  goalName: string;
  /** Specific targets, e.g. ["6.1", "6.b"] — a bare goal number is close to
   * decorative; the target is what an actual reporting framework needs. */
  targets: string[];
  rationale: string;
}

export interface DepartmentBrief {
  problemStatement: string;
  rootCause: string;
  recommendedActions: string[];
  /** Each line ends with a `(PD-…)` token reference. */
  evidence: string[];
  costBandLabel: string;
  expectedImpact: string;
}

/** The final artifact: `solutionCards/{clusterId}`. World-readable, so
 * every free-text field is scrubbed before it is written. */
export interface SolutionCardDoc {
  clusterId: string;
  constituencyId: string;
  constituencyName: string;
  theme: ThemeId | string;
  boothId: string | null;
  wardId: string | null;
  talukId: string | null;
  /** Already snapped for public use — never a raw ticket coordinate. */
  centroid: {lat: number; lng: number} | null;

  /** At most ~10 words. */
  headline: string;
  /** Plain language, no jargon, no rupee figures, no token ids. */
  citizenSummary: string;
  departmentBrief: DepartmentBrief;
  sdg: SdgMapping[];

  priorityScore: number;
  submissionCount: number;
  uniqueReporterCount: number;
  tokenIdsCited: string[];

  routing: RoutingOutput;
  rootCause: RootCauseOutput;
  solutions: SolutionOutput;

  agentRunId: string;
  modelId: string;
  version: number;
  generatedAt: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue;
  /** True when any agent fell back. Shown in the UI — a card assembled from
   * fallbacks should not present with the same authority as one where every
   * agent succeeded. */
  degraded: boolean;
  failedAgents: AgentName[];
}

/* ------------------------------------------------------------------ *
 * Grounding context
 * ------------------------------------------------------------------ */

/** One ticket as the agents see it. Note what is absent: no userId, no raw
 * citizen text, no pincode, no exact coordinates. Grounding data is PII-free
 * at source, so no prompt injection or model lapse can leak what was never
 * put in front of the model. */
export interface ContextTicket {
  tokenId: string;
  summary: string;
  photoCaption: string | null;
  createdOn: string;
  status: string;
}

export interface ClusterContext {
  clusterId: string;
  theme: string;
  constituencyId: string;
  constituencyName: string;
  mpName: string | null;
  state: string | null;
  city: string | null;
  boothId: string | null;
  boothName: string | null;
  boothLocalContext: string | null;
  wardId: string | null;
  wardName: string | null;
  talukId: string | null;
  talukName: string | null;
  centroid: {lat: number; lng: number} | null;

  submissionCount: number;
  uniqueReporterCount: number;
  repeatReporterCount: number;
  priorityScore: number;
  demandScore: number | null;
  demographicScore: number | null;
  infraGapScore: number | null;

  firstReportedOn: string | null;
  lastReportedOn: string | null;
  /** ISO-week → count. */
  weeklyCounts: Record<string, number>;
  /** Fraction of reports filed June–September. The single most useful
   * causal signal for drainage and road issues in Indian cities. */
  monsoonShare: number;
  estimatedAffectedHouseholds: number | null;
  estimatedAffectedPeople: number | null;
  statusCounts: Record<string, number>;

  tickets: ContextTicket[];
  /** Every token in `tickets`, precomputed — the citation validator checks
   * against this, so an agent cannot cite a ticket it was never shown. */
  knownTokenIds: string[];
}
