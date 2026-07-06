const CHAT_COMPLETIONS_URL = "https://integrate.api.nvidia.com/v1/chat/completions";

/**
 * NVIDIA's own document-understanding vision-language model (NIM catalog,
 * build.nvidia.com) — tuned specifically for accurate OCR/field extraction
 * from real-world document photos, which is why it's used here instead of a
 * general-purpose vision model.
 */
const VISION_MODEL = "nvidia/llama-3.1-nemotron-nano-vl-8b-v1";

/**
 * Thin wrapper over NVIDIA's OpenAI-compatible NIM chat completions endpoint
 * (build.nvidia.com), used only for Aadhaar OCR extraction — every other
 * AI task in this app (transcription, translation, photo captioning, theme
 * classification, cluster summarization) stays on `GeminiClient`. There is
 * no real fine-tuning here: this is a carefully engineered structured-
 * extraction prompt against a hosted model, the practical equivalent for an
 * app this size (true fine-tuning needs NVIDIA NeMo Customizer, a labeled
 * dataset, and a GPU training job — a separate, much larger effort).
 */
export class NvidiaClient {
  constructor(private readonly apiKey: string) {}

  /** Vision extraction for the Sign Up screen's Aadhaar upload. [backBase64]
   * is optional — the back side often carries the full address the front
   * truncates, so sending it (when captured) improves accuracy, but a
   * front-only call still works. Never echoes a 12-digit Aadhaar-number-
   * shaped string — the caller additionally regex-scrubs the response as
   * defense-in-depth. */
  async extractAadhaarFields(
    frontBase64: string,
    mimeType: string,
    backBase64?: string,
  ): Promise<{
    name?: string;
    address?: string;
    pincode?: string;
    wardNumber?: string;
    confidence: number;
  }> {
    const prompt = `You are reading photos of an Indian Aadhaar card (front${
      backBase64 ? ", and back" : ""
    }). Extract ONLY the holder's name, their printed address, their 6-digit
pincode, and their ward number if printed anywhere on the card (often on the
back, may be absent). Respond with strict JSON: {"name": string|null,
"address": string|null, "pincode": string|null, "wardNumber": string|null,
"confidence": number between 0 and 1}.
Never include the 12-digit Aadhaar number in your response, even partially.
If the image(s) are unclear or not an Aadhaar card, return nulls and
confidence 0.`;

    const content: Array<Record<string, unknown>> = [
      {type: "text", text: prompt},
      {
        type: "image_url",
        image_url: {url: `data:${mimeType};base64,${frontBase64}`},
      },
    ];
    if (backBase64) {
      content.push({
        type: "image_url",
        image_url: {url: `data:${mimeType};base64,${backBase64}`},
      });
    }

    const response = await fetch(CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: VISION_MODEL,
        messages: [{role: "user", content}],
        max_tokens: 400,
      }),
    });

    if (!response.ok) {
      throw new Error(
        `NVIDIA NIM request failed: ${response.status} ${await response.text()}`,
      );
    }

    const json = (await response.json()) as {
      choices?: Array<{message?: {content?: string}}>;
    };
    const text = json.choices?.[0]?.message?.content ?? "";
    const parsed = safeParseJson(text) ?? {};

    // Defense-in-depth: strip anything that looks like an Aadhaar number
    // even if the model ignored the instruction not to include one.
    const scrub = (value: unknown) =>
      typeof value === "string"
        ? value.replace(/\d{4}\s?\d{4}\s?\d{4}/g, "[redacted]")
        : undefined;

    return {
      name: scrub(parsed.name),
      address: scrub(parsed.address),
      pincode: typeof parsed.pincode === "string" ? parsed.pincode : undefined,
      wardNumber:
        typeof parsed.wardNumber === "string" ? parsed.wardNumber : undefined,
      confidence: typeof parsed.confidence === "number" ? parsed.confidence : 0,
    };
  }
}

function safeParseJson(text: string): any {
  try {
    const cleaned = text.replace(/```json|```/g, "").trim();
    return JSON.parse(cleaned);
  } catch {
    return null;
  }
}
