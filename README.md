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
- **Maps:** OpenFreeMap vector tiles on Android, OpenStreetMap raster tiles on web and as the fallback (flutter_map), Nominatim for addresses. All free, no API keys. Directions open in Google Maps via a plain link, also keyless.
- **Wards:** two Bengaluru layers, switchable on the map — the 369 GBA wards (2025) and the 198 BBMP wards (2010, DataMeet, CC BY-SA 2.5 India).
- **Fonts:** Space Grotesk, Inter, Space Mono

## Citizen features
- **Login:** a Citizen / MP office choice on the welcome screen.
- **Sign Up:** name, **username and password**, and a security question. No email, phone number, OTP or ID document. Then language, basic info and home location (GPS plus a map pin).
- **Sign In:** username + password, for returning citizens only. It never creates an account.
- **Forgot password:** enter the username, answer the security question, set a new password. Five wrong answers lock recovery for 15 minutes.
- **Profile:** change password, change security question.
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
- **Map:** every ward / taluk / district in its own colour (neighbours never share one), a pulsing "you are here" dot, report pins per hotspot, ward names when zoomed in, and a toggle back to problem-density colouring.
- **Directions:** "Directions in Google Maps" on report details, ticket rows, area report lists and hotspot cards. Google Maps starts from the viewer's current location.
- **Ranked Works:** rank badges with score bars for demand, demographics and infrastructure gap.
- **Compare Proposals:** pick two works and compare them side by side, with a recommendation that cites the numbers.
- **Problem Reports:** ticket management for problem-type tickets only.

## Identity and privacy rules
- Citizens never give an email, phone number or ID. The username maps to an undeliverable synthetic address (`<username>@citizen.prajadhwani.app`) inside Firebase Auth.
- Security-question answers are stored only as salted scrypt hashes in `userSecrets/{uid}`, which no client can read.
- A citizen can't grant themselves the official role: `firestore.rules` pins `users/{uid}.role`.
- Aadhaar-number-shaped text is still regex-scrubbed from public report summaries.
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
- ✅ Cloud Functions: AI pipeline (`onSubmissionCreated`, `transcribeAndTranslate`), agents, public projections, MP credentials, and citizen password recovery (`setSecurityQuestion`, `getSecurityQuestion`, `resetPasswordWithSecurityQuestion`). Aadhaar OCR was removed.
- ✅ Blaze billing is attached, and Gemini runs through Vertex AI with no API key.
- ⏳ Booth and constituency data is a Bengaluru demo set. Swap in the real dataset when ready.

## Getting started
1. Install the Flutter SDK (stable channel).
2. Run `flutter create . --platforms=android --project-name praja_dhvani`.
3. Run `python tool/prepare_android.py` (app id, Firebase config, permissions, app label).
4. In the Firebase console, enable **Email/Password** sign-in (used by both citizen usernames and MP logins). Phone and Anonymous are no longer used.
5. Run `flutter pub get`, then `flutter run`.
6. Optional: seed demo data with `cd functions && npm install && npm run seed:mock`.
7. Seed wards: `cd functions && npx ts-node src/scripts/seedWards.ts` (369 GBA) and `npx ts-node src/scripts/seedBbmpWards.ts` (198 BBMP).

## Good to know
- **Signing:** a stable debug keystore is committed at `ci-keystore/prajadhvani-debug.keystore`, so every build has the same SHA fingerprint.
- **Play Store release:** it needs its own upload key, with that SHA registered in Firebase.
- **Nominatim:** the public instance is limited to about 1 request per second, so self-host it at scale.

## Key docs
- `PrajaDhvani_ClaudeCode_BuildPrompt.md` has the full spec, design system and data model.
- `PrajaDhvani_Phase2_OnboardingSignup.md` has the onboarding and signup spec.
