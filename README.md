# People's Priorities

AI-powered civic grievance & constituency insights app. Citizens report local
problems (potholes, water, electricity, sanitation, etc.) by voice, text, or
photo; MPs/officials see a color-coded map of their constituency's problem
density.

Full product spec, design system, and data model:
[`PeoplesPriorities_ClaudeCode_BuildPrompt.md`](PeoplesPriorities_ClaudeCode_BuildPrompt.md).

## Status: Phase 1 scaffold + start of Phase 2/3

- `lib/app/theme.dart` — full `ColorScheme` and category/status color mapping
  from the design system's Section 3.1.
- `lib/app/router.dart` — `go_router` config with every screen from both nav
  shells (citizen + official) wired as a named route.
- `lib/core/` — data models and service classes (`AuthService`,
  `FirestoreService`, `StorageService`, `LocationService`) matching the
  Firestore schema in Section 6 of the build prompt.
- `lib/shared/widgets/` — reusable primitives (status stepper, ticket receipt
  card, language grid button, recording waveform, theme icon chip).
- `lib/features/onboarding/` — splash, language select, and the full phone
  OTP → basic info → location signup flow, wired to Firebase Auth/Firestore.
- `lib/features/citizen/` — home screen with mic FAB, text/voice/photo
  compose screens, submission confirmation receipt, my reports list + detail.
- `lib/features/official/` — dashboard stat cards, constituency
  booth list (map-marker interaction pattern), booth detail sheet, themes
  charts, ticket management.

## Getting started

This repo was scaffolded without a local Flutter SDK available, so the
platform folders (`android/`, `ios/`) and `firebase_options.dart` are not yet
generated for real. To run it:

1. Install the [Flutter SDK](https://flutter.dev) (stable channel).
2. From the repo root, run `flutter create . --platforms=android,ios` to
   generate the native platform scaffolding (this will not overwrite the
   existing `lib/` code).
3. Create a Firebase project, then run `flutterfire configure` to replace
   the placeholder `lib/firebase_options.dart` with real credentials.
4. Add a Google Maps API key for Android/iOS (needed by
   `google_maps_flutter` on the official dashboard map and citizen location
   picker).
5. `flutter pub get`, then `flutter run`.

## Non-negotiable rule

No Aadhaar scanning, no ID document storage anywhere in this app. Identity is
phone number OTP only; location is pincode entry + optional map pin drop.
