import * as admin from "firebase-admin";

admin.initializeApp();

// Citizen username/password accounts: security-question password recovery
// (no email or phone on file to send a reset link to).
export {
  getSecurityQuestion,
  resetPasswordWithSecurityQuestion,
  setSecurityQuestion,
} from "./citizens/securityQuestion";
// Civic intelligence layer — the four-agent chain (root cause → solution →
// routing → report compiler) and its manual re-run entry point.
export {onClusterAnalysis} from "./agents/onClusterAnalysisTrigger";
export {runClusterAgents} from "./agents/runClusterAgentsCallable";
export {resolveConstituencyForLocation} from "./constituencies/resolveConstituencyForLocation";
export {mpFirstTimeSetup} from "./officials/mpFirstTimeSetup";
export {mpForgotCredentials} from "./officials/mpForgotCredentials";
// Area-scoped AI briefing + PDF report for every official type (and the
// statewide view for admins). generateConstituencyReport is the old name.
export {generateAreaReport, generateConstituencyReport} from "./reports/generateConstituencyReport";
export {getAreaBriefing} from "./reports/areaBriefing";
// Self-registered MLAs / officers are approved by a Prajadhwani admin.
export {reviewOfficialApplication} from "./officials/reviewOfficialApplication";
export {getAdminOverview} from "./officials/adminOverview";
export {onSubmissionCreated} from "./submissions/onSubmissionCreated";
// Anonymised projections behind the public dashboard. Deliberately separate
// functions from the AI pipeline so the two have independent failure
// domains — see functions/src/public/projection.ts for the field allowlist.
export {onSubmissionWrittenPublicProjection} from "./public/onSubmissionWritten";
export {onClusterWrittenPublicProjection} from "./public/onClusterWritten";
// MLA / MP leaderboard over public tickets, rebuilt every 6 hours.
export {refreshLeaderboards} from "./public/leaderboard";
// Citizen feed: opt-in blurred photos, "Me too", moderated comments.
export {onSubmissionPhotoConsent} from "./public/publishPhoto";
export {toggleReportSupport} from "./public/toggleSupport";
export {
  onFeedCommentCreated,
  onFeedCommentDeleted,
  reportFeedComment,
} from "./public/feedComments";
export {transcribeAndTranslate} from "./submissions/transcribeAndTranslate";
