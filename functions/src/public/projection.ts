import {PUBLIC_GEO_MIN_TICKETS} from "../config";
import {snapCoordinate} from "./geoPrivacy";

/**
 * The public dashboard reads **only** these projections. It never reads
 * `submissions` or `users`, and the rules on those collections are not
 * loosened by one line to make the dashboard work.
 *
 * That indirection is the entire privacy argument. If the rules on
 * `publicTickets` were somehow wrong tomorrow, the worst case is exposing
 * fields a Cloud Function deliberately copied here after review. There is no
 * configuration mistake that turns "the dashboard is public" into "citizen
 * home addresses are public", because the addresses were never written to
 * anything a public reader can reach.
 */

/**
 * THE COMPLETE ALLOWLIST of fields that may appear on a public ticket.
 *
 * Adding a field to this interface is a privacy decision, not a feature
 * decision. Review it as one.
 *
 * Deliberately EXCLUDED, and not to be re-added without a very good reason:
 *   userId          — the whole point; a public reporter identity chills reporting
 *   rawText         — routinely contains "behind my house at 42 Cross"
 *   transcript      — same, in the citizen's own voice
 *   translatedText  — same content, different language
 *   photoCaption    — can describe an identifiable house or vehicle
 *   mediaUrl        — the photo itself, often of someone's frontage
 *   location.pincode— narrows an area enough to matter alongside a theme
 *   exact lat/lng   — usually the reporter's home; see `geo` below
 *   supporterIds    — a list of uids
 *   aiScores        — internal prioritisation weights, meaningless publicly
 *   language        — a weak but real demographic signal about the reporter
 *   inputMode, analysis — internal pipeline state
 */
export interface PublicTicketDoc {
  /** The only identifier ever exposed. It is the receipt code the citizen
   * already has, deliberately designed to carry no personal information. */
  tokenId: string;
  theme: string | null;
  submissionCategory: string;
  status: string;
  /** AI-generated under an explicit no-PII instruction and regex-scrubbed
   * afterwards. Never the citizen's own words. */
  publicSummary: string;
  constituencyId: string;
  constituencyName: string | null;
  wardId: string | null;
  talukId: string | null;
  boothId: string | null;
  clusterId: string | null;
  supporterCount: number;

  /** Date, never a timestamp. A precise submission time next to even a
   * blurred location is a re-identification vector — "who was filing a
   * complaint from that street at 11:42pm" — and no dashboard feature needs
   * more than the day. */
  createdDate: string;
  createdWeek: string;
  updatedDate: string | null;
  resolvedDate: string | null;

  /** Snapped and jittered, or null. See `geoPrecision`. */
  geo: {lat: number; lng: number} | null;
  geoPrecision: "approx-300m" | "ward" | "none";
}

export interface PublicClusterDoc {
  clusterId: string;
  constituencyId: string;
  constituencyName: string | null;
  theme: string;
  boothId: string | null;
  wardId: string | null;
  talukId: string | null;
  submissionCount: number;
  uniqueReporterCount: number;
  priorityScore: number;
  demandScore: number | null;
  demographicScore: number | null;
  infraGapScore: number | null;
  summaryText: string;
  /** Human-written or AI-written descriptive labels. Safe to publish: they
   * describe the *issue* ("Storm drain desilting — Jalahalli Cross"), never
   * a reporter. */
  title: string | null;
  affectedBoothRange: string | null;
  localContext: string | null;
  centroid: {lat: number; lng: number} | null;
  firstReportedDate: string | null;
  lastReportedDate: string | null;
  weeklyCounts: Record<string, number>;
  statusCounts: Record<string, number>;
  hasSolutionCard: boolean;
  solutionCardVersion: number;
}

function toDateString(value: unknown): string | null {
  const date =
    value && typeof (value as {toDate?: unknown}).toDate === "function" ?
      (value as {toDate: () => Date}).toDate() :
      null;
  return date ? date.toISOString().slice(0, 10) : null;
}

