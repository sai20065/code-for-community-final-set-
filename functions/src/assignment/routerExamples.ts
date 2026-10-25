/**
 * Hand-labelled routing examples. Shown to Gemma as few-shot examples for
 * the same theme (the free hosted model can't be fine-tuned, so this is how
 * it learns the directory's conventions), and the seed set the router
 * training dataset grows from (`scripts/buildRouterDataset.ts`).
 *
 * Every summary is PII-free in the same way `publicSummary` is: no names,
 * numbers or addresses.
 */
export interface RouterExample {
  summary: string;
  theme: string;
  place: string;
  urban: boolean;
  departmentId: string;
  reason: string;
}

export const ROUTER_EXAMPLES: RouterExample[] = [
  {
    summary: "Deep potholes on a ward road near the market, two-wheelers falling at night",
    theme: "roads", place: "Bangalore-South taluk, Bengaluru (Urban)", urban: true,
    departmentId: "KA-GBA-BBMP", reason: "Ward road inside Bengaluru is maintained by the city corporation.",
  },
  {
    summary: "Village approach road washed out after rain, school bus cannot reach",
    theme: "roads", place: "Malavalli taluk, Mandya", urban: false,
    departmentId: "KA-RDPR", reason: "Village roads are a Gram Panchayat responsibility under RDPR.",
  },
  {
    summary: "State highway between two towns has broken shoulders and no signboards",
    theme: "roads", place: "Hassan taluk, Hassan", urban: false,
    departmentId: "KA-PWD", reason: "State highways between towns are maintained by the PWD.",
  },
  {
    summary: "National highway service road flooded and toll plaza lighting not working",
    theme: "roads", place: "Nelamangala taluk, Bengaluru (Rural)", urban: false,
    departmentId: "IN-NHAI", reason: "National highway assets belong to NHAI.",
  },
  {
    summary: "Road dug for pipeline left open for weeks in the city area",
    theme: "roads", place: "Hubballi Nagara taluk, Dharwad", urban: true,
    departmentId: "KA-HDMC", reason: "City roads in Hubballi are maintained by HDMC.",
  },
  {
    summary: "No drinking water supply in the layout for four days, pipeline leaking",
    theme: "water", place: "Bangalore (North) taluk, Bengaluru (Urban)", urban: true,
    departmentId: "KA-BWSSB", reason: "Piped water in Bengaluru is supplied by BWSSB.",
  },
  {
    summary: "Village borewell motor burnt, women walking far for water",
    theme: "water", place: "Pavagada taluk, Tumakuru", urban: false,
    departmentId: "KA-RDWSD", reason: "Rural drinking water schemes are run by RDWSD.",
  },
  {
    summary: "Contaminated tap water with bad smell in the town ward",
    theme: "water", place: "Belagavi taluk, Belagavi", urban: true,
    departmentId: "KA-BELAGAVI-CC", reason: "Town water inside Belagavi city is the corporation's responsibility.",
  },
  {
    summary: "Streetlights off on the main road for a week and frequent power cuts",
    theme: "electricity", place: "Mysuru taluk, Mysuru", urban: true,
    departmentId: "KA-CESC", reason: "Mysuru district electricity supply is CESC's area.",
  },
  {
    summary: "Transformer sparking near the bus stand, low voltage in houses",
    theme: "electricity", place: "Gangavathi taluk, Koppal", urban: false,
    departmentId: "KA-GESCOM", reason: "Koppal district distribution is handled by GESCOM.",
  },
  {
    summary: "Electric pole leaning dangerously after storm near the temple",
    theme: "electricity", place: "Udupi taluk, Udupi", urban: false,
    departmentId: "KA-MESCOM", reason: "Udupi district is in MESCOM's service area.",
  },
  {
    summary: "Primary health centre has no doctor in the evenings and no medicines",
    theme: "health", place: "Sira taluk, Tumakuru", urban: false,
    departmentId: "KA-HFW", reason: "PHCs outside the city are run by the state health department.",
  },
  {
    summary: "Mosquito breeding in stagnant drain water causing dengue cases in the ward",
    theme: "health", place: "Bangalore-East taluk, Bengaluru (Urban)", urban: true,
    departmentId: "KA-GBA-BBMP", reason: "Vector control in Bengaluru wards is done by the corporation's health wing.",
  },
  {
    summary: "Government school roof leaking and no toilets for girls",
    theme: "education", place: "Aland taluk, Kalburgi", urban: false,
    departmentId: "KA-DDPI", reason: "Government schools are run by the School Education department.",
  },
  {
    summary: "Garbage not collected for ten days, burning of waste on the street",
    theme: "sanitation", place: "Bangalore (North) taluk, Bengaluru (Urban)", urban: true,
    departmentId: "KA-GBA-BBMP", reason: "Solid waste collection in Bengaluru is the corporation's job.",
  },
  {
    summary: "Open drain overflowing into houses in the village after rain",
    theme: "sanitation", place: "Kunigal taluk, Tumakuru", urban: false,
    departmentId: "KA-RDPR", reason: "Village drains are maintained by the Gram Panchayat.",
  },
  {
    summary: "Factory releasing foul effluent into the lake, fish dying",
    theme: "sanitation", place: "Anekal taluk, Bengaluru (Urban)", urban: false,
    departmentId: "KA-KSPCB", reason: "Industrial pollution is regulated by the Pollution Control Board.",
  },
  {
    summary: "Underground sewer line blocked and overflowing on the road",
    theme: "sanitation", place: "Bangalore-South taluk, Bengaluru (Urban)", urban: true,
    departmentId: "KA-BWSSB", reason: "Sewerage in Bengaluru is BWSSB's responsibility.",
  },
];

/** Up to [limit] examples for [theme], urban/rural matches first, so the
 * model sees the cases most like the one it is routing. */
export function examplesFor(
  theme: string | null,
  urban: boolean,
  limit = 6,
): RouterExample[] {
  return ROUTER_EXAMPLES
    .filter((e) => e.theme === theme)
    .sort((a, b) => Number(b.urban === urban) - Number(a.urban === urban))
    .slice(0, limit);
}
