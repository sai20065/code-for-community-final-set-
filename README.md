 # Prajadhwani — AI platform for constituency development planning

An AI platform for constituency development planning. Citizens submit
development **suggestions** (the primary flow) and, secondarily, **report**
civic problems — by voice, text, or photo, in any language. An MP-facing
dashboard clusters these into ranked, booth-level priorities weighed against
demographic and infrastructure data.

# Praja Dhvani (People's Priorities)

An AI platform for constituency development planning. Citizens suggest development work (the main flow) and report civic problems (secondary) by voice, text or photo, in any language. MPs get a dashboard that turns these into ranked, booth-level priorities.

## What it does
- Citizens submit **suggestions** (primary) or **problem reports** (secondary).
- AI transcribes, translates, captions photos, classifies themes and clusters similar inputs.
- The MP dashboard ranks works using demand, demographics and infrastructure gaps.

## Tech stack
- **App:** Flutter, Riverpod, go_router
- **Backend:** Firebase (Firestore in asia-south1, Auth, Cloud Functions on Node 20 / TypeScript)
- **AI:** Gemini 3.8 via Vertex AI, plus Cloud Translate
- **Maps:** OpenStreetMap (flutter_map) and Nominatim. No API keys needed.
- **Fonts:** Space Grotesk, Inter, Space Mono

## Citizen features
- **Login:** a Citizen / MP office tab on the welcome screen.
- **Sign Up:**
  - Optional Aadhaar front and back photo OCR fills name, address, pincode and ward.
  - Choose phone OTP or anonymous "skip".
  - Then language, basic info and home location (GPS plus a map pin).
- **Sign In:** for returning citizens only. It never creates an account.
- **Home:**
  - Category chips: Education, Roads, Water, Skilling, Health.
  - A "Trending near you" feed with an "I support this" button.
  - Two buttons: saffron **Submit suggestion** and vermilion **Report problem**.
- **Compose:**
  - Voice, Text or Photo input.
  - A Report/Suggest toggle.
  - An AI "Looks like: X" category hint, always tap-to-confirm.
  - A "N others nearby asked for this" insight.
  - A map pin for photo reports.
- **Mine:**
  - Suggestions show supporter count and an outcome badge.
  - Reports show a Filed → Acknowledged → In Progress → Resolved tracker.

## MP / official features
- **Login:** constituency ID + password. Accounts are provisioned out-of-band.
- **Dashboard:** live stats, with links to Ranked Works, Themes and Problem Reports.
- **Map:** booth markers sized by volume and coloured by dominant theme, with a tap-to-open detail sheet.
- **Ranked Works:** rank badges with score bars for demand, demographics and infrastructure gap.
- **Compare Proposals:** pick two works and compare them side by side, with a recommendation that cites the numbers.
- **Problem Reports:** ticket management for problem-type tickets only.

## Identity and privacy rules
- The Aadhaar number and images are **never stored**. Photos are read once in memory and discarded.
- The Aadhaar number is also regex-scrubbed server-side.
- Aadhaar OCR is a convenience only, not UIDAI verification. Manual entry always works.
- A partial OCR read counts as success, with a "check these details" hint.
- `users/{uid}.signupCompletedAt` is the authoritative marker of a saved profile.
- Citizens can only raise tickets for their own area, enforced in the app and in `firestore.rules`.
- Officials only see their own constituency's data.

## Brand
- **Colours:** indigo #2E1F8F, saffron #FFA630, teal #0B8A6C, vermilion #E0384A
- **Motif:** a 4-bar voice waveform, used in step progress and the logo
- **Mode:** light only for v1
- The old colour token names still work as aliases.

## Project status
- ✅ Firestore rules and indexes are deployed.
- ✅ Android and iOS apps are registered (`com.prajadhvani.app`).
- ✅ All three Cloud Functions are live: `extractAadhaarDetails`, `onSubmissionCreated`, `transcribeAndTranslate`.
- ✅ Blaze billing is attached, and Gemini runs through Vertex AI with no API key.
- ⏳ Booth and constituency data is a Bengaluru demo set. Swap in the real dataset when ready.

## Getting started
1. Install the Flutter SDK (stable channel).
2. Run `flutter create . --platforms=android,ios`.
3. Move the files in `firebase_config/` to `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
4. In the Firebase console, enable **Anonymous**, **Phone** and **Email/Password** sign-in. Email/Password is only for MP logins.
5. Run `flutter pub get`, then `flutter run`.
6. Optional: seed demo data with `cd functions && npm install && npm run seed:mock`.

## Good to know
- **Phone auth on Android:** a stable debug keystore is committed at `ci-keystore/prajadhvani-debug.keystore`, and its SHA-1 and SHA-256 are registered in Firebase.
- **Sideloaded APKs** show a brief reCAPTCHA before the SMS. This is expected.
- **Play Store release:** it needs its own upload key, with that SHA registered in Firebase.
- **Nominatim:** the public instance is limited to about 1 request per second, so self-host it at scale.

## Key docs
- `PrajaDhvani_ClaudeCode_BuildPrompt.md` has the full spec, design system and data model.
- `PrajaDhvani_Phase2_OnboardingSignup.md` has the onboarding and signup spec.
