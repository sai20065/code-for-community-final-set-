import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {REGION, reporterHashSalt} from "../config";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";
import {GeminiClient} from "../lib/geminiClient";
import {TranslateClient} from "../lib/translateClient";
import {resolveTalukForPoint} from "../lib/talukGeo";
import {resolveWardForPoint} from "../lib/wardGeo";
import {
  AggregateInput,
  buildClusterAggregatePatch,
  emptyStatusCounts,
} from "./clusterAggregates";

/** Bumped whenever the shape of what this pipeline writes changes, so a
 * backfill can tell which documents predate a field. */
const PIPELINE_VERSION = 3;

/**
 * Main AI pipeline, triggered whenever a citizen creates a ticket
 * (`submissions/{id}`). Every step is individually try/caught so a
 * Gemini/Translate outage never blocks or retroactively invalidates the
 * citizen's already-issued `tokenId` receipt — partial enrichment is
 * always better than none.
 *
 * Steps: (1) voice → Gemini audio transcription → transcript; text tickets
 * use rawText directly. (2) Cloud Translate → translatedText (English), so
 * cross-language tickets can be classified/clustered consistently.
 * (3) photo → Gemini vision caption. (4) Gemini classifies theme (only if
 * the citizen didn't already pick one manually), scores it, and produces a
 * PII-free `publicSummary`. (5) find-or-create a `clusters` doc for
 * (constituencyId, theme, boothId) and update its aggregates.
 *
 * Writes are **accumulated into one patch** and applied once at the end
 * rather than issued step by step. Beyond the obvious cost saving (this used
 * to do up to six separate updates per ticket), it means a ticket is never
 * observed in a half-enriched state by the public-projection trigger.
 */
