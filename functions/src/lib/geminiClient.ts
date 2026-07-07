import {VertexAI} from "@google-cloud/vertexai";
import {THEME_IDS, ThemeId, VERTEX_AI_LOCATION, VERTEX_AI_PROJECT} from "../config";

const MODEL = "gemini-2.5-flash";

/**
 * Thin wrapper over Vertex AI's Gemini models — used for every "Gemma-
 * family" AI task in this app: Aadhaar OCR extraction, transcription,
 * photo identification, theme classification, and cluster summarization/
 * priority scoring. Authenticates via the function's own runtime service
 * account (Application Default Credentials), billed against the
 * project's regular Cloud Billing account — see the comment on
 * `VERTEX_AI_PROJECT`/`VERTEX_AI_LOCATION` in `config.ts` for why this
 * replaced the Gemini Developer API (AI-Studio) key.
 */
export class GeminiClient {
  private readonly vertexAI: VertexAI;

  constructor() {
    this.vertexAI = new VertexAI({project: VERTEX_AI_PROJECT, location: VERTEX_AI_LOCATION});
  }

  private async generateText(parts: Array<string | {inlineData: {data: string; mimeType: string}}>): Promise<string> {
    const model = this.vertexAI.getGenerativeModel({model: MODEL});
    const result = await model.generateContent({
      contents: [{
        role: "user",
        parts: parts.map((p) => (typeof p === "string" ? {text: p} : p)),
      }],
    });
    const candidateParts = result.response.candidates?.[0]?.content?.parts ?? [];
    return candidateParts.map((p) => p.text ?? "").join("").trim();
  }

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

    const parts: Array<string | {inlineData: {data: string; mimeType: string}}> = [
      prompt,
      {inlineData: {data: frontBase64, mimeType}},
    ];
    if (backBase64) parts.push({inlineData: {data: backBase64, mimeType}});

    const text = await this.generateText(parts);
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

  /** Transcribes voice-ticket audio verbatim in its own spoken language —
   * replaces the Bhashini ASR step. Translation to English is a separate,
   * subsequent step (see `TranslateClient`), not done here. */
  async transcribeAudioBase64(
    audioBase64: string,
    mimeType: string,
    sourceLanguage: string,
  ): Promise<string> {
    return this.generateText([
      "Transcribe this audio verbatim in its original spoken language " +
        `(expected: ${sourceLanguage}). Respond with ONLY the transcript ` +
        "text — no commentary, no translation, no extra formatting.",
      {inlineData: {data: audioBase64, mimeType}},
    ]);
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
    const imageBytes = await fetchAsBase64(imageUrl);
    return this.generateText([
      "In one short sentence, describe the civic issue shown in this photo " +
        "(e.g. road/pothole, water leakage, garbage, downed power line, " +
        "waterlogging). If nothing civic-related is visible, say so plainly.",
      {inlineData: {data: imageBytes.data, mimeType: imageBytes.mimeType}},
    ]);
  }

