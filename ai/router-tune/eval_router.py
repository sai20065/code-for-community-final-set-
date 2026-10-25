"""Scores a router (tuned adapter or base model) on docs/router/test.jsonl.

    !python eval_router.py --data /kaggle/input/prajadhwani-router \
        --model /kaggle/working/router-lora --report eval_v1.md

Reports top-1 department accuracy overall, per theme and on Indic-script
reports, plus how often the reply was not a usable candidate id (the case
where production falls back to the rules). Targets from the concept
document: >= 90% accuracy, <= 15% unusable.
"""
import argparse
import collections
import json
import os
import re

parser = argparse.ArgumentParser()
parser.add_argument("--data", required=True)
parser.add_argument("--model", required=True, help="adapter folder or base model id")
parser.add_argument("--limit", type=int, default=0)
parser.add_argument("--report", default="eval_report.md")
args = parser.parse_args()

from unsloth import FastLanguageModel  # noqa: E402

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=args.model, max_seq_length=1536, load_in_4bit=True)
FastLanguageModel.for_inference(model)

rows = [json.loads(line) for line in open(os.path.join(args.data, "test.jsonl"), encoding="utf-8") if line.strip()]
if args.limit:
    rows = rows[: args.limit]

INDIC = re.compile(r"[ऀ-෿਀-૿]")
total = correct = unusable = 0
by_theme = collections.defaultdict(lambda: [0, 0])
indic = [0, 0]

for row in rows:
    prompt = row["messages"][0]["content"]
    ids = re.findall(r"^- ([A-Z0-9-]+):", prompt, flags=re.M)
    inputs = tokenizer.apply_chat_template(
        [{"role": "user", "content": prompt}], add_generation_prompt=True, return_tensors="pt").to(model.device)
    out = model.generate(input_ids=inputs, max_new_tokens=80, do_sample=False)
    reply = tokenizer.decode(out[0][inputs.shape[1]:], skip_special_tokens=True)
    match = re.search(r"\{.*\}", reply, flags=re.S)
    picked = None
    if match:
        try:
            picked = json.loads(match.group(0)).get("departmentId")
        except json.JSONDecodeError:
            pass
    ok = picked == row["meta"]["label"]
    total += 1
    correct += ok
    unusable += picked not in ids
    by_theme[row["meta"]["theme"]][0] += ok
    by_theme[row["meta"]["theme"]][1] += 1
    report_text = prompt.split('Report: "')[-1]
    if INDIC.search(report_text):
        indic[0] += ok
        indic[1] += 1

pct = lambda a, b: f"{100 * a / b:.1f}%" if b else "n/a"  # noqa: E731
lines = [
    f"# Router eval — {args.model}",
    "",
    f"- Test examples: {total}",
    f"- Top-1 department accuracy: **{pct(correct, total)}** (target >= 90%)",
    f"- Unusable replies (rules fallback): {pct(unusable, total)} (target <= 15%)",
    f"- Indic-script reports: {pct(*indic)} of {indic[1]}",
    "",
    "| Theme | Accuracy | n |",
    "|---|---|---|",
    *[f"| {t} | {pct(c, n)} | {n} |" for t, (c, n) in sorted(by_theme.items())],
]
open(args.report, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("\n".join(lines))
