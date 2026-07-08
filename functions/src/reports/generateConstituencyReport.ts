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

// Mirrors the Flutter app's brand palette (lib/app/theme.dart's AppColors)
// so the printed report reads as the same product, not a generic export.
const BRAND = {
  indigo: "#2E1F8F",
  indigoDeep: "#1C1259",
  indigoMist: "#E9E6F8",
  saffron: "#FFA630",
  saffronDeep: "#C97914",
  saffronMist: "#FFF1DA",
  teal: "#0B8A6C",
  tealMist: "#DBF2EA",
  vermilion: "#E0384A",
  vermilionDeep: "#A5202F",
  vermilionMist: "#FBE1E4",
  ink: "#14131F",
  inkSoft: "#57547A",
  inkFaint: "#8C89AB",
  paper: "#F3F2EE",
  white: "#FFFFFF",
};

const MARGIN = 50;

/** Same red/amber/green hotspot language used on the app's map/booth
 * markers (see `_wardColorForPriority` in constituency_map_screen.dart) —
 * keeps the printed report's urgency cues consistent with what the MP
 * already sees on screen. */
function priorityColor(score: number | undefined): string {
  if (score === undefined) return BRAND.inkFaint;
  if (score >= 70) return BRAND.vermilion;
  if (score >= 40) return BRAND.saffronDeep;
  return BRAND.teal;
}

/**
 * Every drawing helper below takes and returns an explicit `y` cursor
 * rather than reading/relying on `doc.y` — PDFKit's own `.text()` mutates
 * `doc.x`/`doc.y` to wherever the text ended up even when you pass it
 * explicit coordinates, so chaining several absolutely-positioned draws
 * back-to-back while trusting `doc.y` in between silently drifts (this is
 * what caused the stat tiles to overlap and cards to split across pages
 * in an earlier version of this report). Treating `y` as a plain number
 * the caller threads through avoids that class of bug entirely.
 */
function ensureSpace(doc: PDFKit.PDFDocument, y: number, neededHeight: number): number {
  const pageBottom = doc.page.height - doc.page.margins.bottom;
  if (y + neededHeight > pageBottom) {
    doc.addPage();
    return doc.page.margins.top;
  }
  return y;
}

function sectionHeader(doc: PDFKit.PDFDocument, y: number, title: string, color: string): number {
  y = ensureSpace(doc, y, 30);
  doc.rect(MARGIN, y, 5, 20).fill(color);
  doc.fillColor(BRAND.ink).font("Helvetica-Bold").fontSize(14)
    .text(title.toUpperCase(), MARGIN + 12, y + 3, {characterSpacing: 0.5, lineBreak: false});
  return y + 30;
}

function statTile(
  doc: PDFKit.PDFDocument,
  x: number,
  y: number,
  width: number,
  label: string,
  value: string,
  color: string,
  mist: string,
): void {
  const height = 62;
  doc.roundedRect(x, y, width, height, 8).fillAndStroke(mist, color);
  doc.fillColor(color).font("Helvetica-Bold").fontSize(24)
    .text(value, x, y + 10, {width, align: "center", lineBreak: false});
  doc.fillColor(BRAND.inkSoft).font("Helvetica-Bold").fontSize(9)
    .text(label.toUpperCase(), x, y + 40, {width, align: "center", characterSpacing: 0.5, lineBreak: false});
}

