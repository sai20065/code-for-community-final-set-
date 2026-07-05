# Praja Dhvani (ಪ್ರಜಾ ಧ್ವನಿ / प्रजा ध्वनि — "Voice of the People")

AI-powered civic grievance & constituency insights app. Citizens report local
problems (potholes, water, electricity, sanitation, etc.) by voice, text, or
photo; MPs/officials see a color-coded map of their constituency's problem
density.

Full product spec, design system, and data model:
[`PrajaDhvani_ClaudeCode_BuildPrompt.md`](PrajaDhvani_ClaudeCode_BuildPrompt.md).
Phase 2 (onboarding/signup) spec:
[`PrajaDhvani_Phase2_OnboardingSignup.md`](PrajaDhvani_Phase2_OnboardingSignup.md).

## Status: Phase 1 scaffold + Phase 2 (onboarding/signup) complete + start of Phase 3

- `lib/app/theme.dart` — full `ColorScheme` and category/status color mapping
  from the design system's Section 3.1.
- `lib/app/router.dart` — `go_router` config with every screen from both nav
  shells (citizen + official) wired as a named route.
- `lib/app/providers/` — Riverpod providers: `authStateProvider` (wraps
  Firebase Auth's auth state stream), `selectedLanguageProvider` and
  `onboardingProgressProvider` (both backed by `shared_preferences` so splash
  routing resolves before any network call, and a killed/reopened app resumes
  onboarding at the correct step instead of restarting from Splash).
- `lib/core/` — data models and service classes (`AuthService`,
  `FirestoreService`, `StorageService`, `LocationService`) matching the
  Firestore schema in Section 6 of the build prompt. `users/{uid}` is created
  the moment a phone number is OTP-verified and filled in incrementally
  across Basic Info and Location Setup.
- `lib/shared/widgets/` — reusable primitives (status stepper, onboarding
  progress stepper, ticket receipt card, recording waveform, theme icon
  chip).
- `lib/features/onboarding/` — splash (routes to Language Select / resume
  point in signup / Home based on persisted state), language select (10
  languages, instant-navigate on tap), and the full phone entry → OTP verify
  (auto-submit on 6th digit, 30s resend countdown, shake-on-failure) → basic
  info → location setup (2-page pincode + map-pin-confirm) signup flow, all
  wired to Firebase Auth/Firestore per the Phase 2 spec.
- `lib/features/citizen/` — home screen with mic FAB, text/voice/photo
  compose screens, submission confirmation receipt (ticket IDs like
  `PD-2026-004821`), my reports list + detail.
- `lib/features/official/` — dashboard stat cards, constituency
  booth list (map-marker interaction pattern), booth detail sheet, themes
  charts, ticket management.

## Firebase / Google Cloud project

This app is wired to the real Firebase project **`code-for-community-e2cf2`**
("code for community"):

- ✅ **Firestore** — Native-mode database created in `asia-south1`, with
  `firestore.rules` (owner-only `users/{uid}`, owner-create + official-read/
  update `submissions/{id}`, read-only reference collections) and
  `firestore.indexes.json` already deployed live via `firebase deploy`.
- ✅ **Android + iOS apps registered** (package/bundle id
  `com.prajadhvani.app`), plus the pre-existing web app. `lib/firebase_options.dart`
  is filled in with their real API keys/app IDs — these are client
  identifiers, not secrets; access is controlled by the Firestore rules
  above, not by hiding this file.
- ⏳ **Phone Auth sign-in provider** — not yet toggled on. Firebase's Phone
  provider can't be reliably enabled via API/CLI (it needs a one-time console
  visit to provision). **To finish:** open
  [Authentication → Sign-in method](https://console.firebase.google.com/project/code-for-community-e2cf2/authentication/providers)
  and enable **Phone**. Nothing else is needed after that — `AuthService`
  already calls `verifyPhoneNumber`/`signInWithCredential` correctly.
- ⏳ **Cloud Storage + Google Maps API** — both require a **billing account**
  (Blaze plan) attached to the GCP project, which wasn't confirmed to exist.
  Submissions/voice/photo uploads and the map screens will no-op or error
  until this is done. **To finish:** attach a billing account at
  [console.cloud.google.com/billing](https://console.cloud.google.com/billing/linkedaccount?project=code-for-community-e2cf2),
  then tell Claude to enable `storage.googleapis.com` (Firebase Storage) and
  a Maps API key (`maps-android-backend.googleapis.com` /
  `maps-ios-backend.googleapis.com`) via `gcloud`.
- The native `google-services.json` / `GoogleService-Info.plist` are staged
  in [`firebase_config/`](firebase_config/) — once `flutter create` generates
  `android/` and `ios/`, move them to `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist` respectively.

## Getting started

This repo was scaffolded without a local Flutter SDK available, so the
platform folders (`android/`, `ios/`) don't exist yet. To run it:

1. Install the [Flutter SDK](https://flutter.dev) (stable channel).
2. From the repo root, run `flutter create . --platforms=android,ios` to
   generate the native platform scaffolding (this will not overwrite the
   existing `lib/` code or `firebase_options.dart`).
3. Move the staged config files from `firebase_config/` into
   `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist`.
4. Enable Phone sign-in and (optionally) attach billing per the section
   above.
5. `flutter pub get`, then `flutter run`.

## Non-negotiable rule

No Aadhaar scanning, no ID document storage anywhere in this app. Identity is
phone number OTP only; location is pincode entry + optional map pin drop.
