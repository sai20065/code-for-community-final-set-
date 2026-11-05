"""QLoRA fine-tune of Gemma for the Prajadhwani office router — free GPU.

Runs on a free Kaggle notebook (T4 x2 / P100, ~30 h/week) or Colab free T4.
In a notebook cell:

    !pip install -q "unsloth" "trl>=0.12" datasets
    !python train_router_lora.py --data /kaggle/input/prajadhwani-router \
        --out /kaggle/working/router-lora

`--data` is a folder holding train.jsonl and val.jsonl from
`npm run build:router-dataset` (docs/router/), uploaded as a Kaggle dataset.

The adapter is small (~50-100 MB) and is evaluated with eval_router.py. It
is *not* served in production: there is no free 24/7 host for a tuned
model, so the app keeps using hosted Gemma with few-shot examples and the
eval numbers are what this run is for.
"""
import argparse
import json
import os

parser = argparse.ArgumentParser()
parser.add_argument("--data", required=True)
parser.add_argument("--out", default="router-lora")
# Tried in order — the first that loads is used.
parser.add_argument("--models", default="unsloth/gemma-4-E4B-it,unsloth/gemma-3-4b-it")
parser.add_argument("--epochs", type=float, default=2)
parser.add_argument("--max-len", type=int, default=1536)
args = parser.parse_args()

from unsloth import FastLanguageModel  # noqa: E402  (import after argparse for fast --help)
from datasets import load_dataset  # noqa: E402
from trl import SFTConfig, SFTTrainer  # noqa: E402

model = tokenizer = None
for model_id in args.models.split(","):
    try:
        model, tokenizer = FastLanguageModel.from_pretrained(
            model_name=model_id.strip(), max_seq_length=args.max_len, load_in_4bit=True)
        print("Loaded", model_id)
        break
    except Exception as err:  # noqa: BLE001 — try the next id
        print("Could not load", model_id, "-", err)
if model is None:
    raise SystemExit("No base model could be loaded")

model = FastLanguageModel.get_peft_model(
    model, r=16, lora_alpha=16, lora_dropout=0,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    use_gradient_checkpointing="unsloth", random_state=42)

data = load_dataset("json", data_files={
    "train": os.path.join(args.data, "train.jsonl"),
    "val": os.path.join(args.data, "val.jsonl"),
})


def to_text(row):
    return {"text": tokenizer.apply_chat_template(row["messages"], tokenize=False)}


data = data.map(to_text, remove_columns=["messages", "meta"])

trainer = SFTTrainer(
    model=model, tokenizer=tokenizer,
    train_dataset=data["train"], eval_dataset=data["val"],
    args=SFTConfig(
        output_dir=args.out, dataset_text_field="text", max_seq_length=args.max_len,
        per_device_train_batch_size=4, gradient_accumulation_steps=4,
        num_train_epochs=args.epochs, learning_rate=2e-4, warmup_ratio=0.05,
        logging_steps=20, eval_strategy="epoch", save_strategy="epoch",
        fp16=True, report_to="none", seed=42),
)
stats = trainer.train()
model.save_pretrained(args.out)
tokenizer.save_pretrained(args.out)
with open(os.path.join(args.out, "train_stats.json"), "w") as f:
    json.dump({"base_model": model_id, **stats.metrics}, f, indent=2)
print("Saved adapter to", args.out)
