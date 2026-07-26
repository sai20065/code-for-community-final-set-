import {
  AgentClient,
  clampNumber,
  isNonEmptyString,
  limitWords,
  stringArray,
} from "./agentClient";
import {AgentTurn, Citation, ClusterContext, RootCauseOutput} from "./types";

const SYSTEM_ROLE = `You are a municipal engineering analyst for an Indian Lok
Sabha constituency. Your job is to explain WHY a recurring civic problem keeps
happening — the underlying cause, not a restatement of what was reported.

HARD RULES:
1. Every entry in "claims" MUST carry at least one citation. A citation is
   either a ticket token id taken verbatim from the TICKETS list, or the name
   of a statistic from the STATISTICS list (e.g. "monsoonShare").
2. Never cite a token id that does not appear in the TICKETS list. Inventing
   one invalidates your entire answer.
3. If the data does not support a causal explanation, SAY SO. Put what is
   missing in "dataGaps" and lower your "confidence". A short honest answer
   is worth more than a confident invented one — an engineer who knows this
   neighbourhood will read it.
4. Never mention any person's name, house number, street address, phone
   number or pincode. You have not been given any; do not infer any.
5. Reason about mechanism: drainage gradients, supply intermittency, load
   growth versus transformer capacity, staffing ratios, catchment distance,
   deferred maintenance cycles, seasonality. Not "citizens are unhappy".`;

const SCHEMA_HINT = `Respond with ONLY this JSON object:
{
  "rootCauseSummary": string (at most 60 words, explains WHY),
  "causalChain": string[] (2-5 ordered contributing factors, upstream first),
  "claims": [{"claim": string, "citations": [{"tokenId": string} or {"stat": string, "value": string}]}],
  "seasonality": "monsoon-driven" | "summer-driven" | "year-round" | "unclear",
  "dataGaps": string[] (what you could NOT determine),
  "confidence": number between 0 and 1
}`;

function parseCitations(raw: unknown, knownTokens: Set<string>): Citation[] | null {
  if (!Array.isArray(raw) || raw.length === 0) return null;
  const citations: Citation[] = [];
  for (const item of raw) {
    if (typeof item !== "object" || item === null) continue;
    const {tokenId, stat, value} = item as Record<string, unknown>;
    if (isNonEmptyString(tokenId)) {
      // The anti-hallucination gate. A model that cannot find real evidence
      // will happily manufacture a plausible-looking token id, and a cited
      // claim reads as verified whether or not the citation is real — so
      // this is checked in code rather than asked for in the prompt.
      if (!knownTokens.has(tokenId)) return null;
      citations.push({tokenId});
    } else if (isNonEmptyString(stat)) {
      citations.push({
        stat,
        value: isNonEmptyString(value) ? value : undefined,
      });
    }
  }
  return citations.length ? citations : null;
}

/**
 * Agent 1. Reasons about why an issue recurs, grounded in cited evidence.
 *
 * Its fallback is deliberately thin — a statistical restatement with
 * `confidence: 0` and an explicit note that no analysis was produced.
 * Fabricating a plausible causal story on failure would be far worse than
 * an obviously empty one, because the failure would be invisible.
 */
export async function runRootCauseAgent(
  client: AgentClient,
  ctx: ClusterContext,
  contextText: string,
): Promise<{output: RootCauseOutput; turn: AgentTurn}> {
  const knownTokens = new Set(ctx.knownTokenIds);

  return client.run<RootCauseOutput>({
    agent: "rootCause",
    systemRole: SYSTEM_ROLE,
    history: [],
    userPrompt:
      `${contextText}\n\n` +
      "Explain why this problem keeps recurring in this specific area. " +
      "Ground every claim in the tickets or statistics above.",
    schemaHint: SCHEMA_HINT,
    validate: (raw) => {
      const data = raw as Record<string, unknown>;
      if (!isNonEmptyString(data.rootCauseSummary)) return null;

      const claimsRaw = data.claims;
      if (!Array.isArray(claimsRaw) || claimsRaw.length === 0) return null;

      const claims: RootCauseOutput["claims"] = [];
      for (const entry of claimsRaw.slice(0, 6)) {
        if (typeof entry !== "object" || entry === null) return null;
        const {claim, citations} = entry as Record<string, unknown>;
        if (!isNonEmptyString(claim)) return null;
        const parsed = parseCitations(citations, knownTokens);
        // An uncited claim fails the whole response rather than being
        // quietly dropped: silently discarding it would leave a summary
        // asserting something no surviving claim supports.
        if (!parsed) return null;
        claims.push({claim: claim.trim(), citations: parsed});
      }

      const seasonality = ["monsoon-driven", "summer-driven", "year-round", "unclear"]
        .includes(data.seasonality as string) ?
        (data.seasonality as RootCauseOutput["seasonality"]) :
        "unclear";

      return {
        rootCauseSummary: limitWords(data.rootCauseSummary, 70),
        causalChain: stringArray(data.causalChain, 6),
        claims,
        seasonality,
        dataGaps: stringArray(data.dataGaps, 6),
        confidence: clampNumber(data.confidence, 0, 1, 0.5),
      };
    },
    fallback: () => ({
      rootCauseSummary:
        `${ctx.submissionCount} ${ctx.theme} reports from ` +
        `${ctx.uniqueReporterCount} residents in this area. Automated causal ` +
        "analysis was unavailable for this cluster.",
      causalChain: [],
      claims: [],
      seasonality:
        ctx.monsoonShare >= 0.6 ? "monsoon-driven" : "unclear",
      dataGaps: [
        "Automated root-cause analysis did not complete for this cluster.",
      ],
      confidence: 0,
    }),
  });
}