export const onSubmissionCreated = onDocumentCreated(
  {
    document: "submissions/{submissionId}",
    region: REGION,
    secrets: [reporterHashSalt],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const submission = snapshot.data();
    const submissionRef = snapshot.ref;
    const db = admin.firestore();

    const gemini = new GeminiClient();
    const translate = new TranslateClient();

    /** Accumulated field updates for the submission doc. */
    const patch: Record<string, unknown> = {};

    // --- 1 & 2: transcript + translation ---------------------------------
    // Voice tickets are now transcribed on the client *before* submit (the
    // citizen sees/edits the text), arriving here as `rawText`. Only fall
    // back to server-side transcription when that didn't happen — avoids
    // paying for Gemini transcription twice.
    let transcript: string | undefined = submission.rawText;
    let transcriptionSource: string | null = submission.rawText ? "client" : null;
    if (
      submission.type === "voice" &&
      submission.mediaUrl &&
      !submission.rawText
    ) {
      try {
        transcript = await gemini.transcribeAudioUrl(
          submission.mediaUrl,
          submission.language ?? "hi",
        );
        transcriptionSource = "server";
        patch.transcript = transcript;
      } catch (err) {
        console.error("Gemini audio transcription failed", err);
      }
    }

    let translatedText: string | undefined = submission.translatedText;
    if (transcript && !translatedText) {
      try {
        translatedText = await translate.translate({
          text: transcript,
          sourceLanguage: submission.language ?? "hi",
          targetLanguage: "en",
        });
        patch.translatedText = translatedText;
      } catch (err) {
        console.error("Cloud Translate failed", err);
      }
    }

    // --- 3: photo captioning ----------------------------------------------
    // Persisted, not just used in passing: the caption is often the only
    // description a photo-only ticket has, and the Root-Cause agent needs it
    // as evidence. It used to be computed and silently discarded.
    let photoCaption: string | undefined;
    if (submission.type === "photo" && submission.mediaUrl) {
      try {
        photoCaption = await gemini.captionCivicPhoto(submission.mediaUrl);
        patch.photoCaption = photoCaption;
      } catch (err) {
        console.error("Gemini vision captioning failed", err);
      }
    }

    const classificationInput =
      translatedText || transcript || photoCaption || submission.rawText || "";
    if (!classificationInput) {
      if (Object.keys(patch).length) await submissionRef.update(patch);
      return;
    }

    // --- 4: theme classification (never overwrites a citizen's own pick) --
    let theme: string | undefined = submission.theme;
    let priorityHint = 3;
    let demandScore = 50;
    let demographicScore = 50;
    let infraGapScore = 50;
    let publicSummary: string | undefined;
    try {
      const classification = await gemini.classifyTicket({
        text: classificationInput,
        existingClusterSummaries: [],
      });
      if (!theme) theme = classification.theme;
      priorityHint = classification.priorityHint;
      demandScore = classification.demandScore;
      demographicScore = classification.demographicScore;
      infraGapScore = classification.infraGapScore;
      publicSummary = classification.publicSummary;
      if (!submission.theme) patch.theme = theme;
    } catch (err) {
      console.error("Gemini classification failed", err);
    }

    // The public dashboard shows `publicSummary` and nothing else of the
    // citizen's words. If classification failed we must still write
    // *something* safe, or the projection would fall back to raw text.
    patch.publicSummary =
      publicSummary ?? `${theme ?? "civic"} issue reported in this area`;
    patch.aiScores = {priorityHint, demandScore, demographicScore, infraGapScore};
    patch.analysis = {
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      pipelineVersion: PIPELINE_VERSION,
      transcriptionSource,
    };

    if (!theme) {
      await submissionRef.update(patch);
      return;
    }

    // --- 5: authoritative constituency resolution + cluster assignment ----
    // The client resolves constituencyId client-side (booth/pincode match,
    // often unmapped) purely so the citizen sees an immediate "routed to..."
    // hint. Here we re-resolve from the actual GPS point against real
    // constituency boundaries and correct the ticket if it disagrees (or was
    // never resolved at all) — this is what actually determines which
    // official's dashboard the ticket appears on, so it must not silently
    // stay wrong just because the client-side heuristic had no coverage.
    let constituencyId: string | undefined = submission.location?.constituencyId;
    const lat: number | undefined = submission.location?.lat;
    const lng: number | undefined = submission.location?.lng;
    let wardId: string | undefined = submission.location?.wardId;
    let talukId: string | undefined = submission.location?.talukId;
    if (typeof lat === "number" && typeof lng === "number") {
      const resolved = resolveConstituencyForPoint(lat, lng);
      if (resolved && resolved.constituencyId !== constituencyId) {
        constituencyId = resolved.constituencyId;
        patch["location.constituencyId"] = resolved.constituencyId;
        patch["location.constituencyName"] = resolved.constituencyName;
      }
      const resolvedWard = resolveWardForPoint(lat, lng);
      if (resolvedWard && resolvedWard.wardId !== wardId) {
        wardId = resolvedWard.wardId;
        patch["location.wardId"] = resolvedWard.wardId;
      }
      // Taluks are the ward-equivalent granular unit outside Bengaluru
      // Urban — a point can resolve to both (a Bengaluru ward's taluk is
      // just "Bengaluru North/South/etc" from the same KGIS dataset), so
      // both are stored whenever available rather than one excluding the
      // other.
      const resolvedTaluk = resolveTalukForPoint(lat, lng);
      if (resolvedTaluk && resolvedTaluk.talukId !== talukId) {
        talukId = resolvedTaluk.talukId;
        patch["location.talukId"] = resolvedTaluk.talukId;
      }
    }
    const boothId: string | undefined = submission.location?.boothId;
    if (!constituencyId) {
      // Unscoped ticket — no cluster to join yet. Still persist everything
      // computed so far; a backfill can reconcile the cluster later.
      await submissionRef.update(patch);
      return;
    }

    // --- grounding context for the aggregates ------------------------------
    const [wardSnap, boothSnap] = await Promise.all([
      wardId ? db.collection("wards").doc(wardId).get() : Promise.resolve(null),
      boothId ? db.collection("booths").doc(boothId).get() : Promise.resolve(null),
    ]);
    const createdAtRaw = submission.createdAt;
    const aggregateBase: Omit<AggregateInput, "submissionId"> = {
      userId: submission.userId,
      createdAt:
        createdAtRaw && typeof createdAtRaw.toDate === "function" ?
          createdAtRaw.toDate() :
          new Date(),
      wardId: wardId ?? null,
      talukId: talukId ?? null,
      lat: typeof lat === "number" ? lat : null,
      lng: typeof lng === "number" ? lng : null,
      wardPopulation: wardSnap?.data()?.totalPopulation ?? null,
      boothHouseholds: boothSnap?.data()?.estimatedHouseholds ?? null,
      boothLat: boothSnap?.data()?.lat ?? null,
      boothLng: boothSnap?.data()?.lng ?? null,
    };
    const salt = reporterHashSalt.value() || "praja-dhvani-dev-salt";

    const clusterQuery = await db
      .collection("clusters")
      .where("constituencyId", "==", constituencyId)
      .where("theme", "==", theme)
      .where("boothId", "==", boothId ?? null)
      .limit(1)
      .get();

    if (clusterQuery.empty) {
      const clusterRef = db.collection("clusters").doc();
      const aggregates = buildClusterAggregatePatch({
        clusterId: clusterRef.id,
        existing: {},
        input: {...aggregateBase, submissionId: event.params.submissionId},
        salt,
      });
      await clusterRef.set({
        constituencyId,
        boothId: boothId ?? null,
        theme,
        sampleSubmissionIds: [event.params.submissionId],
        summaryText: `${classificationInput}`.slice(0, 140),
        // Always set explicitly — a cluster missing this field is silently
        // excluded from any `orderBy('priorityScore')` query, which used to
        // make clusters vanish from the map with no error anywhere.
        priorityScore: priorityHint * 10,
        demandScore,
        demographicScore,
        infraGapScore,
        centroidVector: [],
        statusCounts: {...emptyStatusCounts(), new: 1},
        hasSolutionCard: false,
        agentRunCount: 0,
        solutionCardVersion: 0,
        lastAgentRunAt: null,
        ...aggregates,
      });
      patch.clusterId = clusterRef.id;
      await submissionRef.update(patch);
      return;
    }

    const clusterDoc = clusterQuery.docs[0];
    const cluster = clusterDoc.data();
    patch.clusterId = clusterDoc.id;

    const aggregates = buildClusterAggregatePatch({
      clusterId: clusterDoc.id,
      existing: cluster,
      input: {...aggregateBase, submissionId: event.params.submissionId},
      salt,
    });
    const newCount = aggregates.submissionCount as number;

    const sampleIds: string[] = (cluster.sampleSubmissionIds ?? []).slice(-4);
    sampleIds.push(event.params.submissionId);

    const clusterPatch: Record<string, unknown> = {
      ...aggregates,
      sampleSubmissionIds: sampleIds,
      demandScore,
      demographicScore,
      infraGapScore,
      "statusCounts.new": admin.firestore.FieldValue.increment(1),
    };

    // Refresh the AI summary/priority every 5th new ticket in a cluster —
    // not on every single one, to control Gemini call cost. The demand/
    // demographic/infraGap scores are cheap (already computed above for
    // this ticket, no extra Gemini call) so they're kept fresh on every
    // single new ticket, not gated behind the 5th-ticket refresh.
    if (newCount % 5 === 0) {
      try {
        const refreshed = await gemini.summarizeCluster({
          theme,
          sampleTexts: [classificationInput],
          submissionCount: newCount,
        });
        clusterPatch.summaryText = refreshed.summaryText;
        clusterPatch.priorityScore = refreshed.priorityScore;
      } catch (err) {
        console.error("Gemini cluster summarization failed", err);
      }
    }

    await Promise.all([
      clusterDoc.ref.update(clusterPatch),
      submissionRef.update(patch),
    ]);
  },
);
