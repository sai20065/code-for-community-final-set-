import {
  AgentClient,
  clampNumber,
  isNonEmptyString,
  limitWords,
  stringArray,
} from "./agentClient";
import {
  AgentMessage,
  AgentTurn,
  ClusterContext,
  Intervention,
  JurisdictionLevel,
  RootCauseOutput,
  SolutionOutput,
} from "./types";

/** Order-of-magnitude anchors for Indian municipal works.
 *
 * Without these a model asked for a rupee figure will produce something
 * either absurdly low or wildly high, and a department reading "desilt this
 * drain, ~₹4 crore" stops reading. Anchors don't make the estimates
 * accurate — they make them the right size, which is all a range labelled
 * "estimate" can honestly claim. */
const COST_ANCHORS = `Typical Indian municipal cost anchors (use as order-of-
magnitude reference, not as exact quotes):
- Storm-drain desilting: ₹1.5-4 lakh per km
- Pothole patching: ₹800-1500 per square metre
- Road resurfacing: ₹25-45 lakh per km
- Borewell plus pump: ₹3-6 lakh
- Water pipeline extension: ₹12-20 lakh per km
- 100 kVA distribution transformer: ₹4-7 lakh
- Street lighting (LED, per pole): ₹8-15 thousand
- PHC medicine restocking: ₹2-5 lakh per quarter
- Additional school classroom block: ₹18-30 lakh
- Public toilet block: ₹6-12 lakh
- Garbage collection vehicle: ₹8-14 lakh`;

const SYSTEM_ROLE = `You are a public works planner advising an Indian Member
of Parliament. Given a diagnosed root cause, you propose what should actually
be DONE about it.

HARD RULES:
1. Propose ONE or TWO interventions. Not three, not five. A list of
   everything that could conceivably help is not a recommendation, and the
   MP has a finite budget and attention.
2. Every cost is a RANGE presented as an estimate. Never a precise figure —
   you have not costed this site and must not imply that you have.
3. If "estimatedAffectedHouseholds" is UNKNOWN, set householdsAddressed to
   null. Do NOT invent a number. An invented beneficiary count is the fastest
   way for a department to discard this entire report.
4. Never claim to address more households than the estimate provided.
5. Address the ROOT CAUSE you were given. If the diagnosis is that a drain
   silts up every monsoon, recurring desilting or a capacity upgrade is the
   answer — not "repair the road surface" again.
6. Prefer the smallest intervention that actually resolves the cause.

${COST_ANCHORS}`;

const SCHEMA_HINT = `Respond with ONLY this JSON object:
{
  "interventions": [
    {
      "title": string (at most 10 words),
      "description": string (at most 50 words, concrete and physical),
      "interventionType": "maintenance" | "capital-works" | "policy" | "service-delivery",
      "costBandInr": {"min": number (rupees), "max": number (rupees), "label": string like "₹8-12 lakh"},
      "timelineWeeks": {"min": number, "max": number},
      "impact": {
        "householdsAddressed": number or null,
        "peopleAddressed": number or null,
        "rationale": string (at most 25 words)
      },
      "prerequisites": string[] (surveys, approvals, clearances needed first),
      "ownerHint": "municipal" | "state" | "central"
    }
  ],
  "quickWin": string or null (something deliverable in under 2 weeks),
  "confidence": number between 0 and 1
}`;

const VALID_TYPES = ["maintenance", "capital-works", "policy", "service-delivery"];
const VALID_LEVELS: JurisdictionLevel[] = ["municipal", "state", "central"];

/** Rupee-denominated range with a lakh/crore/thousand word. Rejecting a bare
 * "₹800000" is deliberate: an unformatted number is far harder to sanity
 * check at a glance, which is exactly when an order-of-magnitude slip slides
 * through. */
const COST_LABEL_PATTERN = /(lakh|crore|thousand|₹)/i;

