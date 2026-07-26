import * as admin from "firebase-admin";
import {AGENT_MODEL, PUBLIC_GEO_MIN_TICKETS} from "../config";
import {snapCoordinate} from "../public/geoPrivacy";
import {AgentClient} from "./agentClient";
import {buildClusterContext, renderContext} from "./context";
import {loadDirectory} from "./departmentDirectory";
import {runReportCompilerAgent} from "./reportCompilerAgent";
import {runRootCauseAgent} from "./rootCauseAgent";
import {runRoutingAgent} from "./routingAgent";
import {runSolutionAgent} from "./solutionAgent";
import {AgentName, AgentTurn, SolutionCardDoc} from "./types";

/** Agent transcripts retained per cluster. Enough to compare a regeneration
 * against what it replaced; bounded so a long-lived cluster can't accumulate
 * transcripts indefinitely. */
const MAX_RETAINED_TRANSCRIPTS = 10;

/** Canary threshold. Reaching this many runs on a single cluster almost
 * certainly means a trigger guard has regressed and the chain is looping —
 * the failure mode that turns "1,200 calls total" into an unbounded bill. */
const RUNAWAY_WARN_THRESHOLD = 20;

export interface RunResult {
  card: SolutionCardDoc;
  turns: AgentTurn[];
}

/**
 * Runs the four-agent chain over one cluster and persists the result.
 *
 * The agents converse: each receives the previous agents' outputs as prior
 * turns. The chain never aborts — `AgentClient.run` resolves every failure
 * to a deterministic fallback, so a Vertex outage during the Solution agent
 * still produces a card carrying a real root cause, real routing, and
 * `degraded: true` saying plainly which agent didn't run.
 */
export async function runAgentChain(
  db: FirebaseFirestore.Firestore,
  clusterId: string,
  trigger: "threshold" | "priority" | "manual",
): Promise<RunResult | null> {
  const ctx = await buildClusterContext(db, clusterId);
  if (!ctx) {
    console.warn(`runAgentChain: cluster ${clusterId} not found`);
    return null;
  }

  const contextText = renderContext(ctx);
  const client = new AgentClient();
  client.beginRun();

  const turns: AgentTurn[] = [];
  const failedAgents: AgentName[] = [];
  const record = (turn: AgentTurn) => {
    turns.push(turn);
    if (turn.usedFallback) failedAgents.push(turn.agent);
  };

  // 1 — why does this keep happening?
  const rootCause = await runRootCauseAgent(client, ctx, contextText);
  record(rootCause.turn);

  // 2 — what should be done about that cause?
  const solutions = await runSolutionAgent(
    client, ctx, contextText, rootCause.output,
  );
  record(solutions.turn);

  // 3 — who owns it?
  const directory = await loadDirectory(db);
  const routing = await runRoutingAgent(
    client, ctx, contextText, directory, rootCause.output, solutions.output,
  );
  record(routing.turn);

  // 4 — write it up for both audiences.
  const compiled = await runReportCompilerAgent(
    client, ctx, contextText, rootCause.output, solutions.output, routing.output,
  );
  record(compiled.turn);

  const agentRunId = db.collection("_ids").doc().id;
  const cardRef = db.collection("solutionCards").doc(clusterId);

  // The card's coordinate is snapped before it is written, not on read.
  // This document is world-readable, so an exact centroid stored here would
  // be public whether or not any UI chooses to display it. Below the
  // k-anonymity floor there is no point on the card at all.
  const centroid =
    ctx.centroid && ctx.submissionCount >= PUBLIC_GEO_MIN_TICKETS ?
      snapCoordinate(ctx.centroid.lat, ctx.centroid.lng, clusterId) :
      null;

  const existing = await cardRef.get();
  const version = ((existing.data()?.version as number) ?? 0) + 1;

  const card: SolutionCardDoc = {
    clusterId,
    constituencyId: ctx.constituencyId,
    constituencyName: ctx.constituencyName,
    theme: ctx.theme,
    boothId: ctx.boothId,
    wardId: ctx.wardId,
    talukId: ctx.talukId,
    centroid,

    headline: compiled.output.headline,
    citizenSummary: compiled.output.citizenSummary,
    departmentBrief: compiled.output.departmentBrief,
    sdg: compiled.output.sdg,

    priorityScore: ctx.priorityScore,
    submissionCount: ctx.submissionCount,
    uniqueReporterCount: ctx.uniqueReporterCount,
    tokenIdsCited: ctx.knownTokenIds,

    routing: routing.output,
    rootCause: rootCause.output,
    solutions: solutions.output,

    agentRunId,
    modelId: AGENT_MODEL,
    version,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    degraded: failedAgents.length > 0,
    failedAgents,
  };

  const batch = db.batch();
  batch.set(cardRef, card);
  batch.set(cardRef.collection("agentTranscripts").doc(agentRunId), {
    agentRunId,
    clusterId,
    trigger,
    modelId: AGENT_MODEL,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    degraded: failedAgents.length > 0,
    failedAgents,
    // One document per run holding all four turns, rather than a document
    // per turn: it's the natural read granularity for the audit view, it's
    // atomic, and it's four times fewer documents.
    turns,
  });

  const clusterRef = db.collection("clusters").doc(clusterId);
  const agentRunCount = ((await clusterRef.get()).data()?.agentRunCount ?? 0) + 1;
  if (agentRunCount >= RUNAWAY_WARN_THRESHOLD) {
    console.warn(
      `Cluster ${clusterId} has run the agent chain ${agentRunCount} times — ` +
        "check the self-trigger guard in onClusterAnalysisTrigger.",
    );
  }
  batch.update(clusterRef, {
    hasSolutionCard: true,
    solutionCardVersion: version,
    agentRunCount: admin.firestore.FieldValue.increment(1),
    lastAgentRunAt: admin.firestore.FieldValue.serverTimestamp(),
    agentRunLockAt: null,
  });

  await batch.commit();
  await pruneTranscripts(cardRef);

  return {card, turns};
}

async function pruneTranscripts(
  cardRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const snap = await cardRef
    .collection("agentTranscripts")
    .orderBy("createdAt", "desc")
    .offset(MAX_RETAINED_TRANSCRIPTS)
    .get();
  if (snap.empty) return;
  const batch = cardRef.firestore.batch();
  for (const doc of snap.docs) batch.delete(doc.ref);
  await batch.commit();
}
