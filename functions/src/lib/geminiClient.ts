import {GoogleGenerativeAI} from "@google/generative-ai";
import {THEME_IDS, ThemeId} from "../config";

/**
 * Thin wrapper over the Gemini Developer API (aistudio.google.com key, not
 * Vertex AI Model Garden) — used for every "Gemma-family" AI task in this
 * app: Aadhaar OCR extraction, photo identification, theme classification,
 * and cluster summarization/priority scoring.
 */
export class GeminiClient {
  private readonly genAI: GoogleGenerativeAI;

  constructor(apiKey: string) {
    this.genAI = new GoogleGenerativeAI(apiKey);
  }

  /** Vision extraction for the Aadhaar upload screen. Never echoes a
   * 12-digit Aadhaar-number-shaped string — the caller additionally
   * regex-scrubs the response as defense-in-depth. */
  async extractAadhaarFields(
    imageBase64: string,
    mimeType: string,
  ): Promise<{name?: string; address?: string; pincode?: string; confidence: number}> {
    const model = this.genAI.getGenerativeModel({model: "gemini-2.5-flash"});
    const prompt = `You are reading an Indian Aadhaar card photo. Extract ONLY the
holder's name, their printed address, and their 6-digit pincode.
Respond with strict JSON: {"name": string|null, "address": string|null,
"pincode": string|null, "confidence": number between 0 and 1}.
Never include the 12-digit Aadhaar number in your response, even partially.
If the image is unclear or not an Aadhaar card, return nulls and confidence 0.`;

    const result = await model.generateContent([
      prompt,
      {inlineData: {data: imageBase64, mimeType}},
    ]);
    const text = result.response.text();
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
      confidence: typeof parsed.confidence === "number" ? parsed.confidence : 0,
    };
  }

  /** Transcribes voice-ticket audio verbatim in its own spoken language —
   * replaces the Bhashini ASR step. Translation to English is a separate,
   * subsequent step (see `TranslateClient`), not done here. */
  async transcribeAudioBase64(
    audioBase64: string,
    mimeType: string,
    sourceLanguage: string,
  ): Promise<string> {
    const model = this.genAI.getGenerativeModel({model: "gemini-2.5-flash"});
    const result = await model.generateContent([
      "Transcribe this audio verbatim in its original spoken language " +
        `(expected: ${sourceLanguage}). Respond with ONLY the transcript ` +
        "text — no commentary, no translation, no extra formatting.",
      {inlineData: {data: audioBase64, mimeType}},
    ]);
    return result.response.text().trim();
  }

  /** Same as [transcribeAudioBase64], fetching the audio from a Storage
   * URL first (used by the Firestore-triggered pipeline, where the
   * function only has a `mediaUrl`, not raw bytes). */
  async transcribeAudioUrl(audioUrl: string, sourceLanguage: string): Promise<string> {
    const audio = await fetchAsBase64(audioUrl);
    return this.transcribeAudioBase64(audio.data, audio.mimeType, sourceLanguage);
  }

  /** One-line caption identifying the civic issue in a submitted photo
   * (pothole, garbage pile, waterlogging, downed wire, etc.). */
  async captionCivicPhoto(imageUrl: string): Promise<string> {
    const model = this.genAI.getGenerativeModel({model: "gemini-2.5-flash"});
    const imageBytes = await fetchAsBase64(imageUrl);
    const result = await model.generateContent([
      "In one short sentence, describe the civic issue shown in this photo " +
        "(e.g. road/pothole, water leakage, garbage, downed power line, " +
        "waterlogging). If nothing civic-related is visible, say so plainly.",
      {inlineData: {data: imageBytes.data, mimeType: imageBytes.mimeType}},
    ]);
    return result.response.text().trim();
  }

  /** Classifies a ticket's text/caption into one of the app's 6 category
   * ids, and suggests whether it looks like a duplicate of an existing
   * cluster summary. Only called when the citizen didn't already pick a
   * theme manually — AI never overwrites a citizen's own choice. */
  async classifyTicket(input: {
    text: string;
    existingClusterSummaries: string[];
  }): Promise<{theme: ThemeId; priorityHint: number}> {
    const model = this.genAI.getGenerativeModel({model: "gemini-2.5-flash"});
    const prompt = `Classify this civic ticket into exactly one of these
categories: ${THEME_IDS.join(", ")}.
Also give a priorityHint from 1 (minor) to 5 (urgent/safety-critical).
Ticket: "${input.text}"
${
  input.existingClusterSummaries.length
    ? `Similar existing issues already reported nearby:\n- ${input.existingClusterSummaries.join("\n- ")}`
    : ""
}
Respond with strict JSON: {"theme": string, "priorityHint": number}.`;

    const result = await model.generateContent(prompt);
    const parsed = safeParseJson(result.response.text()) ?? {};
    const theme = THEME_IDS.includes(parsed.theme) ? parsed.theme : "roads";
    const priorityHint =
      typeof parsed.priorityHint === "number" ? parsed.priorityHint : 3;
    return {theme, priorityHint};
  }

  /** Refreshes a cluster's natural-language summary + priority score from
   * its member tickets. Called every Nth update, not on every single
   * ticket, to control cost. */
  async summarizeCluster(input: {
    theme: string;
    sampleTexts: string[];
    submissionCount: number;
  }): Promise<{summaryText: string; priorityScore: number}> {
    const model = this.genAI.getGenerativeModel({model: "gemini-2.5-flash"});
    const prompt = `${input.submissionCount} citizens have reported similar
"${input.theme}" issues. Sample reports:\n- ${input.sampleTexts.join("\n- ")}
Write ONE short sentence (for an MP's dashboard) summarizing the recurring
issue, and a priorityScore from 1-100 weighing both volume and severity.
Respond with strict JSON: {"summaryText": string, "priorityScore": number}.`;

    const result = await model.generateContent(prompt);
    const parsed = safeParseJson(result.response.text()) ?? {};
    return {
      summaryText:
        typeof parsed.summaryText === "string"
          ? parsed.summaryText
          : `${input.submissionCount} ${input.theme} reports in this area`,
      priorityScore:
        typeof parsed.priorityScore === "number" ? parsed.priorityScore : 50,
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

async function fetchAsBase64(
  url: string,
): Promise<{data: string; mimeType: string}> {
  const response = await fetch(url);
  const buffer = Buffer.from(await response.arrayBuffer());
  return {
    data: buffer.toString("base64"),
    mimeType: response.headers.get("content-type") ?? "image/jpeg",
  };
}
