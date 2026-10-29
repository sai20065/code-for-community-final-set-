/**
 * Bhashini (Government of India's language platform) for speech-to-text and
 * translation — free, and built for Indian languages. Calls the Dhruva
 * inference endpoint directly with the dashboard's inference key
 * (`BHASHINI_INFERENCE_KEY`), naming the service per language.
 *
 * Verified live on 2026-10-29 for all ten app languages, including the
 * phone's m4a recordings sent as-is (no conversion needed).
 */

const COMPUTE_URL = "https://dhruva-api.bhashini.gov.in/services/inference/pipeline";

export const NMT_SERVICE = "ai4bharat/indictrans-v2-all-gpu--t4";

const DRAVIDIAN = new Set(["kn", "ta", "te", "ml"]);
const INDO_ARYAN = new Set(["mr", "bn", "gu", "pa"]);

/** The ASR model for an app language, or null when Bhashini has none. */
export function asrServiceFor(lang: string): string | null {
  if (lang === "en") return "ai4bharat/whisper-medium-en--gpu--t4";
  if (lang === "hi") return "ai4bharat/conformer-hi-gpu--t4";
  if (DRAVIDIAN.has(lang)) return "ai4bharat/conformer-multilingual-dravidian-gpu--t4";
  if (INDO_ARYAN.has(lang)) return "ai4bharat/conformer-multilingual-indo_aryan-gpu--t4";
  return null;
}

/** Bhashini's `audioFormat` for a recording's MIME type. */
export function audioFormatFor(mimeType: string | undefined): string {
  const m = (mimeType ?? "").toLowerCase();
  if (m.includes("wav")) return "wav";
  if (m.includes("flac")) return "flac";
  if (m.includes("mpeg") || m.includes("mp3")) return "mp3";
  if (m.includes("ogg")) return "ogg";
  if (m.includes("webm")) return "webm";
  return "m4a"; // the app records AAC in an MP4 container
}

interface PipelineResponse {
  pipelineResponse?: Array<{
    taskType?: string;
    output?: Array<{source?: string; target?: string}>;
  }>;
}

export class BhashiniClient {
  constructor(private readonly key: string, private readonly timeoutMs = 25000) {}

  private async compute(body: unknown): Promise<PipelineResponse> {
    const res = await fetch(COMPUTE_URL, {
      method: "POST",
      headers: {"Content-Type": "application/json", "Authorization": this.key},
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!res.ok) {
      throw new Error(`Bhashini ${res.status}: ${(await res.text()).slice(0, 200)}`);
    }
    return await res.json() as PipelineResponse;
  }

  /**
   * Speech to text in [lang], and the English translation, in one pipeline
   * call. English audio skips translation.
   */
  async transcribeAndTranslate(
    audioBase64: string,
    lang: string,
    mimeType?: string,
  ): Promise<{transcript: string; translatedText: string}> {
    const asr = asrServiceFor(lang);
    if (!asr) throw new Error(`Bhashini has no ASR for "${lang}"`);
    const tasks: unknown[] = [{
      taskType: "asr",
      config: {
        language: {sourceLanguage: lang},
        serviceId: asr,
        audioFormat: audioFormatFor(mimeType),
        samplingRate: 16000,
      },
    }];
    if (lang !== "en") {
      tasks.push({
        taskType: "translation",
        config: {language: {sourceLanguage: lang, targetLanguage: "en"}, serviceId: NMT_SERVICE},
      });
    }
    const json = await this.compute({pipelineTasks: tasks, inputData: {audio: [{audioContent: audioBase64}]}});
    const steps = json.pipelineResponse ?? [];
    const transcript = steps.find((s) => s.taskType === "asr")?.output?.[0]?.source?.trim() ?? "";
    if (!transcript) throw new Error("Bhashini returned an empty transcript");
    const translatedText = lang === "en" ?
      transcript :
      steps.find((s) => s.taskType === "translation")?.output?.[0]?.target?.trim() ?? "";
    if (!translatedText) throw new Error("Bhashini returned an empty translation");
    return {transcript, translatedText};
  }

  /** Text from [sourceLanguage] into [targetLanguage] (English by default). */
  async translate(text: string, sourceLanguage: string, targetLanguage = "en"): Promise<string> {
    if (sourceLanguage === targetLanguage) return text;
    const json = await this.compute({
      pipelineTasks: [{
        taskType: "translation",
        config: {language: {sourceLanguage, targetLanguage}, serviceId: NMT_SERVICE},
      }],
      inputData: {input: [{source: text}]},
    });
    const out = json.pipelineResponse?.[0]?.output?.[0]?.target?.trim();
    if (!out) throw new Error("Bhashini returned an empty translation");
    return out;
  }
}
