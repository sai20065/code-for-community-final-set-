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

Sign Up and Sign In are **deliberately separate flows**
(`lib/features/onboarding/signup_screen.dart` and `signin_screen.dart`), not
one combined "continue" action. Sign Up always creates a brand-new
credential and stamps `users/{uid}.signupCompletedAt` — the authoritative
"this citizen has a real, saved profile" marker, which `SplashScreen` and
`SignInScreen` both trust over any local per-device onboarding-progress
state (fixing a real bug: a citizen who signed up on one device and signed
back in on a fresh install used to get pushed through onboarding again,
since progress was only ever stored in local `shared_preferences`). Sign In
never creates an account — a phone number with no matching `signupCompletedAt`
profile is treated as "no account found, please Sign Up" and signed back
out.

Citizens have **two** ways to get a Firebase account, both landing on the
same `users/{uid}` shape: **Phone** (real Firebase Phone Auth with SMS OTP —
a portable identity that survives a reinstall) and **Anonymous** (no
credential at all, still offered as "skip"). Citizen **email/password was
removed** — Firebase has no native email-OTP and email magic-links are
unreliable on a sideloaded APK, so phone OTP is the single "verify yourself"
path. (Officials still sign in with a constituency ID + password on the MP
tab — that's separate, internal email/password auth.) The `signInMethod`
field on `users/{uid}` records which method was used. The Aadhaar number
itself is never stored anywhere in this app.

Home location is captured on `SignUpScreen` via a **"Use my location"
button** (GPS, reused from `LocationService.getCurrentLatLng`) plus a
tappable OpenStreetMap pin, instead of a free-text address field. The raw
`location.lat`/`lng` is stored, along with a best-effort reverse-geocoded
`addressHome` label (`LocationService.reverseGeocode`, Nominatim, no API
key).

Aadhaar capture (front **and** back — the back side often carries the full
address the front truncates, so capturing both improves accuracy, though
neither is ever required) lives on `SignUpScreen`. It's a one-time
**convenience OCR extraction**, not verified UIDAI eKYC:

- The citizen uploads photo(s) of their Aadhaar; a Cloud Function
  (`functions/src/aadhaar/extractAadhaarDetails.ts`) reads them with an
  NVIDIA NIM document-understanding vision model (see
  `functions/src/lib/nvidiaClient.ts` — `nvidia/llama-3.1-nemotron-nano-vl-8b-v1`)
  **once, in memory**, extracts `{name, address, pincode, wardNumber}`, and
  discards the images immediately. They are never written to Cloud Storage,
  Firestore, or disk at any point. Every other AI task in this app
  (transcription, translation, photo captioning, theme classification,
  cluster summarization) stays on Gemini — NVIDIA is scoped to Aadhaar OCR
  only. Note this is a carefully engineered extraction prompt against a
  hosted model, not real fine-tuning — true fine-tuning would need NVIDIA
  NeMo Customizer, a labeled dataset, and a GPU training job, a separate and
  much larger effort than this app's scope.
- The extraction callable requires an authenticated caller, so the app
  establishes an anonymous Firebase session the moment Sign Up opens (before
  the citizen picks phone/anonymous) — otherwise the call is rejected with
  `unauthenticated` and OCR silently fails.
- The Aadhaar number itself is never returned to the client and is
  regex-scrubbed server-side as defense-in-depth even if the model includes
  one by mistake.
- **This proves nothing about who uploaded the document.** There is no
  cryptographic/UIDAI verification step. Manual entry (including an optional
  ward number field) is always available and never blocks onboarding if OCR
  fails or looks wrong.

**Phone Auth signing requirement:** Firebase Phone Auth on Android requires
the app's signing SHA-1/SHA-256 to be registered in the Firebase project.
Because CI used to generate a fresh throwaway debug keystore every build, the
fingerprint changed each run and could never be registered — so phone auth
failed outright. This is now fixed: a **stable keystore is committed at
`ci-keystore/prajadhvani-debug.keystore`** (standard Android debug identity),
the workflow copies it to `~/.android/debug.keystore` before building so
every APK shares one fingerprint, and that fingerprint's SHA-1 + SHA-256 are
registered in Firebase. Because the APK is sideloaded (not from Play Store),
Play Integrity app-recognition won't pass, so Firebase falls back to a brief
reCAPTCHA web challenge before the SMS — expected, and it now works. This
keystore is a debug/sideload signing key only; a real Play Store release must
use its own upload key (whose SHA must also be registered).

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
  office tabs. The Citizen tab is a chooser between `SignUpScreen` (Aadhaar
  front/back OCR + sign-in method choice: Phone OTP / Email+password /
  anonymous "skip", then Language → Basic Info → Location as before) and
  `SignInScreen` (strict sign-in only for returning citizens) — see
  "Identity model" above. MP office tab is unchanged: a real
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
- ❌ **Authentication itself has never been initialized** for this project
  — verified directly against the Identity Toolkit REST API (not just the
  console), which returns `CONFIGURATION_NOT_FOUND` for every call. This is
  a bigger gap than "a provider isn't toggled": it means the Authentication
  product has never been switched on at all, so *no* sign-in method —
  Anonymous, Phone, or Email/Password — currently works, regardless of what
  may have been clicked in the console. **To finish:** open
  [Authentication](https://console.firebase.google.com/project/code-for-community-e2cf2/authentication)
  and click "Get started" if it hasn't been, then enable **Anonymous**,
  **Phone**, and **Email/Password** under Sign-in method (citizens can now
  choose any of the three on the Welcome screen; MP office login also maps
  onto Email/Password — `AuthService.signInOfficial` maps a constituency ID
  to a synthetic `{id}@mp.prajadhwani.app` address under the hood). Phone
  additionally needs its own quota/reCAPTCHA setup on first enable — see the
  Phone Auth caveat under "Identity model" above.
- ⏳ **MP official accounts must be provisioned manually** — there's no
  self-registration. For each MP, create a Firebase Auth user with email
  `{constituencyId}@mp.prajadhwani.app` and a password (Firebase console →
  Authentication → Add user, or the Admin SDK), then create their
  `users/{uid}` Firestore doc with `role: "official"` and their
  `constituencyId` set.
- ✅ **Cloud Functions + Gemini + Cloud Translate** — deployed and live
  (verified directly against the project: all three functions —
  `extractAadhaarDetails`, `onSubmissionCreated`, `transcribeAndTranslate` —
  are running in `asia-south1` on Node 20). Blaze billing is attached and
  `GEMINI_API_KEY` is already configured as a secret. The Bhashini
  integration mentioned in older versions of this doc has been fully
  replaced by Gemini audio transcription + Cloud Translate — there is no
  `bhashiniClient.ts` anymore and no separate Bhashini credentials needed.
- ⏳ **`booths`/`constituencies` reference data** — was unseeded; a starter
  demo dataset (one constituency, five booths, six ranked-work clusters, a
  few sample tickets — Bengaluru-area, from `functions/src/scripts/
  seedMockData.ts`) has since been loaded directly into Firestore so the
  map/rankings/trending feed have something to show. Swap in the real
  dataset when it's ready — `resolveConstituency` in `location_service.dart`
  looks up `booths` where `pincodesCovered` array-contains the citizen's
  pincode. Schema: `booths/{id}`: `constituencyId, name, lat, lng,
  pincodesCovered: string[], openIssueCount`; `constituencies/{id}`: `name,
  state, mpUserId, boundaryGeoJson?`.
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
4. In the Firebase console, initialize Authentication if it hasn't been
   already, then enable **Anonymous**, **Phone**, and **Email/Password**
   sign-in (see above) — the app can't sign anyone in, citizen or MP,
   until this is done.
5. `flutter pub get`, then `flutter run`.

The Cloud Functions AI pipeline (Gemini + Cloud Translate) is already
deployed and billed — no further setup needed there.

## Non-negotiable rules that still apply

- Citizens can only raise tickets about their **own** area — a ticket's
  location is always derived from the citizen's own profile
  (`pincodeHome`/`constituencyId`), never freely chosen, enforced in both
  the compose screens and `firestore.rules`.
- Officials only ever see their **own** constituency's tickets, map, and
  analytics — never another MP's.
- No Aadhaar number and no Aadhaar image are ever stored — see the
  Identity model section above.
