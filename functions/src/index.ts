import * as admin from "firebase-admin";

admin.initializeApp();

export {extractAadhaarDetails} from "./aadhaar/extractAadhaarDetails";
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
