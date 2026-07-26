import * as admin from "firebase-admin";
import {VertexAI} from "@google-cloud/vertexai";
import {
  AGENT_MODEL,
  AGENT_TIME_BUDGET_MS,
  VERTEX_AI_LOCATION,
  VERTEX_AI_PROJECT,
} from "../config";
import {safeParseJson} from "../lib/geminiClient";
import {AgentMessage, AgentName, AgentTurn} from "./types";

const PROMPT_LOG_LIMIT = 4000;
const RESPONSE_LOG_LIMIT = 8000;

export interface AgentCallOptions<T> {
  agent: AgentName;
  /** The agent's persona and hard rules. Sent as Vertex `systemInstruction`
   * rather than prepended to the user turn, so it isn't diluted by the
   * conversation history that follows. */
  systemRole: string;
  /** Prior agents' turns. This is what makes the chain a conversation. */
  history: AgentMessage[];
  userPrompt: string;
  /** Human-readable JSON shape, appended to the prompt. */
  schemaHint: string;
  /** Returns the typed output, or null to reject and retry. This is where
   * the real guarantees live — citation checks, range checks, count
   * limits — because a prompt is a request and a validator is a rule. */
  validate: (raw: unknown) => T | null;
  /** Deterministic, LLM-free output used when every attempt fails. */
  fallback: () => T;
  maxAttempts?: number;
  temperature?: number;
}

/**
 * Runs one agent turn and **never throws**.
 *
 * That guarantee is the whole point of centralising this. The chain has four
 * agents; if any one of them could throw, the orchestrator would need
 * try/catch at four call sites, and the fourth would be the one nobody
 * tested. Instead every failure — a network error, unparseable JSON, a
 * response that fails validation twice — resolves to the caller's own
 * `fallback()` with `usedFallback: true` recorded on the turn, and the
 * conversation continues with a degraded but honest input.
 */
export class AgentClient {
  private readonly vertexAI: VertexAI;
  private startedAt = Date.now();

  constructor() {
    this.vertexAI = new VertexAI({
      project: VERTEX_AI_PROJECT,
      location: VERTEX_AI_LOCATION,
    });
  }

  /** Resets the wall-clock budget. Called once per chain. */
  beginRun(): void {
    this.startedAt = Date.now();
  }

  private budgetExhausted(): boolean {
    return Date.now() - this.startedAt > AGENT_TIME_BUDGET_MS;
  }

  async run<T>(opts: AgentCallOptions<T>): Promise<{output: T; turn: AgentTurn}> {
    const turnStart = Date.now();
    const startedAt = admin.firestore.Timestamp.now();
    const maxAttempts = opts.maxAttempts ?? 2;

    const baseTurn = {
      agent: opts.agent,
      systemRole: opts.systemRole.slice(0, PROMPT_LOG_LIMIT),
      promptText: opts.userPrompt.slice(0, PROMPT_LOG_LIMIT),
      modelId: AGENT_MODEL,
      startedAt,
    };

    // Out of time: skip the call entirely rather than risk the whole
    // function timing out and losing the agents that already succeeded.
    if (this.budgetExhausted()) {
      return {
        output: opts.fallback(),
        turn: {
          ...baseTurn,
          rawResponse: "",
          parsedOutput: null,
          ok: false,
          usedFallback: true,
          errorMessage: "time budget exhausted before call",
          attempts: 0,
          latencyMs: 0,
        },
      };
    }

    const model = this.vertexAI.getGenerativeModel({
      model: AGENT_MODEL,
      systemInstruction: {
        role: "system",
        parts: [{text: opts.systemRole}],
      },
      generationConfig: {
        responseMimeType: "application/json",
        temperature: opts.temperature ?? 0.2,
      },
    });

    let rawResponse = "";
    let lastError: string | undefined;
    let attempts = 0;
    let correction = "";

    while (attempts < maxAttempts) {
      attempts++;
      try {
        const contents = [
          ...opts.history.map((m) => ({
            role: m.role,
            parts: [{text: m.text}],
          })),
          {
            role: "user" as const,
            parts: [{text: `${opts.userPrompt}\n\n${opts.schemaHint}${correction}`}],
          },
        ];

        const result = await model.generateContent({contents});
        rawResponse = (result.response.candidates?.[0]?.content?.parts ?? [])
          .map((p) => p.text ?? "")
          .join("")
          .trim();

        const parsed = safeParseJson(rawResponse);
        const validated = parsed === null ? null : opts.validate(parsed);
        if (validated !== null) {
          return {
            output: validated,
            turn: {
              ...baseTurn,
              rawResponse: rawResponse.slice(0, RESPONSE_LOG_LIMIT),
              parsedOutput: validated,
              ok: true,
              usedFallback: false,
              attempts,
              latencyMs: Date.now() - turnStart,
            },
          };
        }

        lastError =
          parsed === null ? "response was not valid JSON" : "failed validation";
        // Show the model its own bad answer. A blind retry at the same
        // temperature usually reproduces the same mistake.
        correction =
          "\n\nYour previous reply was rejected because it " +
          `${lastError}. Reply again with ONLY a JSON object matching the ` +
          "schema exactly. Do not add commentary or markdown fences.";
      } catch (err) {
        lastError = err instanceof Error ? err.message : String(err);
        console.error(`Agent ${opts.agent} attempt ${attempts} failed`, err);
      }

      if (attempts < maxAttempts && !this.budgetExhausted()) {
        await new Promise((resolve) => setTimeout(resolve, 800));
      }
    }

    console.warn(
      `Agent ${opts.agent} exhausted ${attempts} attempts, using fallback: ${lastError}`,
    );
    return {
      output: opts.fallback(),
      turn: {
        ...baseTurn,
        rawResponse: rawResponse.slice(0, RESPONSE_LOG_LIMIT),
        parsedOutput: null,
        ok: false,
        usedFallback: true,
        errorMessage: lastError,
        attempts,
        latencyMs: Date.now() - turnStart,
      },
    };
  }
}

/* ---------------------------------------------------------------- *
 * Shared validation helpers
 * ---------------------------------------------------------------- */

export function isNonEmptyString(v: unknown): v is string {
  return typeof v === "string" && v.trim().length > 0;
}

export function stringArray(v: unknown, max = 20): string[] {
  if (!Array.isArray(v)) return [];
  return v.filter(isNonEmptyString).slice(0, max).map((s) => s.trim());
}

export function clampNumber(v: unknown, min: number, max: number, fallback: number): number {
  if (typeof v !== "number" || !Number.isFinite(v)) return fallback;
  return Math.min(Math.max(v, min), max);
}

/** Caps a string at [maxWords] words. Prompts ask for a word limit; models
 * treat it as a suggestion, and a "≤45 word" citizen summary that arrives at
 * 120 words breaks the card layout. */
export function limitWords(text: string, maxWords: number): string {
  const words = text.trim().split(/\s+/);
  if (words.length <= maxWords) return text.trim();
  return `${words.slice(0, maxWords).join(" ")}…`;
}
