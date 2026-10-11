import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {REGION} from "../config";
import {AreaBriefingContent, GeminiClient} from "../lib/geminiClient";
import {scopeForCaller} from "../officials/scope";
import {loadAreaData} from "./areaData";

/** A cached briefing is reused for this long — opening the dashboard must
 * not re-bill Gemini every time. */
const CACHE_HOURS = 6;
/** "Refresh" can force a regeneration at most this often. */
const MIN_REFRESH_MINUTES = 60;

/** "+40% vs previous 2 weeks"-style trend from a cluster's weekly counts. */
function trendOf(weekly: Record<string, number> | undefined): string {
  if (!weekly) return "no trend data";
  const weeks = Object.keys(weekly).sort();
  const last2 = weeks.slice(-2).reduce((s, w) => s + weekly[w], 0);
  const prev2 = weeks.slice(-4, -2).reduce((s, w) => s + weekly[w], 0);
  if (!prev2) return last2 ? "new in the last 2 weeks" : "quiet";
  const pct = Math.round(((last2 - prev2) / prev2) * 100);
  return pct === 0 ? "steady" : `${pct > 0 ? "+" : ""}${pct}% vs previous 2 weeks`;
}

/**
 * AI briefing on the problems in the caller's own area — MP constituency,
 * MLA assembly seat, ward / taluk / district for officers, or the whole
 * state for an admin (see `scopeForCaller`). Returns structured JSON for the
 * dashboard card; cached in `briefings/{scopeKey}` (readable only by the
 * matching official or an admin — see firestore.rules).
 *
 * Request: `{refresh?: boolean}`.
 */
export const getAreaBriefing = onCall(
  {region: REGION, timeoutSeconds: 120, memory: "512MiB"},
  async (request) => {
    const scope = await scopeForCaller(request.auth?.uid);
    const db = admin.firestore();
    const ref = db.collection("briefings").doc(scope.key);
    const cached = (await ref.get()).data();
    const ageMin = cached?.generatedAt ?
      (Date.now() - cached.generatedAt.toDate().getTime()) / 60000 :
      Infinity;
    const wantsRefresh = request.data?.refresh === true && ageMin >= MIN_REFRESH_MINUTES;
    if (cached && ageMin < CACHE_HOURS * 60 && !wantsRefresh) {
      return {...cached, generatedAt: cached.generatedAt.toDate().toISOString(), cached: true};
    }

    const area = await loadAreaData(scope);
    const top = area.clusters.slice(0, 8);
    let content: AreaBriefingContent;
    try {
      content = await new GeminiClient().generateAreaBriefing({
        areaName: scope.name,
        audience: scope.typeLabel,
        stats: area.stats,
        topClusters: top.map((c) => ({
          theme: c.theme,
          summaryText: c.summaryText,
          priorityScore: c.priorityScore ?? 0,
          submissionCount: c.submissionCount ?? 0,
          trend: trendOf(c.weeklyCounts),
        })),
      });
    } catch (err) {
      console.error("Area briefing generation failed", err);
      if (cached) {
        return {...cached, generatedAt: cached.generatedAt.toDate().toISOString(), cached: true, stale: true};
      }
      throw new HttpsError("unavailable", "The AI briefing is unavailable right now. Try again shortly.");
    }

    const doc = {
      ...content,
      scopeKey: scope.key,
      areaName: scope.name,
      audience: scope.typeLabel,
      stats: area.stats,
      // Matched by firestore.rules against the reader's jurisdiction.
      scopeField: scope.field,
      scopeId: scope.id,
      topClusters: top.slice(0, 4).map((c) => ({
        id: c.id,
        theme: c.theme,
        summaryText: c.summaryText,
        priorityScore: c.priorityScore ?? 0,
        submissionCount: c.submissionCount ?? 0,
      })),
      generatedAt: admin.firestore.Timestamp.now(),
    };
    await ref.set(doc);
    return {...doc, generatedAt: doc.generatedAt.toDate().toISOString(), cached: false};
  },
);
