/**
 * Builds the training/eval data for the Gemma office router. NOT deployed.
 *
 *   npm run build:router-dataset                      # offline, rules + overrides
 *   GEMMA_API_KEY=... npm run build:router-dataset -- --translate 600
 *
 * Writes chat-format JSONL to `docs/router/{train,val,test}.jsonl` — the
 * exact prompt `suggestOffice` sends (without few-shot examples) and the
 * JSON answer — for the free Kaggle/Colab LoRA run in `ai/router-tune/`.
 *
 * Sources:
 *  - the hand-labelled `ROUTER_EXAMPLES`;
 *  - report templates × every Karnataka taluk, labelled by the directory
 *    rules — except "override" templates whose wording names a body the
 *    rules can't infer (national highway → NHAI, factory effluent → KSPCB),
 *    which is exactly what the model has to learn beyond the rules;
 *  - with `--translate N` and a free GEMMA_API_KEY, N summaries rewritten
 *    into the app's other languages, so routing is learnt for a Kannada or
 *    Hindi report too. Free-tier rate limits apply; it paces itself.
 *
 * Split 80/10/10, deterministically, so reruns give the same test set.
 */
import * as fs from "fs";
import * as path from "path";
import {DEPARTMENTS} from "../agents/departmentSeed";
import {ROUTER_EXAMPLES} from "../assignment/routerExamples";
import {
  SuggestInput,
  buildRouterPrompt,
  isUrban,
  officeCandidates,
} from "../assignment/suggestOffice";
import {GemmaClient} from "../lib/gemmaClient";

const OUT_DIR = path.resolve(__dirname, "../../../docs/router");
const translateArg = process.argv.indexOf("--translate");
const TRANSLATE_N = translateArg > 0 ? Number(process.argv[translateArg + 1]) || 0 : 0;

interface Template {
  theme: string;
  text: string;
  /** Wording that names an owner the rules can't infer. */
  override?: string;
}

const TEMPLATES: Template[] = [
  {theme: "roads", text: "Large potholes on the main road causing accidents"},
  {theme: "roads", text: "Road surface broken and full of mud after rain"},
  {theme: "roads", text: "National highway stretch damaged with no warning signs", override: "IN-NHAI"},
  {theme: "roads", text: "State highway between towns has crumbling edges", override: "KA-PWD"},
  {theme: "water", text: "No drinking water supply for several days"},
  {theme: "water", text: "Water pipeline leaking and wasting water on the street"},
  {theme: "water", text: "Dirty, smelly water coming from the taps"},
  {theme: "electricity", text: "Frequent power cuts and low voltage at night"},
  {theme: "electricity", text: "Transformer making noise and sparking near houses"},
  {theme: "electricity", text: "Electric wires hanging low over the road"},
  {theme: "health", text: "Health centre has no doctor and medicines are out of stock"},
  {theme: "health", text: "Ambulance did not come and hospital staff absent"},
  {theme: "sanitation", text: "Garbage piling up and not collected for many days"},
  {theme: "sanitation", text: "Drain blocked and dirty water overflowing on the road"},
  {theme: "sanitation", text: "Factory discharging chemical waste into the lake", override: "KA-KSPCB"},
  {theme: "education", text: "Government school building unsafe and teachers absent"},
  {theme: "education", text: "School has no drinking water or toilets for students"},
];

const LANGUAGES = ["Kannada", "Hindi", "Tamil", "Telugu", "Malayalam", "Marathi", "Bengali", "Gujarati", "Punjabi"];

interface Row {
  input: SuggestInput;
  label: string;
  reason: string;
}

function taluks(): Array<{talukName: string; districtId: string; districtName: string}> {
  const geo = JSON.parse(fs.readFileSync(
    path.resolve(__dirname, "../data/karnataka_taluks.json"), "utf-8"));
  return geo.features.map((f: {properties: Record<string, string>}) => ({
    talukName: f.properties.talukName,
    districtId: f.properties.districtId,
    districtName: f.properties.districtName,
  }));
}

/** Stable hash → split bucket, so the test set never drifts between runs. */
function bucket(key: string): "train" | "val" | "test" {
  let h = 2166136261;
  for (let i = 0; i < key.length; i++) h = Math.imul(h ^ key.charCodeAt(i), 16777619);
  const r = (h >>> 0) % 10;
  return r === 0 ? "test" : r === 1 ? "val" : "train";
}