function renderPdf(data: {
  constituencyName: string;
  mpName: string;
  stats: {total: number; resolved: number; urgent: number};
  topClusters: ClusterData[];
  aiSummary: {executiveSummary: string; keyRecommendations: string[]};
}): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({margin: MARGIN, size: "A4", bufferPages: true});
    const chunks: Buffer[] = [];
    doc.on("data", (chunk) => chunks.push(chunk));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - MARGIN * 2;

    // --- Header band (page 1 only) -----------------------------------------
    doc.rect(0, 0, pageWidth, 130).fill(BRAND.indigo);
    const third = pageWidth / 3;
    doc.rect(0, 130, third, 4).fill(BRAND.saffron);
    doc.rect(third, 130, third, 4).fill(BRAND.white);
    doc.rect(third * 2, 130, third, 4).fill(BRAND.teal);

    doc.fillColor(BRAND.white).font("Helvetica-Bold").fontSize(22)
      .text("PRAJADHWANI", MARGIN, 32, {characterSpacing: 1, lineBreak: false});
    doc.font("Helvetica").fontSize(10).fillColor(BRAND.indigoMist)
      .text("Constituency Briefing", MARGIN, 58, {lineBreak: false});
    doc.font("Helvetica-Bold").fontSize(18).fillColor(BRAND.white)
      .text(data.constituencyName, MARGIN, 76, {lineBreak: false});
    doc.font("Helvetica").fontSize(11).fillColor(BRAND.indigoMist)
      .text(`MP: ${data.mpName}`, MARGIN, 100, {lineBreak: false});
    doc.fontSize(9).fillColor(BRAND.indigoMist)
      .text(
        new Date().toLocaleDateString("en-IN", {year: "numeric", month: "long", day: "numeric"}),
        MARGIN, 100, {width: contentWidth, align: "right", lineBreak: false},
      );

    let y = 155;

    // --- Stat tiles ---------------------------------------------------------
    const gap = 14;
    const tileWidth = (contentWidth - gap * 2) / 3;
    statTile(doc, MARGIN, y, tileWidth, "Total Tickets", String(data.stats.total), BRAND.indigo, BRAND.indigoMist);
    statTile(doc, MARGIN + tileWidth + gap, y, tileWidth, "Resolved", String(data.stats.resolved), BRAND.teal, BRAND.tealMist);
    statTile(doc, MARGIN + (tileWidth + gap) * 2, y, tileWidth, "Urgent", String(data.stats.urgent), BRAND.vermilion, BRAND.vermilionMist);
    y += 62 + 24;

    // --- Executive summary, highlighted box ----------------------------------
    y = sectionHeader(doc, y, "Executive Summary", BRAND.indigo);
    doc.font("Helvetica").fontSize(11);
    const summaryHeight = doc.heightOfString(data.aiSummary.executiveSummary, {width: contentWidth - 24}) + 24;
    y = ensureSpace(doc, y, summaryHeight);
    doc.roundedRect(MARGIN, y, contentWidth, summaryHeight, 6).fillAndStroke(BRAND.paper, BRAND.indigoMist);
    doc.fillColor(BRAND.ink).font("Helvetica").fontSize(11)
      .text(data.aiSummary.executiveSummary, MARGIN + 12, y + 12, {width: contentWidth - 24});
    y += summaryHeight + 24;

    // --- Recommended actions, numbered badges --------------------------------
    if (data.aiSummary.keyRecommendations.length) {
      y = sectionHeader(doc, y, "Recommended Actions", BRAND.saffronDeep);
      for (const r of data.aiSummary.keyRecommendations) {
        doc.font("Helvetica-Bold").fontSize(11);
        const textHeight = doc.heightOfString(r, {width: contentWidth - 28});
        const rowHeight = Math.max(textHeight, 18) + 12;
        y = ensureSpace(doc, y, rowHeight);
        doc.circle(MARGIN + 10, y + 9, 9).fill(BRAND.saffron);
        doc.fillColor(BRAND.white).font("Helvetica-Bold").fontSize(9)
          .text(String(data.aiSummary.keyRecommendations.indexOf(r) + 1), MARGIN + 1, y + 4.5, {width: 18, align: "center", lineBreak: false});
        doc.fillColor(BRAND.ink).font("Helvetica-Bold").fontSize(11)
          .text(r, MARGIN + 28, y, {width: contentWidth - 28});
        y += rowHeight;
      }
      y += 12;
    }

    // --- Top issues, priority-colored cards -----------------------------------
    y = sectionHeader(doc, y, "Top Issues by Priority", BRAND.vermilion);
    data.topClusters.forEach((c, i) => {
      const color = priorityColor(c.priorityScore);
      const titleText = `${i + 1}. [${c.theme}]  ${c.summaryText}`;
      doc.font("Helvetica-Bold").fontSize(11);
      const titleHeight = doc.heightOfString(titleText, {width: contentWidth - 20});
      const cardHeight = titleHeight + 34;
      y = ensureSpace(doc, y, cardHeight + 10);

      doc.roundedRect(MARGIN, y, contentWidth, cardHeight, 4).fill(BRAND.paper);
      doc.rect(MARGIN, y, 4, cardHeight).fill(color);
      doc.fillColor(BRAND.ink).font("Helvetica-Bold").fontSize(11)
        .text(titleText, MARGIN + 14, y + 8, {width: contentWidth - 20});

      const metaY = y + titleHeight + 12;
      const priorityLabel = `PRIORITY ${c.priorityScore ?? "—"}`;
      doc.font("Helvetica-Bold").fontSize(8.5).fillColor(color);
      const priorityLabelWidth = doc.widthOfString(priorityLabel);
      doc.text(priorityLabel, MARGIN + 14, metaY, {lineBreak: false});
      doc.font("Helvetica").fontSize(8.5).fillColor(BRAND.inkFaint)
        .text(
          `   ·   ${c.submissionCount ?? 0} reports   ·   demand ${c.demandScore ?? "—"}   ·   infra gap ${c.infraGapScore ?? "—"}`,
          MARGIN + 14 + priorityLabelWidth, metaY,
          {lineBreak: false},
        );
      y += cardHeight + 10;
    });

    doc.end();
  });
}
