import {SdgMapping} from "./types";

/**
 * UN Sustainable Development Goal alignment for each civic theme.
 *
 * Deterministic on purpose. The mapping from "waterlogged street" to SDG 6.1
 * is a matter of published fact, not judgement, and a model asked to produce
 * goal *numbers* will occasionally produce confident nonsense (SDG 6 is
 * Clean Water; SDG 16 is not). The agent's contribution is limited to the
 * `rationale` prose, where being wrong is visible and cheap.
 *
 * Targets, not just goals: "this relates to SDG 6" is close to decorative,
 * whereas "SDG 6.1 — universal and equitable access to safe drinking water"
 * is something a district reporting framework can actually consume.
 */
const GOAL_NAMES: Record<number, string> = {
  3: "Good Health and Well-being",
  4: "Quality Education",
  6: "Clean Water and Sanitation",
  7: "Affordable and Clean Energy",
  9: "Industry, Innovation and Infrastructure",
  11: "Sustainable Cities and Communities",
  13: "Climate Action",
};

interface BaseMapping {
  goal: number;
  targets: string[];
  rationale: string;
}

const THEME_SDG: Record<string, BaseMapping[]> = {
  water: [
    {
      goal: 6,
      targets: ["6.1", "6.4", "6.b"],
      rationale:
        "Safe and reliable drinking water access, water-use efficiency, and " +
        "community participation in local water management.",
    },
  ],
  sanitation: [
    {
      goal: 6,
      targets: ["6.2", "6.3"],
      rationale:
        "Adequate sanitation and reduced untreated wastewater discharge.",
    },
    {
      goal: 11,
      targets: ["11.6"],
      rationale:
        "Reducing the adverse environmental impact of cities, including " +
        "municipal waste management.",
    },
  ],
  roads: [
    {
      goal: 9,
      targets: ["9.1"],
      rationale:
        "Reliable and resilient local infrastructure supporting economic " +
        "development and wellbeing.",
    },
    {
      goal: 11,
      targets: ["11.2"],
      rationale:
        "Safe, affordable and accessible transport systems for all, " +
        "including vulnerable road users.",
    },
  ],
  health: [
    {
      goal: 3,
      targets: ["3.8"],
      rationale:
        "Universal health coverage, including access to quality essential " +
        "services and affordable medicines.",
    },
  ],
  education: [
    {
      goal: 4,
      targets: ["4.1", "4.a"],
      rationale:
        "Free, equitable and quality primary and secondary education, in " +
        "facilities that provide a safe and effective learning environment.",
    },
  ],
  electricity: [
    {
      goal: 7,
      targets: ["7.1", "7.b"],
      rationale:
        "Universal access to affordable, reliable and modern energy " +
        "services, and infrastructure upgrades to supply them.",
    },
  ],
};

/** Climate-resilience overlay for monsoon-driven issues.
 *
 * Applied by rule rather than by the model: a drain that fails every single
 * monsoon is a climate-adaptation problem regardless of how the causal
 * summary happens to be worded, and that framing is often what unlocks a
 * different funding line. */
const CLIMATE_MAPPING: BaseMapping = {
  goal: 13,
  targets: ["13.1"],
  rationale:
    "Strengthening resilience and adaptive capacity to climate-related " +
    "hazards — this issue recurs with the monsoon season.",
};

export function sdgForTheme(
  theme: string,
  options: {monsoonDriven?: boolean} = {},
): SdgMapping[] {
  const base = THEME_SDG[theme] ?? [
    {
      goal: 11,
      targets: ["11.3"],
      rationale:
        "Inclusive and sustainable urbanisation with participatory planning.",
    },
  ];

  const mappings = [...base];
  if (options.monsoonDriven) mappings.push(CLIMATE_MAPPING);

  return mappings.map((m) => ({
    goal: m.goal,
    goalName: GOAL_NAMES[m.goal] ?? `SDG ${m.goal}`,
    targets: m.targets,
    rationale: m.rationale,
  }));
}

/** Merges agent-supplied rationale prose into the deterministic mapping.
 *
 * The agent may make a rationale more specific to this cluster; it may not
 * introduce a goal, remove one, or change a target. Anything it invents is
 * silently ignored rather than merged, so the goal set on a Solution Card is
 * always exactly what the table says it should be.
 */
export function mergeSdgRationales(
  base: SdgMapping[],
  agentSupplied: unknown,
): SdgMapping[] {
  if (!Array.isArray(agentSupplied)) return base;
  const byGoal = new Map<number, string>();
  for (const entry of agentSupplied) {
    if (typeof entry !== "object" || entry === null) continue;
    const {goal, rationale} = entry as Record<string, unknown>;
    if (typeof goal === "number" && typeof rationale === "string" && rationale.trim()) {
      byGoal.set(goal, rationale.trim());
    }
  }
  return base.map((m) => ({
    ...m,
    rationale: byGoal.get(m.goal) ?? m.rationale,
  }));
}
