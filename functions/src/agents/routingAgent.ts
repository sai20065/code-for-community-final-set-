import {AgentClient, isNonEmptyString, limitWords} from "./agentClient";
import {DepartmentDoc, resolveDepartment, toRef} from "./departmentDirectory";
import {
  AgentMessage,
  AgentTurn,
  ClusterContext,
  JurisdictionLevel,
  RootCauseOutput,
  RoutingOutput,
  SolutionOutput,
} from "./types";

const SYSTEM_ROLE = `You decide which TIER of Indian government is responsible
for fixing a civic problem. That is your only task.

- "municipal": the city corporation or a city utility board handles it —
  local roads, ward drains, city water supply, garbage, street lighting,
  primary health centres.
- "state": a state department or state utility handles it — highways and
  arterial roads outside city limits, transmission-level power, district
  hospitals, school education, pollution control, water supply outside the
  city corporation's area.
- "central": a central ministry handles it — national highways, railways,
  central schemes, or cases where the state has no jurisdiction.

Prefer "municipal" when the issue is plainly local and the location is
inside a city. Escalate only when the physical asset genuinely belongs to a
higher tier.

Do NOT name any department, phone number, email address or website. You are
not being asked for one and you do not have that information.`;

const SCHEMA_HINT = `Respond with ONLY this JSON object:
{
  "jurisdictionLevel": "municipal" | "state" | "central",
  "rationale": string (at most 25 words, explaining which tier owns the asset)
}`;

const VALID_LEVELS: JurisdictionLevel[] = ["municipal", "state", "central"];

/**
 * Agent 3. Routes a cluster to the MP and the responsible department.
 *
 * Structurally different from the other three: the *answer* comes from a
 * deterministic table (`departmentDirectory.ts`), and the model contributes
 * exactly one enum plus a sentence of justification. Contact details are
 * therefore non-hallucinable by construction rather than by instruction —
 * which matters, because a citizen who calls a fabricated grievance number
 * and gets nowhere loses trust in every other part of this report too.
 */
export async function runRoutingAgent(
  client: AgentClient,
  ctx: ClusterContext,
  contextText: string,
  directory: DepartmentDoc[],
  rootCause: RootCauseOutput,
  solutions: SolutionOutput,
): Promise<{output: RoutingOutput; turn: AgentTurn}> {
  const history: AgentMessage[] = [
    {role: "user", text: contextText},
    {
      role: "model",
      text: JSON.stringify({
        rootCauseSummary: rootCause.rootCauseSummary,
        causalChain: rootCause.causalChain,
      }),
    },
    {
      role: "model",
      text: JSON.stringify({
        interventions: solutions.interventions.map((i) => ({
          title: i.title,
          interventionType: i.interventionType,
          ownerHint: i.ownerHint,
        })),
      }),
    },
  ];

  const {output: level, turn} = await client.run<{
    jurisdictionLevel: JurisdictionLevel;
    rationale: string;
  }>({
    agent: "routing",
    systemRole: SYSTEM_ROLE,
    history,
    userPrompt:
      `Location: ${ctx.city ?? "unknown city"}, ${ctx.state ?? "unknown state"}. ` +
      `Theme: ${ctx.theme}. ` +
      "Which tier of government owns the asset that needs fixing?",
    schemaHint: SCHEMA_HINT,
    validate: (raw) => {
      const d = raw as Record<string, unknown>;
      if (!VALID_LEVELS.includes(d.jurisdictionLevel as JurisdictionLevel)) {
        return null;
      }
      return {
        jurisdictionLevel: d.jurisdictionLevel as JurisdictionLevel,
        rationale: isNonEmptyString(d.rationale) ?
          limitWords(d.rationale, 30) :
          "",
      };
    },
    // Falls back to the Solution agent's own view of who owns the work,
    // then to municipal — the tier that handles the large majority of the
    // issues this app collects.
    fallback: () => ({
      jurisdictionLevel:
        solutions.interventions[0]?.ownerHint ?? ("municipal" as const),
      rationale: "Tier inferred from the proposed intervention type.",
    }),
  });

  const resolved = resolveDepartment(directory, {
    theme: ctx.theme,
    state: ctx.state,
    city: ctx.city,
    preferredLevel: level.jurisdictionLevel,
  });

  const mp = {
    constituencyId: ctx.constituencyId,
    constituencyName: ctx.constituencyName,
    mpName: ctx.mpName,
  };

  if (!resolved) {
    // No directory entry at all — usually an unseeded `departments`
    // collection. Say so plainly rather than inventing a plausible
    // department name to fill the field.
    return {
      output: {
        jurisdictionLevel: level.jurisdictionLevel,
        jurisdictionRationale: level.rationale,
        primary: {
          departmentId: "unresolved",
          name: "Department not yet mapped for this area",
          shortName: null,
          jurisdictionLevel: level.jurisdictionLevel,
          email: null,
          phone: null,
          grievancePortalUrl: null,
        },
        escalation: null,
        mp,
        matchQuality: "national-fallback",
      },
      turn,
    };
  }

  return {
    output: {
      jurisdictionLevel: level.jurisdictionLevel,
      jurisdictionRationale: level.rationale,
      primary: toRef(resolved.primary),
      escalation: resolved.escalation ? toRef(resolved.escalation) : null,
      mp,
      matchQuality: resolved.matchQuality,
    },
    turn,
  };
}
