import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {REGION, geminiApiKey} from "../config";
import {resolveConstituencyForPoint} from "../lib/constituencyGeo";
import {GeminiClient} from "../lib/geminiClient";
import {TranslateClient} from "../lib/translateClient";

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
 * the citizen didn't already pick one manually) + a priority hint.
 * (5) find-or-create a `clusters` doc for (constituencyId, theme, boothId),
 * increment submissionCount, and periodically refresh the AI summary/
 * priorityScore (not on every single update, to control Gemini call cost).
 */
export const onSubmissionCreated = onDocumentCreated(
  {
    document: "submissions/{submissionId}",
    region: REGION,
    secrets: [geminiApiKey],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const submission = snapshot.data();
    const submissionRef = snapshot.ref;
    const db = admin.firestore();

    const gemini = new GeminiClient(geminiApiKey.value());
    const translate = new TranslateClient();

    // --- 1 & 2: transcript + translation ---------------------------------
    // Voice tickets are now transcribed on the client *before* submit (the
    // citizen sees/edits the text), arriving here as `rawText`. Only fall
    // back to server-side transcription when that didn't happen — avoids
    // paying for Gemini transcription twice.
    let transcript: string | undefined = submission.rawText;
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
        await submissionRef.update({transcript});
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
        await submissionRef.update({translatedText});
      } catch (err) {
        console.error("Cloud Translate failed", err);
      }
    }

    // --- 3: photo captioning ----------------------------------------------
    let photoCaption: string | undefined;
    if (submission.type === "photo" && submission.mediaUrl) {
      try {
        photoCaption = await gemini.captionCivicPhoto(submission.mediaUrl);
      } catch (err) {
        console.error("Gemini vision captioning failed", err);
      }
    }

    const classificationInput =
      translatedText || transcript || photoCaption || submission.rawText || "";
    if (!classificationInput) return;

    // --- 4: theme classification (never overwrites a citizen's own pick) --
    let theme: string | undefined = submission.theme;
    let priorityHint = 3;
    try {
      const classification = await gemini.classifyTicket({
        text: classificationInput,
        existingClusterSummaries: [],
      });
      if (!theme) theme = classification.theme;
      priorityHint = classification.priorityHint;
      if (!submission.theme) await submissionRef.update({theme});
    } catch (err) {
      console.error("Gemini classification failed", err);
    }
    if (!theme) return;

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
    if (typeof lat === "number" && typeof lng === "number") {
      const resolved = resolveConstituencyForPoint(lat, lng);
      if (resolved && resolved.constituencyId !== constituencyId) {
        constituencyId = resolved.constituencyId;
        await submissionRef.update({
          "location.constituencyId": resolved.constituencyId,
          "location.constituencyName": resolved.constituencyName,
        });
      }
    }
    const boothId: string | undefined = submission.location?.boothId;
    if (!constituencyId) return; // unscoped ticket — no cluster to join yet

    const clusterQuery = await db
      .collection("clusters")
      .where("constituencyId", "==", constituencyId)
      .where("theme", "==", theme)
      .where("boothId", "==", boothId ?? null)
      .limit(1)
      .get();

    if (clusterQuery.empty) {
      await db.collection("clusters").add({
        constituencyId,
        boothId: boothId ?? null,
        theme,
        submissionCount: 1,
        sampleSubmissionIds: [event.params.submissionId],
        summaryText: `${classificationInput}`.slice(0, 140),
        priorityScore: priorityHint * 10,
        centroidVector: [],
      });
      return;
    }

    const clusterDoc = clusterQuery.docs[0];
    const cluster = clusterDoc.data();
    const newCount = (cluster.submissionCount ?? 0) + 1;
    const sampleIds: string[] = (cluster.sampleSubmissionIds ?? []).slice(-4);
    sampleIds.push(event.params.submissionId);

    // Refresh the AI summary/priority every 5th new ticket in a cluster —
    // not on every single one, to control Gemini call cost.
    if (newCount % 5 === 0) {
      try {
        const refreshed = await gemini.summarizeCluster({
          theme,
          sampleTexts: [classificationInput],
          submissionCount: newCount,
        });
        await clusterDoc.ref.update({
          submissionCount: newCount,
          sampleSubmissionIds: sampleIds,
          summaryText: refreshed.summaryText,
          priorityScore: refreshed.priorityScore,
        });
        return;
      } catch (err) {
        console.error("Gemini cluster summarization failed", err);
      }
    }
    await clusterDoc.ref.update({
      submissionCount: newCount,
      sampleSubmissionIds: sampleIds,
    });
  },
);
