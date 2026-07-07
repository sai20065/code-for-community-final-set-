import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import PDFDocument from "pdfkit";
import {REGION} from "../config";
import {GeminiClient} from "../lib/geminiClient";

interface ClusterData {
  theme: string;
  summaryText: string;
  priorityScore?: number;
  demandScore?: number;
  demographicScore?: number;
  infraGapScore?: number;
  submissionCount?: number;
}

/** priorityScore threshold above which a cluster is flagged "urgent" in the
 * report — matches the 0-100 scale `classifyTicket`/`summarizeCluster`
 * already score on. */
const URGENT_THRESHOLD = 70;

/**
 * Generates an AI-authored, printable PDF briefing for an MP's own
 * constituency: open/resolved/urgent counts, top issues ranked by
 * priority, an executive summary, and recommended actions — everything a
 * dashboard "Generate report" button needs to hand the MP something they
 * can act on immediately. Callable only by a signed-in official, scoped
 * strictly to their own `constituencyId` (never a parameter the caller
 * can choose — read straight from their own `users/{uid}` doc, same
 * trust boundary as every constituency-scoped Firestore rule elsewhere in
 * this app).
 */
export const generateConstituencyReport = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const user = userDoc.data();
    if (!user || user.role !== "official" || !user.constituencyId) {
      throw new HttpsError(
        "permission-denied",
        "Only an official with a linked constituency can generate a report.",
      );
    }
    const constituencyId = user.constituencyId as string;

    const constituencyDoc = await db.collection("constituencies").doc(constituencyId).get();
    const constituencyName = (constituencyDoc.data()?.name as string | undefined) ?? constituencyId;
    const mpName = (constituencyDoc.data()?.mpName as string | undefined) ?? "Not yet assigned";

    const [clustersSnap, submissionsSnap] = await Promise.all([
      db.collection("clusters")
        .where("constituencyId", "==", constituencyId)
        .orderBy("priorityScore", "desc")
        .get(),
      db.collection("submissions")
        .where("location.constituencyId", "==", constituencyId)
        .get(),
    ]);

    const clusters = clustersSnap.docs.map((d) => d.data() as ClusterData);
    const submissions = submissionsSnap.docs.map((d) => d.data());
    const resolvedCount = submissions.filter((s) => s.status === "resolved").length;
    const urgentClusters = clusters.filter((c) => (c.priorityScore ?? 0) >= URGENT_THRESHOLD);
    const topClusters = clusters.slice(0, 8);

    const gemini = new GeminiClient();
    let aiSummary = {
      executiveSummary: `${clusters.length} tracked issue groups from ${submissions.length} tickets in ${constituencyName}.`,
      keyRecommendations: [] as string[],
    };
    try {
      aiSummary = await gemini.generateConstituencyReportSummary({
        constituencyName,
        stats: {open: submissions.length, resolved: resolvedCount, urgent: urgentClusters.length},
        topClusters: topClusters.map((c) => ({
          theme: c.theme,
          summaryText: c.summaryText,
          priorityScore: c.priorityScore ?? 0,
          submissionCount: c.submissionCount ?? 0,
        })),
      });
    } catch (err) {
      console.error("Gemini constituency report summary failed", err);
    }

    const pdfBuffer = await renderPdf({
      constituencyName,
      mpName,
      stats: {total: submissions.length, resolved: resolvedCount, urgent: urgentClusters.length},
      topClusters,
      aiSummary,
    });

    const bucket = admin.storage().bucket();
    const fileName = `reports/${constituencyId}/${Date.now()}.pdf`;
    const file = bucket.file(fileName);
    await file.save(pdfBuffer, {contentType: "application/pdf"});
    const [downloadUrl] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 24 * 60 * 60 * 1000,
    });

    return {downloadUrl, generatedAt: new Date().toISOString()};
  },
);

function renderPdf(data: {
  constituencyName: string;
  mpName: string;
  stats: {total: number; resolved: number; urgent: number};
  topClusters: ClusterData[];
  aiSummary: {executiveSummary: string; keyRecommendations: string[]};
}): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({margin: 50});
    const chunks: Buffer[] = [];
    doc.on("data", (chunk) => chunks.push(chunk));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    doc.fontSize(20).text(`Constituency Report: ${data.constituencyName}`, {align: "center"});
    doc.fontSize(12).text(`MP: ${data.mpName}`, {align: "center"});
    doc.fontSize(10).fillColor("gray")
      .text(`Generated ${new Date().toLocaleDateString("en-IN", {year: "numeric", month: "long", day: "numeric"})}`, {align: "center"});
    doc.fillColor("black").moveDown(2);

    doc.fontSize(14).text("Summary", {underline: true});
    doc.fontSize(11)
      .text(`Total tickets: ${data.stats.total}`)
      .text(`Resolved: ${data.stats.resolved}`)
      .text(`Urgent (priority >= ${URGENT_THRESHOLD}): ${data.stats.urgent}`);
    doc.moveDown();

    doc.fontSize(14).text("Executive Summary", {underline: true});
    doc.fontSize(11).text(data.aiSummary.executiveSummary);
    doc.moveDown();

    if (data.aiSummary.keyRecommendations.length) {
      doc.fontSize(14).text("Recommended Actions", {underline: true});
      data.aiSummary.keyRecommendations.forEach((r, i) => {
        doc.fontSize(11).text(`${i + 1}. ${r}`);
      });
      doc.moveDown();
    }

    doc.fontSize(14).text("Top Issues by Priority", {underline: true});
    data.topClusters.forEach((c, i) => {
      doc.fontSize(11).text(`${i + 1}. [${c.theme}] ${c.summaryText}`);
      doc.fontSize(9).fillColor("gray").text(
        `   ${c.submissionCount ?? 0} reports · priority ${c.priorityScore ?? "-"} · ` +
        `demand ${c.demandScore ?? "-"} · infra gap ${c.infraGapScore ?? "-"}`,
      );
      doc.fillColor("black");
    });

    doc.end();
  });
}
