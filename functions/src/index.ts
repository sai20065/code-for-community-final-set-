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
export {generateConstituencyReport} from "./reports/generateConstituencyReport";
export {onSubmissionCreated} from "./submissions/onSubmissionCreated";
// Anonymised projections behind the public dashboard. Deliberately separate
// functions from the AI pipeline so the two have independent failure
// domains — see functions/src/public/projection.ts for the field allowlist.
export {onSubmissionWrittenPublicProjection} from "./public/onSubmissionWritten";
export {onClusterWrittenPublicProjection} from "./public/onClusterWritten";
export {transcribeAndTranslate} from "./submissions/transcribeAndTranslate";
