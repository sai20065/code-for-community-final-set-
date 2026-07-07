import * as admin from "firebase-admin";

admin.initializeApp();

export {extractAadhaarDetails} from "./aadhaar/extractAadhaarDetails";
export {resolveConstituencyForLocation} from "./constituencies/resolveConstituencyForLocation";
export {onSubmissionCreated} from "./submissions/onSubmissionCreated";
export {transcribeAndTranslate} from "./submissions/transcribeAndTranslate";