function isoWeek(dateString: string | null): string {
  if (!dateString) return "";
  const date = new Date(`${dateString}T00:00:00Z`);
  const d = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

export interface ProjectTicketArgs {
  submissionId: string;
  submission: FirebaseFirestore.DocumentData;
  /** The parent cluster's ticket count, for the k-anonymity gate. */
  clusterSubmissionCount: number;
  /** Ward centroid, used as the coarse fallback location. */
  wardCentroid: {lat: number; lng: number} | null;
}

/**
 * Builds a public ticket, or null when the submission isn't publishable.
 *
 * The geo rule is worth stating plainly: a single pin representing a single
 * report in a sparse ward **is somebody's house**, no matter how far it has
 * been snapped, because there is nothing else nearby to confuse it with.
 * Below [PUBLIC_GEO_MIN_TICKETS] reports in the enclosing cluster, the
 * ticket gets the ward centroid or no location at all — and `geoPrecision`
 * says which, so the map can render it honestly instead of implying a
 * precision it doesn't have.
 */
export function projectTicket(args: ProjectTicketArgs): PublicTicketDoc | null {
  const {submission, clusterSubmissionCount, wardCentroid} = args;

  const tokenId = submission.tokenId;
  const constituencyId = submission.location?.constituencyId;
  // No token means nothing citable; no constituency means it belongs to no
  // dashboard yet. Either way there is nothing useful to publish.
  if (typeof tokenId !== "string" || !tokenId) return null;
  if (typeof constituencyId !== "string" || !constituencyId) return null;

  const createdDate = toDateString(submission.createdAt);
  if (!createdDate) return null;

  const lat = submission.location?.lat;
  const lng = submission.location?.lng;
  let geo: {lat: number; lng: number} | null = null;
  let geoPrecision: PublicTicketDoc["geoPrecision"] = "none";

  if (
    typeof lat === "number" &&
    typeof lng === "number" &&
    clusterSubmissionCount >= PUBLIC_GEO_MIN_TICKETS
  ) {
    geo = snapCoordinate(lat, lng, args.submissionId);
    geoPrecision = "approx-300m";
  } else if (wardCentroid) {
    geo = wardCentroid;
    geoPrecision = "ward";
  }

  return {
    tokenId,
    theme: typeof submission.theme === "string" ? submission.theme : null,
    submissionCategory:
      typeof submission.submissionCategory === "string" ?
        submission.submissionCategory :
        "problem",
    status: typeof submission.status === "string" ? submission.status : "new",
    publicSummary:
      typeof submission.publicSummary === "string" && submission.publicSummary.trim() ?
        submission.publicSummary :
        // Never fall back to the citizen's own text. A generic line is a
        // worse dashboard and a fine privacy posture; the reverse is not.
        `${submission.theme ?? "Civic"} issue reported in this area`,
    constituencyId,
    constituencyName: submission.location?.constituencyName ?? null,
    wardId: submission.location?.wardId ?? null,
    talukId: submission.location?.talukId ?? null,
    boothId: submission.location?.boothId ?? null,
    clusterId: typeof submission.clusterId === "string" ? submission.clusterId : null,
    supporterCount:
      typeof submission.supporterCount === "number" ? submission.supporterCount : 0,

    createdDate,
    createdWeek: isoWeek(createdDate),
    updatedDate: toDateString(submission.updatedAt),
    resolvedDate: toDateString(submission.resolvedAt),

    geo,
    geoPrecision,
  };
}

export function projectCluster(
  clusterId: string,
  cluster: FirebaseFirestore.DocumentData,
  constituencyName: string | null,
): PublicClusterDoc | null {
  const constituencyId = cluster.constituencyId;
  if (typeof constituencyId !== "string" || !constituencyId) return null;

  const submissionCount = cluster.submissionCount ?? 0;
  const rawCentroid = cluster.centroid;
  const centroid =
    rawCentroid &&
    typeof rawCentroid.lat === "number" &&
    typeof rawCentroid.lng === "number" &&
    submissionCount >= PUBLIC_GEO_MIN_TICKETS ?
      snapCoordinate(rawCentroid.lat, rawCentroid.lng, clusterId) :
      null;

  return {
    clusterId,
    constituencyId,
    constituencyName,
    theme: cluster.theme ?? "unknown",
    boothId: cluster.boothId ?? null,
    wardId: cluster.wardId ?? null,
    talukId: cluster.talukId ?? null,
    submissionCount,
    uniqueReporterCount: cluster.uniqueReporterCount ?? submissionCount,
    priorityScore: cluster.priorityScore ?? 50,
    demandScore: cluster.demandScore ?? null,
    demographicScore: cluster.demographicScore ?? null,
    infraGapScore: cluster.infraGapScore ?? null,
    // Already an AI-written neutral summary; scrubbed at the point it was
    // generated (see geminiClient.summarizeCluster / classifyTicket).
    summaryText: cluster.summaryText ?? "",
    title: cluster.title ?? null,
    affectedBoothRange: cluster.affectedBoothRange ?? null,
    localContext: cluster.localContext ?? null,
    centroid,
    firstReportedDate: toDateString(cluster.firstReportedAt),
    lastReportedDate: toDateString(cluster.lastReportedAt),
    weeklyCounts: cluster.weeklyCounts ?? {},
    statusCounts: cluster.statusCounts ?? {},
    hasSolutionCard: cluster.hasSolutionCard === true,
    solutionCardVersion: cluster.solutionCardVersion ?? 0,
  };
}
