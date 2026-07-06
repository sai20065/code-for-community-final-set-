# Prajadhwani — AI platform for constituency development planning

An AI platform for constituency development planning. Citizens submit
development **suggestions** (the primary flow) and, secondarily, **report**
civic problems — by voice, text, or photo, in any language. An MP-facing
dashboard clusters these into ranked, booth-level priorities weighed against
demographic and infrastructure data.

Rebranded from the earlier "Praja Dhvani" build: same Flutter/Firebase
foundation (Aadhaar-OCR onboarding, Firestore schema, Gemini/Bhashini
pipeline, own-area/constituency-scoped security rules all carried over
unchanged), with a new bold indigo/saffron/teal/vermilion brand, a
citizen/MP two-tab login, and a Suggest-vs-Report split across every screen.

Full product spec, design system, and data model:
[`PrajaDhvani_ClaudeCode_BuildPrompt.md`](PrajaDhvani_ClaudeCode_BuildPrompt.md).
Phase 2 (onboarding/signup) spec:
[`PrajaDhvani_Phase2_OnboardingSignup.md`](PrajaDhvani_Phase2_OnboardingSignup.md).

## Identity model — read this before touching onboarding code

Identity is **Firebase Anonymous Auth** — there is no phone number and no
Aadhaar number stored anywhere in this app. The Aadhaar Upload screen
(`lib/features/onboarding/signup/aadhaar_upload_screen.dart`) is a one-time
**convenience OCR extraction**, not verified UIDAI eKYC:

- The citizen uploads a photo of their Aadhaar; a Cloud Function
  (`functions/src/aadhaar/extractAadhaarDetails.ts`) reads it with Gemini
  vision **once, in memory**, extracts `{name, address, pincode}`, and
  discards the image immediately. The image is never written to Cloud
  Storage, Firestore, or disk at any point.
- The Aadhaar number itself is never returned to the client and is
  regex-scrubbed server-side as defense-in-depth even if the model includes
  one by mistake.
- **This proves nothing about who uploaded the document.** There is no
  cryptographic/UIDAI verification step. Manual entry is always available
  and never blocks onboarding if OCR fails or looks wrong.
- This is a deliberate reversal of this project's earlier "no Aadhaar
  scanning" rule, made at the requesting user's explicit direction after
  being shown the legal-risk tradeoff — see the git history for that
  conversation if you need the reasoning again later.

## Brand system

- **Color** (`lib/app/theme.dart` `AppColors`): indigo `#2E1F8F` (primary),
  saffron `#FFA630` (accent/CTA), teal `#0B8A6C` (success/resolution),
  vermilion `#E0384A` (urgent/escalated), ink/paper neutrals. The original
  Trust-Blue-era token names (`trustBlue`, `marigoldOrange`, `leafGreen`,
  `coralRed`, `warmOffWhite`, `charcoal`) are kept as aliases onto these new
  hues, so every existing screen picked up the rebrand without a rename.
- **Type**: Space Grotesk (headings, via `google_fonts`) + Inter (body) +
  Space Mono (ticket IDs/stats, via the existing `fontFamily: 'monospace'`
  usage).
- **Motif**: a 4-bar "voice waveform" replaces plain dots for step-progress
  (`lib/shared/widgets/onboarding_progress_stepper.dart`) and the splash/
  welcome screen logo lockup.
- Light mode only for v1, per spec.

## Status

- `lib/app/theme.dart` — full brand `ColorScheme`, typography, `AppRadii`
  (14–22px), `appCardShadow` (soft layered shadow), category/status color
  mapping (now including `skilling`).
- `lib/app/router.dart` — `go_router` config for citizen, MP office, and
  onboarding routes, including `/welcome`, `/official/works`,
  `/official/compare`.
