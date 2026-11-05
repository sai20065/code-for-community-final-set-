/**
 * Runs the scheduled leaderboard rebuild once, now. NOT deployed.
 *   npm run leaderboard:now
 */
import * as admin from "firebase-admin";
import {rebuildLeaderboards} from "../public/leaderboard";

admin.initializeApp({projectId: "code-for-community-e2cf2"});

rebuildLeaderboards(admin.firestore())
  .then((counts) => console.log("Rebuilt leaderboards:", counts))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
