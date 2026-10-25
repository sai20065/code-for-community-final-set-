# Office router: free training

What the app does in production, and what this folder is for.

**In production (free).** `functions/src/assignment/suggestOffice.ts` builds a shortlist of real offices from the directory. Hosted Gemma, on the free Gemini API with the `GEMMA_API_KEY` secret, then picks one id from that shortlist, guided by few-shot examples. If the call fails or the reply can't be used, the rules' first choice is used. The email and website always come from the directory, never from the model.

**This folder (free, optional).** It fine-tunes a small Gemma with LoRA on the router dataset, using a free Kaggle or Colab GPU, and measures accuracy. A tuned model has no free 24/7 host, so it isn't served. The eval report is the deliverable, and the adapter can be served later on the lab PARAM Shavak.

## Steps
1. Build the data: `cd functions && npm run build:router-dataset`. This writes `docs/router/{train,val,test}.jsonl`.
   - Add `-- --translate 600` with `GEMMA_API_KEY` set to add Indic-language reports. It is free and takes about 25 minutes.
2. In Kaggle, go to **Datasets → New** and upload the three `.jsonl` files as `prajadhwani-router`.
3. Open a new notebook, set **Accelerator: GPU T4 x2**, add the dataset, and upload these two `.py` files.
4. Install the libraries:
   ```
   !pip install -q unsloth "trl>=0.12" datasets
   ```
5. Train (about 1–2 hours on a T4; the free quota is about 30 hours a week):
   ```
   !python train_router_lora.py --data /kaggle/input/prajadhwani-router --out /kaggle/working/router-lora
   ```
6. Evaluate the tuned adapter:
   ```
   !python eval_router.py --data /kaggle/input/prajadhwani-router --model /kaggle/working/router-lora --report eval_v1.md
   ```
7. For a baseline, run `eval_router.py` again with `--model unsloth/gemma-4-E4B-it`.
8. Copy `eval_v1.md` into `docs/router/`.

The cost of all of this is ₹0.