- `lib/app/providers/` — Riverpod providers: `authStateProvider`,
  `selectedLanguageProvider` / `onboardingProgressProvider`
  (shared_preferences-backed, so a killed/reopened app resumes onboarding at
  the right step), `currentUserProfileProvider` (live `users/{uid}` doc —
  used everywhere an official needs their own `constituencyId`, and
  everywhere a citizen's location/language needs autofilling).
- `lib/core/` — models + services. `SubmissionModel` gained
  `supporterCount`/`supporterIds` (the "I support this" mechanic,
  transaction-safe via `FirestoreService.toggleSupport`). `ClusterModel`
  gained `title`/`demandScore`/`demographicScore`/`infraGapScore`/
  `localContext`/`affectedBoothRange` — it now doubles as the "development
  work" entity behind the ranked-works panel and compare tool.
  `FirestoreService.watchTrendingSuggestions` powers the Home feed.
- **Login** (`lib/features/onboarding/welcome_screen.dart`): Citizen / MP
  office tabs. Citizen tab enters the existing Language → Aadhaar Upload →
  Basic Info → Location flow unchanged. MP office tab is a real
  constituency-ID + password login (`AuthService.signInOfficial`, mapped
  internally to Firebase email/password) — officials are provisioned
  out-of-band, not self-registered. Splash checks the signed-in user's
  Firestore `role` first so an official session never falls into the
  citizen onboarding-step routing.
- `lib/features/citizen/home/home_screen.dart` — booth/constituency
  context, category filter chips (Education/Roads/Water/Skilling/Health),
  a "Trending near you" feed of ranked suggestions with supporter counts
  and an "I support this" button, and two FABs distinct by priority: saffron
  "Submit suggestion" (primary) bottom-right, vermilion-outline "Report
  problem" (secondary) bottom-left.
- Compose screens (`lib/features/citizen/compose/`) share an
  `InputModeSwitcher` (Voice/Text/Photo) and `CategoryToggleWidget`
  (Report/Suggest), default-preset by which Home FAB launched the flow. Text
  compose shows a "Looks like: X" AI-suggested category chip (on-device
  keyword heuristic standing in for the real Gemini classification that
  runs server-side once a ticket is created) — never auto-assigned, always
  tap-to-confirm — plus a "N others nearby have asked for this too" insight
  chip once a category is set. Photo compose adds a geolocation pin
  (defaulted to home, tap-to-adjust) for Report tickets, since a civic
  problem's exact spot often isn't the citizen's home address.
- `lib/features/citizen/reports/my_reports_screen.dart` ("Mine") — cards
  branch by ticket type: suggestions show supporter count + an outcome
  badge ("In development plan" / "Under review"); reports show the
  Filed→Acknowledged→In Progress→Resolved stepper (relabeled from
  New/Reviewed — the underlying `SubmissionStatus` enum is unchanged).
- `lib/features/official/` —
  - `dashboard/` — real aggregated stats, links to Ranked Works/Themes/
    Problem Reports.
  - `map/constituency_map_screen.dart` — booth markers sized by
    `submissionVolume`, colored by `dominantTheme`, with an on-map legend
    and a tap-to-open callout (`BoothDetailSheet`) showing submission
    count/dominant theme/local context up top, then AI cluster summaries.
  - `works/ranked_works_screen.dart` (new) — numbered rank badges +
    segmented score bars (demand/demographic/infra-gap proportions) per
    `ClusterModel`, so the composite priority number is never a black box.
  - `works/compare_proposals_screen.dart` (new) — pick any two ranked works,
    compare their stats side by side, with a recommendation line generated
    from those same numbers (cites specific figures, not a bare "we
    recommend X").
  - `tickets/ticket_management_screen.dart` — renamed "Problem Reports";
    filters to `category == problem` only (suggestions live in Ranked
    Works instead), status labels relabeled to match the Mine screen.
  - Every official screen is scoped to the signed-in official's own
    `constituencyId`, enforced both in the UI (`currentUserProfileProvider`)
    and in `firestore.rules` (`isOfficialForConstituency`).
- `functions/` — Cloud Functions backend (TypeScript), **scaffolded but not
  deployed** (see below): `extractAadhaarDetails` (Aadhaar OCR),
  `onSubmissionCreated` (the main Gemini + Bhashini pipeline: transcription,
  translation, photo captioning, theme classification, clustering, priority
  scoring), `transcribeAndTranslate` (standalone retry/testing callable),
  `scripts/seedMockData.ts` (one-off admin script — realistic Bengaluru-area
  constituency/booths/clusters/sample-tickets so the new Home feed, demand
  map, ranked-works panel, and compare tool are demoable without waiting on
  real citizen data or a deployed AI pipeline: `cd functions && npm install
  && npm run seed:mock`).

## Firebase / Google Cloud project

Wired to the real project **`code-for-community-e2cf2`** ("code for
community"), `.firebaserc` included:

- ✅ **Firestore** — Native-mode, `asia-south1`. `firestore.rules` and
  `firestore.indexes.json` are deployed live and include the new own-area
  ticket-creation check and official constituency-scoping.
- ✅ **Android + iOS apps registered** (`com.prajadhvani.app`).
  `lib/firebase_options.dart` has real API keys/app IDs — these are client
  identifiers, not secrets, safe to commit.
- ⏳ **Anonymous + Email/Password sign-in providers** — neither toggled on
  yet (replaces the old "enable Phone" task, which is now moot). These
  provider toggles can't be reliably flipped via API — each needs a
  one-time console visit. **To finish:** open
  [Authentication → Sign-in method](https://console.firebase.google.com/project/code-for-community-e2cf2/authentication/providers)
  and enable both **Anonymous** (citizens) and **Email/Password** (MP
  office login — `AuthService.signInOfficial` maps a constituency ID to a
  synthetic `{id}@mp.prajadhwani.app` address under the hood).
- ⏳ **MP official accounts must be provisioned manually** — there's no
  self-registration. For each MP, create a Firebase Auth user with email
  `{constituencyId}@mp.prajadhwani.app` and a password (Firebase console →
  Authentication → Add user, or the Admin SDK), then create their
  `users/{uid}` Firestore doc with `role: "official"` and their
  `constituencyId` set.
- ⏳ **Cloud Functions + Gemini + Bhashini** — scaffolded in `functions/` but
  **not deployed**. Blocked on:
  1. **GCP Blaze billing** attached to `code-for-community-e2cf2` — Cloud
     Functions 2nd gen requires this regardless of which Gemini access path
     is used. Attach at
     [console.cloud.google.com/billing](https://console.cloud.google.com/billing/linkedaccount?project=code-for-community-e2cf2).
  2. **`GEMINI_API_KEY`** — generate a free-tier key at
     [aistudio.google.com](https://aistudio.google.com) (Gemini Developer
     API — not Vertex AI Model Garden; no self-hosted Gemma endpoint is used
     here, it's too costly/complex for this project's scale).
  3. **`BHASHINI_API_KEY`, `BHASHINI_ASR_PIPELINE_ID`,
     `BHASHINI_TRANSLATION_PIPELINE_ID`** — register at
     [bhashini.gov.in](https://bhashini.gov.in) (ULCA) and take the
     API key + pipeline ids issued for your registration. **Verify the
     exact request/response shape in `functions/src/lib/bhashiniClient.ts`
     against what your registration's pipeline config actually returns**
     before deploying — Bhashini's contract can vary per registered
     pipeline.

  Once all three are ready:
  ```
  firebase functions:secrets:set GEMINI_API_KEY
  firebase functions:secrets:set BHASHINI_API_KEY
  firebase functions:secrets:set BHASHINI_ASR_PIPELINE_ID
  firebase functions:secrets:set BHASHINI_TRANSLATION_PIPELINE_ID
  cd functions && npm install && cd ..
  firebase deploy --only functions
  ```
- ⏳ **`booths`/`constituencies` reference data** — not seeded (you said
  you'd provide the real dataset). `resolveConstituency` in
  `location_service.dart` looks up `booths` where `pincodesCovered`
  array-contains the citizen's pincode; nothing will map to a constituency
  until real booth documents exist with that field populated. Schema:
  `booths/{id}`: `constituencyId, name, lat, lng, pincodesCovered: string[],
  openIssueCount`; `constituencies/{id}`: `name, state, mpUserId,
  boundaryGeoJson?`.
- The native `google-services.json` / `GoogleService-Info.plist` are staged
  in [`firebase_config/`](firebase_config/) — move them to
  `android/app/google-services.json` / `ios/Runner/GoogleService-Info.plist`
  once `flutter create` generates those folders.
- **Maps** now use free OpenStreetMap tiles (`flutter_map` + `latlong2`, no
  API key) instead of Google Maps — no billing needed for mapping itself.
  Geocoding uses OSM's free Nominatim service; production-scale usage should
  eventually move to a self-hosted Nominatim instance (public-instance fair
  use is ~1 req/sec).

## Getting started

1. Install the [Flutter SDK](https://flutter.dev) (stable channel).
2. `flutter create . --platforms=android,ios` (won't overwrite existing
   `lib/` code or `firebase_options.dart`).
3. Move the staged config files from `firebase_config/` into
   `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist`.
4. Enable **Anonymous** sign-in in the Firebase console (see above).
5. `flutter pub get`, then `flutter run`.
6. To bring the AI pipeline online: attach Blaze billing, get a Gemini API
   key and Bhashini credentials, set the secrets, then
   `firebase deploy --only functions` (see above). Everything else in the
   app works without this — tickets just won't get auto-classified/
   clustered/transcribed until the functions are deployed.

## Non-negotiable rules that still apply

- Citizens can only raise tickets about their **own** area — a ticket's
  location is always derived from the citizen's own profile
  (`pincodeHome`/`constituencyId`), never freely chosen, enforced in both
  the compose screens and `firestore.rules`.
- Officials only ever see their **own** constituency's tickets, map, and
  analytics — never another MP's.
- No Aadhaar number and no Aadhaar image are ever stored — see the
  Identity model section above.
