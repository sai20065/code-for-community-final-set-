import {GoogleGenerativeAI} from "@google/generative-ai";
import {GEMMA_MODELS} from "../config";

/**
 * Gemma on the free Gemini Developer API (see `gemmaApiKey` in config.ts).
 *
 * Gemma there takes no system instruction and has no JSON mode, so callers
 * put everything in one prompt and parse the reply with [parseJsonObject].
 */
export class GemmaClient {
  private readonly genAI: GoogleGenerativeAI;
  /** The first model id the API accepted, reused for the instance's life. */
  private workingModel: string | null = null;

  constructor(apiKey: string, private readonly models: string[] = GEMMA_MODELS) {
    this.genAI = new GoogleGenerativeAI(apiKey);
  }

  async generate(
    prompt: string,
    timeoutMs = 20000,
  ): Promise<{text: string; modelId: string}> {
    const ids = this.workingModel ? [this.workingModel] : this.models;
    let lastError: unknown;
    for (const id of ids) {
      try {
        const model = this.genAI.getGenerativeModel(
          {model: id, generationConfig: {temperature: 0.1, maxOutputTokens: 300}},
          {timeout: timeoutMs},
        );
        const result = await model.generateContent(prompt);
        this.workingModel = id;
        return {text: result.response.text().trim(), modelId: id};
      } catch (err) {
        lastError = err;
        // Only an unknown model id moves on to the next one — a quota or
        // network error would fail the same way on every id.
        if (!/404|not found/i.test(String(err))) throw err;
      }
    }
    throw lastError;
  }
}

/** The first `{...}` object in [text], tolerating ```json fences and prose
 * around it. Null when there is none or it doesn't parse. */
export function parseJsonObject(text: string): Record<string, unknown> | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const value = JSON.parse(text.slice(start, end + 1));
    return value && typeof value === "object" && !Array.isArray(value) ?
      value as Record<string, unknown> :
      null;
  } catch {
    return null;
  }
}
