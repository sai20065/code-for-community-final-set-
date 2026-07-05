# Praja Dhvani (ಪ್ರಜಾ ಧ್ವನಿ / प्रजा ध्वनि — "Voice of the People")

AI-powered civic grievance & constituency insights app. Citizens raise
tickets — problems (potholes, water, electricity, sanitation, etc.) or
feedback on development projects — by voice, text, or photo; recurring
themes are AI-clustered and ranked so MPs/officials see a prioritized,
color-coded picture of their own constituency's demand.

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

## Status

- `lib/app/theme.dart` — full `ColorScheme` and category/status color mapping.
- `lib/app/router.dart` — `go_router` config for both nav shells (citizen +
  official).
- `lib/app/providers/` — Riverpod providers: `authStateProvider`,
  `selectedLanguageProvider` / `onboardingProgressProvider` (shared_preferences-
  backed, so a killed/reopened app resumes onboarding at the right step),
  `currentUserProfileProvider` (live `users/{uid}` doc — used everywhere an
  official needs their own `constituencyId`, and everywhere a citizen's
  location/language needs autofilling).
- `lib/core/` — models + services. `UserModel` no longer has a `phone`
  field. `FirestoreService.getOrCreateUser` is called right after anonymous
  sign-in with whatever Aadhaar OCR (or manual entry) produced. New
  aggregation helpers (`countSubmissionsSince`, `countResolvedSubmissions`,
  `averageResolutionTime`, `watchBoothsForConstituency`,
  `watchClustersForConstituency`) power the official dashboard/analytics
  without needing a separate Cloud Function.
- `lib/features/onboarding/` — Splash → Language Select → **Aadhaar Upload**
  (replaces phone/OTP entirely) → Basic Info (name prefilled, age) →
  Location Setup (pincode prefilled + **OpenStreetMap** tap-to-place pin,
  replacing Google Maps) → Home.
- `lib/features/citizen/` — Home, compose (text/voice/photo, each with a
  **"Report a problem" / "Feedback on a project"** toggle), Ticket
  Confirmation receipt, My Tickets, Ticket Detail. Compose screens now pull
  `location`/`language` from the citizen's own profile (never freely
  chosen) and actually upload voice/photo media via `StorageService`
  (previously defined but unused).
- `lib/features/official/` — Dashboard (real aggregated stats), Constituency
  Map (OpenStreetMap, booths scoped to the signed-in official's own
  constituency), Booth Detail (real `clusters` data), Themes Overview (real
  bar/line charts from live data), Ticket Management (real list, working
  status dropdown + bulk update). **Every official screen is scoped to the
  signed-in official's own `constituencyId`** — enforced both in the UI
  (`currentUserProfileProvider`) and in `firestore.rules`
  (`isOfficialForConstituency`).
- `functions/` — Cloud Functions backend (TypeScript), **scaffolded but not
  deployed** (see below): `extractAadhaarDetails` (Aadhaar OCR),
  `onSubmissionCreated` (the main Gemini + Bhashini pipeline: transcription,
  translation, photo captioning, theme classification, clustering, priority
  scoring), `transcribeAndTranslate` (standalone retry/testing callable).

## Firebase / Google Cloud project

Wired to the real project **`code-for-community-e2cf2`** ("code for
community"), `.firebaserc` included:

- ✅ **Firestore** — Native-mode, `asia-south1`. `firestore.rules` and
  `firestore.indexes.json` are deployed live and include the new own-area
  ticket-creation check and official constituency-scoping.
- ✅ **Android + iOS apps registered** (`com.prajadhvani.app`).
  `lib/firebase_options.dart` has real API keys/app IDs — these are client
  identifiers, not secrets, safe to commit.
- ⏳ **Anonymous sign-in provider** — not yet toggled on (replaces the old
  "enable Phone" task, which is now moot). Like Phone, Anonymous can't be
  reliably toggled via API — it needs a one-time console visit. **To
  finish:** open
  [Authentication → Sign-in method](https://console.firebase.google.com/project/code-for-community-e2cf2/authentication/providers)
  and enable **Anonymous**.
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
