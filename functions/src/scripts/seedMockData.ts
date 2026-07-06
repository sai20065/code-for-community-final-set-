/**
 * One-off admin seed script — NOT deployed as a Cloud Function. Populates
 * realistic Bengaluru-area demo data (one constituency, five booths, six
 * ranked development-work clusters, and a handful of sample suggestion/
 * report tickets) so the citizen Home trending feed, the booth demand map,
 * the ranked-works panel, and the compare tool are all demoable without
 * waiting for real citizen submissions or the Gemini/Bhashini pipeline to
 * be deployed.
 *
 * This does NOT touch `users/{uid}` — it only seeds the shared reference/
 * analytics collections (`constituencies`, `booths`, `clusters`) plus a
 * few `submissions` docs owned by a placeholder demo user id, so it's safe
 * to run against a project that already has real citizens signed up.
 *
 * Run with a service account that has Firestore write access:
 *   cd functions
 *   npm install
 *   npx ts-node src/scripts/seedMockData.ts
 */
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

const CONSTITUENCY_ID = "blr-north";
const DEMO_USER_ID = "demo-seed-user";

async function main() {
  await db.collection("constituencies").doc(CONSTITUENCY_ID).set({
    name: "Bengaluru North",
    state: "Karnataka",
    mpUserId: "",
    boundaryGeoJson: null,
  });

  const booths = [
    {
      id: "booth-hebbal",
      name: "Hebbal Ward Booth 12",
      lat: 13.0358,
      lng: 77.5971,
      pincodesCovered: ["560024", "560032"],
      openIssueCount: 18,
      submissionVolume: 42,
      dominantTheme: "roads",
      localContext: "Nearest govt school 3.1km away; local roads see heavy peak-hour traffic.",
    },
    {
      id: "booth-yelahanka",
      name: "Yelahanka Ward Booth 4",
      lat: 13.1005,
      lng: 77.5963,
      pincodesCovered: ["560064"],
      openIssueCount: 6,
      submissionVolume: 28,
      dominantTheme: "water",
      localContext: "Borewell-dependent supply; municipal Cauvery line not yet extended here.",
    },
    {
      id: "booth-jalahalli",
      name: "Jalahalli Ward Booth 9",
      lat: 13.0453,
      lng: 77.5442,
      pincodesCovered: ["560013", "560014"],
      openIssueCount: 11,
      submissionVolume: 35,
      dominantTheme: "education",
      localContext: "Single govt school serves 3 wards; capacity gap ~340 seats.",
    },
    {
      id: "booth-vidyaranyapura",
      name: "Vidyaranyapura Booth 7",
      lat: 13.0714,
      lng: 77.5548,
      pincodesCovered: ["560097"],
      openIssueCount: 3,
      submissionVolume: 15,
      dominantTheme: "skilling",
      localContext: "High youth unemployment reported; nearest ITI is 8km away.",
    },
    {
      id: "booth-rtnagar",
      name: "R.T. Nagar Booth 2",
      lat: 13.0230,
      lng: 77.5950,
      pincodesCovered: ["560032"],
      openIssueCount: 9,
      submissionVolume: 22,
      dominantTheme: "health",
      localContext: "Nearest PHC serves 40,000+ residents; frequent medicine stockouts reported.",
    },
  ];

  for (const booth of booths) {
    const { id, ...data } = booth;
    await db.collection("booths").doc(id).set({ constituencyId: CONSTITUENCY_ID, ...data });
  }

  const clusters = [
    {
      id: "cluster-jalahalli-school",
      boothId: "booth-jalahalli",
      theme: "education",
      title: "New government school block — Jalahalli",
      summaryText: "128 citizens across 3 booths have asked for additional school capacity near Jalahalli.",
      submissionCount: 128,
      sampleSubmissionIds: [],
      priorityScore: 88,
      demandScore: 45,
      demographicScore: 28,
      infraGapScore: 15,
      affectedBoothRange: "Booths 7-9",
      centroidVector: [],
    },
    {
      id: "cluster-vidyaranyapura-iti",
      boothId: "booth-vidyaranyapura",
      theme: "skilling",
      title: "Skilling & livelihoods training centre — Vidyaranyapura",
      summaryText: "73 citizens requested a local skilling centre, citing an 8km commute to the nearest ITI.",
      submissionCount: 73,
      sampleSubmissionIds: [],
      priorityScore: 71,
      demandScore: 30,
      demographicScore: 22,
      infraGapScore: 19,
      affectedBoothRange: "Booth 7",
      centroidVector: [],
    },
    {
      id: "cluster-hebbal-roads",
      boothId: "booth-hebbal",
      theme: "roads",
      title: "Road widening & pothole repair — Hebbal main road",
      summaryText: "96 reports of potholes and congestion along the Hebbal main stretch.",
      submissionCount: 96,
      sampleSubmissionIds: [],
      priorityScore: 74,
      demandScore: 38,
      demographicScore: 20,
      infraGapScore: 16,
      affectedBoothRange: "Booths 11-13",
      centroidVector: [],
    },
    {
      id: "cluster-yelahanka-water",
      boothId: "booth-yelahanka",
      theme: "water",
      title: "Cauvery water line extension — Yelahanka",
      summaryText: "54 households report borewell-only supply; requesting municipal line extension.",
      submissionCount: 54,
      sampleSubmissionIds: [],
      priorityScore: 65,
      demandScore: 25,
      demographicScore: 18,
      infraGapScore: 22,
      affectedBoothRange: "Booth 4",
      centroidVector: [],
    },
    {
      id: "cluster-rtnagar-health",
      boothId: "booth-rtnagar",
      theme: "health",
      title: "Primary health centre capacity upgrade — R.T. Nagar",
      summaryText: "41 citizens flagged long queues and medicine stockouts at the local PHC.",
      submissionCount: 41,
      sampleSubmissionIds: [],
      priorityScore: 58,
      demandScore: 20,
      demographicScore: 24,
      infraGapScore: 14,
      affectedBoothRange: "Booth 2",
      centroidVector: [],
    },
    {
      id: "cluster-jalahalli-drainage",
      boothId: "booth-jalahalli",
      theme: "sanitation",
      title: "Storm drain desilting — Jalahalli Cross",
      summaryText: "22 reports of waterlogging near Jalahalli Cross during monsoon.",
      submissionCount: 22,
      sampleSubmissionIds: [],
      priorityScore: 40,
      demandScore: 12,
      demographicScore: 10,
      infraGapScore: 18,
      affectedBoothRange: "Booth 9",
      centroidVector: [],
    },
  ];

  for (const cluster of clusters) {
    const { id, ...data } = cluster;
    await db.collection("clusters").doc(id).set({ constituencyId: CONSTITUENCY_ID, ...data });
  }

  const now = admin.firestore.Timestamp.now();
  const sampleTickets = [
    {
      id: "demo-ticket-1",
      type: "text",
      submissionCategory: "feedback",
      theme: "education",
      rawText: "We need a bigger school building near Jalahalli — classrooms are overcrowded.",
      supporterCount: 41,
      supporterIds: [],
      status: "reviewed",
      pincode: "560013",
      boothId: "booth-jalahalli",
    },
    {
      id: "demo-ticket-2",
      type: "text",
      submissionCategory: "feedback",
      theme: "skilling",
      rawText: "A skilling centre near Vidyaranyapura would help a lot of unemployed youth here.",
      supporterCount: 29,
      supporterIds: [],
      status: "new",
      pincode: "560097",
      boothId: "booth-vidyaranyapura",
    },
    {
      id: "demo-ticket-3",
      type: "photo",
      submissionCategory: "problem",
      theme: "roads",
      rawText: "Large pothole near the Hebbal flyover service road.",
      supporterCount: 0,
      supporterIds: [],
      status: "inProgress",
      pincode: "560024",
      boothId: "booth-hebbal",
    },
  ];

  for (const t of sampleTickets) {
    const { id, ...rest } = t;
    await db
      .collection("submissions")
      .doc(id)
      .set({
        userId: DEMO_USER_ID,
        inputMode: rest.type,
        language: "en",
        clusterId: null,
        priorityScore: null,
        mediaUrl: null,
        transcript: null,
        translatedText: null,
        tokenId: `PD-2026-${String(Math.floor(Math.random() * 900000) + 100000)}`,
        createdAt: now,
        location: {
          pincode: rest.pincode,
          boothId: rest.boothId,
          constituencyId: CONSTITUENCY_ID,
          lat: null,
          lng: null,
        },
        ...rest,
      });
  }

  console.log("Seed complete: 1 constituency, 5 booths, 6 clusters, 3 sample tickets.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