function rulesRow(input: SuggestInput, override?: string): Row | null {
  const ranked = officeCandidates(DEPARTMENTS, input);
  if (!ranked.length) return null;
  const label = override && ranked.some((c) => c.doc.departmentId === override) ?
    override :
    ranked[0].doc.departmentId;
  const doc = DEPARTMENTS.find((d) => d.departmentId === label)!;
  const reason = override ?
    `The report names an asset owned by ${doc.shortName ?? doc.name}.` :
    `${doc.shortName ?? doc.name} handles ${input.theme} here.`;
  return {input, label, reason};
}

function toChat(row: Row): string {
  const candidates = officeCandidates(DEPARTMENTS, row.input).map((c) => c.doc);
  const urban = isUrban(DEPARTMENTS, row.input);
  return JSON.stringify({
    messages: [
      {role: "user", content: buildRouterPrompt(row.input, candidates, urban, false)},
      {role: "assistant", content: JSON.stringify({departmentId: row.label, confidence: 0.9, reason: row.reason})},
    ],
    // Kept beside the chat for per-theme/per-language accuracy in eval.
    meta: {theme: row.input.theme, label: row.label, district: row.input.districtName},
  });
}

async function main(): Promise<void> {
  const rows: Row[] = [];

  for (const e of ROUTER_EXAMPLES) {
    const [talukPart, districtName] = e.place.split(", ");
    rows.push({
      input: {
        theme: e.theme, summary: e.summary,
        talukName: talukPart.replace(/ taluk$/, ""), districtName,
        districtId: taluks().find((t) => t.districtName === districtName)?.districtId ?? null,
        inBengaluruWard: e.urban && districtName.startsWith("Bengaluru (Urban)"),
      },
      label: e.departmentId,
      reason: e.reason,
    });
  }

  for (const t of taluks()) {
    for (const tpl of TEMPLATES) {
      const bengaluru = t.districtId === "20" && /bangalore/i.test(t.talukName);
      const row = rulesRow({
        theme: tpl.theme, summary: tpl.text, ...t, inBengaluruWard: bengaluru,
      }, tpl.override);
      if (row) rows.push(row);
    }
  }

  if (TRANSLATE_N > 0) {
    const key = process.env.GEMMA_API_KEY;
    if (!key) throw new Error("--translate needs GEMMA_API_KEY in the environment");
    const gemma = new GemmaClient(key);
    const picked = rows.filter((_, i) => i % Math.max(1, Math.floor(rows.length / TRANSLATE_N)) === 0)
      .slice(0, TRANSLATE_N);
    let done = 0;
    for (const row of picked) {
      const language = LANGUAGES[done % LANGUAGES.length];
      try {
        const {text} = await gemma.generate(
          `Rewrite this civic complaint the way a resident would say it in ${language}, ` +
            `in ${language} script, one sentence, no names or numbers. Reply with the sentence only.\n\n` +
            row.input.summary,
        );
        if (text) rows.push({...row, input: {...row.input, summary: text.split("\n")[0]}});
      } catch (err) {
        console.warn(`translate failed (${language}):`, String(err).slice(0, 120));
      }
      done++;
      // Free tier is ~30 requests/minute.
      await new Promise((r) => setTimeout(r, 2200));
      if (done % 50 === 0) console.log(`translated ${done}/${picked.length}`);
    }
  }

  fs.mkdirSync(OUT_DIR, {recursive: true});
  const out = {train: [] as string[], val: [] as string[], test: [] as string[]};
  for (const row of rows) {
    const key = `${row.input.summary}|${row.input.talukName}|${row.input.theme}`;
    out[bucket(key)].push(toChat(row));
  }
  for (const [split, lines] of Object.entries(out)) {
    fs.writeFileSync(path.join(OUT_DIR, `${split}.jsonl`), lines.join("\n") + "\n");
  }
  const labels = new Map<string, number>();
  for (const r of rows) labels.set(r.label, (labels.get(r.label) ?? 0) + 1);
  console.log(`Wrote ${rows.length} examples → train ${out.train.length}, ` +
    `val ${out.val.length}, test ${out.test.length} in ${OUT_DIR}`);
  console.log("Label counts:", Object.fromEntries([...labels].sort((a, b) => b[1] - a[1])));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