function parseIntervention(
  raw: unknown,
  ctx: ClusterContext,
): Intervention | null {
  if (typeof raw !== "object" || raw === null) return null;
  const d = raw as Record<string, unknown>;

  if (!isNonEmptyString(d.title) || !isNonEmptyString(d.description)) return null;

  const cost = d.costBandInr as Record<string, unknown> | undefined;
  if (!cost || typeof cost.min !== "number" || typeof cost.max !== "number") {
    return null;
  }
  if (cost.min > cost.max || cost.min < 0) return null;
  if (!isNonEmptyString(cost.label) || !COST_LABEL_PATTERN.test(cost.label)) {
    return null;
  }

  const timeline = d.timelineWeeks as Record<string, unknown> | undefined;
  const tMin = clampNumber(timeline?.min, 0, 520, 2);
  const tMax = clampNumber(timeline?.max, tMin, 520, Math.max(tMin, 8));

  const impact = (d.impact ?? {}) as Record<string, unknown>;
  let households =
    typeof impact.householdsAddressed === "number" ?
      Math.round(impact.householdsAddressed) :
      null;
  let people =
    typeof impact.peopleAddressed === "number" ?
      Math.round(impact.peopleAddressed) :
      null;

  // Reject fantasy reach. A 50% tolerance over the estimate allows for the
  // agent reasonably arguing a fix helps slightly beyond the modelled
  // catchment; ten times the estimate is not an argument, it's a number
  // chosen to sound impressive.
  const ceiling = ctx.estimatedAffectedHouseholds;
  if (ceiling !== null && households !== null && households > ceiling * 1.5) {
    return null;
  }
  // No population estimate available means we genuinely don't know. Report
  // that, rather than passing through whatever the model guessed.
  if (ceiling === null) {
    households = null;
    people = null;
  }

  return {
    title: limitWords(d.title, 12),
    description: limitWords(d.description, 60),
    interventionType: VALID_TYPES.includes(d.interventionType as string) ?
      (d.interventionType as Intervention["interventionType"]) :
      "maintenance",
    costBandInr: {min: cost.min, max: cost.max, label: cost.label.trim()},
    timelineWeeks: {min: tMin, max: tMax},
    impact: {
      householdsAddressed: households,
      peopleAddressed: people,
      rationale: isNonEmptyString(impact.rationale) ?
        limitWords(impact.rationale, 30) :
        "",
    },
    prerequisites: stringArray(d.prerequisites, 5),
    ownerHint: VALID_LEVELS.includes(d.ownerHint as JurisdictionLevel) ?
      (d.ownerHint as JurisdictionLevel) :
      "municipal",
  };
}

/**
 * Agent 2. Receives the root cause as a prior model turn — this is the first
 * point where the chain is genuinely a conversation rather than four
 * independent prompts, and it matters: the interventions have to answer the
 * diagnosis that was actually made, not the theme label.
 */
export async function runSolutionAgent(
  client: AgentClient,
  ctx: ClusterContext,
  contextText: string,
  rootCause: RootCauseOutput,
): Promise<{output: SolutionOutput; turn: AgentTurn}> {
  const history: AgentMessage[] = [
    {role: "user", text: contextText},
    {
      role: "model",
      text: JSON.stringify({
        rootCauseSummary: rootCause.rootCauseSummary,
        causalChain: rootCause.causalChain,
        seasonality: rootCause.seasonality,
        dataGaps: rootCause.dataGaps,
        confidence: rootCause.confidence,
      }),
    },
  ];

  return client.run<SolutionOutput>({
    agent: "solution",
    systemRole: SYSTEM_ROLE,
    history,
    userPrompt:
      "Given that root cause, propose the interventions that would actually " +
      "resolve it. Address the cause, not the symptom." +
      (rootCause.confidence === 0 ?
        " NOTE: no reliable root cause was established, so propose only a " +
          "conservative diagnostic or maintenance step and say why." :
        ""),
    schemaHint: SCHEMA_HINT,
    validate: (raw) => {
      const d = raw as Record<string, unknown>;
      if (!Array.isArray(d.interventions) || d.interventions.length === 0) {
        return null;
      }
      const interventions: Intervention[] = [];
      for (const item of d.interventions.slice(0, 2)) {
        const parsed = parseIntervention(item, ctx);
        if (!parsed) return null;
        interventions.push(parsed);
      }
      return {
        interventions,
        quickWin: isNonEmptyString(d.quickWin) ? limitWords(d.quickWin, 25) : null,
        confidence: clampNumber(d.confidence, 0, 1, 0.5),
      };
    },
    fallback: () => ({
      interventions: [
        {
          title: `Site inspection for recurring ${ctx.theme} issue`,
          description:
            `Field inspection of the reported ${ctx.theme} issue in this area ` +
            `to establish scope and cost, covering ${ctx.submissionCount} ` +
            "reports. Automated recommendations were unavailable.",
          interventionType: "service-delivery" as const,
          // No costing is offered rather than a placeholder — a fabricated
          // band would be indistinguishable from a real recommendation.
          costBandInr: {min: 0, max: 0, label: "₹ not estimated"},
          timelineWeeks: {min: 1, max: 3},
          impact: {
            householdsAddressed: null,
            peopleAddressed: null,
            rationale: "Not estimated — automated analysis unavailable.",
          },
          prerequisites: [],
          ownerHint: "municipal" as const,
        },
      ],
      quickWin: null,
      confidence: 0,
    }),
  });
}
