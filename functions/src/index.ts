import * as admin from "firebase-admin";

admin.initializeApp();

export {extractAadhaarDetails} from "./aadhaar/extractAadhaarDetails";
export {resolveConstituencyForLocation} from "./constituencies/resolveConstituencyForLocation";
export {mpFirstTimeSetup} from "./officials/mpFirstTimeSetup";
export {mpForgotCredentials} from "./officials/mpForgotCredentials";
export {generateConstituencyReport} from "./reports/generateConstituencyReport";
export {onSubmissionCreated} from "./submissions/onSubmissionCreated";
export {transcribeAndTranslate} from "./submissions/transcribeAndTranslate";