  /** Classifies a ticket's text/caption into one of the app's 6 category
   * ids, and suggests whether it looks like a duplicate of an existing
   * cluster summary. Only called when the citizen didn't already pick a
   * theme manually — AI never overwrites a citizen's own choice. Also
   * scores the ticket on three axes an MP's constituency report groups
   * clusters by: demandScore (how many people are affected/how loudly),
   * demographicScore (breadth of population reach — schools/health/transit
   * affecting many vs. a narrow local issue), and infraGapScore (how much
   * this reflects a missing/inadequate piece of infrastructure vs. a
   * one-off maintenance issue). */
  async classifyTicket(input: {
    text: string;
    existingClusterSummaries: string[];
  }): Promise<{
    theme: ThemeId;
    priorityHint: number;
    demandScore: number;
    demographicScore: number;
    infraGapScore: number;
  }> {
    const prompt = `Classify this civic ticket into exactly one of these
categories: ${THEME_IDS.join(", ")}.
Also give:
- priorityHint from 1 (minor) to 5 (urgent/safety-critical)
- demandScore from 0-100: how strong is the apparent citizen demand behind this (volume/urgency of language)?
- demographicScore from 0-100: how broad is the population this affects (a school/hospital/transit issue affecting thousands scores high; a single household's issue scores low)?
- infraGapScore from 0-100: how much does this reflect a missing or inadequate piece of infrastructure (new school/road/water line needed) vs. a simple maintenance fix (score low for maintenance)?
Ticket: "${input.text}"
${
  input.existingClusterSummaries.length
    ? `Similar existing issues already reported nearby:\n- ${input.existingClusterSummaries.join("\n- ")}`
    : ""
}
Respond with strict JSON: {"theme": string, "priorityHint": number, "demandScore": number, "demographicScore": number, "infraGapScore": number}.`;

    const text = await this.generateText([prompt]);
    const parsed = safeParseJson(text) ?? {};
    const theme = THEME_IDS.includes(parsed.theme) ? parsed.theme : "roads";
    const num = (v: unknown, fallback: number) => (typeof v === "number" ? v : fallback);
    return {
      theme,
      priorityHint: num(parsed.priorityHint, 3),
      demandScore: num(parsed.demandScore, 50),
      demographicScore: num(parsed.demographicScore, 50),
      infraGapScore: num(parsed.infraGapScore, 50),
    };
  }

  /** Refreshes a cluster's natural-language summary + priority score from
   * its member tickets. Called every Nth update, not on every single
   * ticket, to control cost. */
  async summarizeCluster(input: {
    theme: string;
    sampleTexts: string[];
    submissionCount: number;
  }): Promise<{summaryText: string; priorityScore: number}> {
    const prompt = `${input.submissionCount} citizens have reported similar
"${input.theme}" issues. Sample reports:\n- ${input.sampleTexts.join("\n- ")}
Write ONE short sentence (for an MP's dashboard) summarizing the recurring
issue, and a priorityScore from 1-100 weighing both volume and severity.
Respond with strict JSON: {"summaryText": string, "priorityScore": number}.`;

    const text = await this.generateText([prompt]);
    const parsed = safeParseJson(text) ?? {};
    return {
      summaryText:
        typeof parsed.summaryText === "string"
          ? parsed.summaryText
          : `${input.submissionCount} ${input.theme} reports in this area`,
      priorityScore:
        typeof parsed.priorityScore === "number" ? parsed.priorityScore : 50,
    };
  }

  /** Generates an executive summary + recommended actions for an MP's
   * printable constituency report (see `generateConstituencyReport.ts`) —
   * plain free-text prompt in, structured JSON out, same pattern as the
   * other methods here. */
  async generateConstituencyReportSummary(input: {
    constituencyName: string;
    stats: {open: number; resolved: number; urgent: number};
    topClusters: Array<{theme: string; summaryText: string; priorityScore: number; submissionCount: number}>;
  }): Promise<{executiveSummary: string; keyRecommendations: string[]}> {
    const prompt = `You are writing a briefing for the Member of Parliament for
${input.constituencyName}. Current status: ${input.stats.open} open tickets,
${input.stats.resolved} resolved, ${input.stats.urgent} flagged urgent.
Top issues by priority:
${input.topClusters.map((c) => `- [${c.theme}] ${c.summaryText} (${c.submissionCount} reports, priority ${c.priorityScore})`).join("\n")}
Write a short executive summary (3-4 sentences, plain professional English,
no markdown) for the MP, and 3-5 concrete recommended actions ranked by
impact. Respond with strict JSON: {"executiveSummary": string,
"keyRecommendations": string[]}.`;

    const text = await this.generateText([prompt]);
    const parsed = safeParseJson(text) ?? {};
    return {
      executiveSummary:
        typeof parsed.executiveSummary === "string" ?
          parsed.executiveSummary :
          `${input.stats.open} open tickets across ${input.topClusters.length} tracked issues in ${input.constituencyName}.`,
      keyRecommendations: Array.isArray(parsed.keyRecommendations) ?
        parsed.keyRecommendations.filter((r: unknown) => typeof r === "string") :
        [],
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
