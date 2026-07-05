# PHASE 2 BUILD PROMPT — Claude Code / Antigravity
## App: Praja Dhvani — Onboarding, Language Select, Phone OTP Signup, Location Setup

This is a **continuation prompt**. Phase 1 (project scaffold, Firebase wiring, theme.dart
with the full color system, go_router skeleton with placeholder screens) should already be
done. If Phase 1 is not done in this project yet, do that first before continuing — check
`lib/app/theme.dart` and `lib/app/router.dart` exist and are wired, then proceed below.

**Do not re-theme or re-architect anything from Phase 1.** Reuse the existing
`ColorScheme`, `TextTheme`, folder structure, and state management approach (Riverpod)
already established. This phase only builds real, working screens inside
`lib/features/onboarding/`.

---

## 1. Scope of this phase

Build these five screens, fully functional, wired to Firebase Auth + Firestore, in this order:

1. Splash screen
2. Language select screen
3. Phone entry + OTP verify (Firebase Auth phone OTP)
4. Basic info screen (name, age)
5. Location setup screen (pincode entry + map pin confirm)

At the end of this phase: a new user should be able to open the app, pick a language,
verify their phone via OTP, enter their name/age, set their pincode + confirm location on a
map, and land on a placeholder Home screen — with a `users/{uid}` document correctly
written to Firestore.

**No Aadhaar or ID document upload anywhere in this flow** — identity is phone OTP only.

---

## 2. Design psychology to apply in this phase (recap — follow exactly)

- **One question per screen.** Never combine phone entry + OTP on one screen, never
  combine name + age + pincode on one screen. Each screen = one decision, one big
  "Next" button bottom-right in the thumb zone.
- **No dead air during async waits.** OTP send, OTP verify, and pincode lookup must all
  show inline loading states on the button itself (e.g. button text swaps to a small
  spinner, button stays same size/position — no layout jump).
- **Language select has no instructional text**, just a clean grid of language name
  buttons in their own script (हिन्दी, தமிழ், తెలుగు, ಕನ್ನಡ, বাংলা, मराठी, English, +More)
  with a 🌐 icon at the top. The act of tapping IS the onboarding — don't make the user
  read a paragraph first.
- **Trust signals:** thin 3px gradient accent line (blue→white→green) under every
  AppBar in this flow, consistent with the rest of the app.
- **Progress indication:** show a slim progress dots/stepper at the top of the signup
  screens (Phone → OTP → Basic Info → Location) so users know how many steps
  remain — reduces abandonment on multi-step forms.
- **Forgiving inputs:** phone field auto-formats as the user types, OTP boxes auto-
  advance focus per digit and auto-submit on the 6th digit, pincode field shows a
  green checkmark + resolved area name the moment a valid pincode is recognized (no
  need to press a separate "lookup" button).

---

## 3. Screen 1 — Splash Screen

`lib/features/onboarding/splash_screen.dart`

- Centered app logo/wordmark "Praja Dhvani" on Warm Off-White (`#FAF8F5`)
  background.
- Thin tricolor-inspired accent line animates in under the wordmark (draw-in animation,
  ~600ms).
- Auto-navigates after 1.5s to:
  - Language Select screen, if no language has been chosen yet (check local
    shared_preferences / Riverpod state)
  - Home screen, if a valid Firebase Auth session already exists
  - Phone Entry screen, if language is chosen but user is not authenticated

Use `shared_preferences` package to persist the chosen language locally in addition to
Firestore, so the splash routing logic works before any network call resolves.

---

## 4. Screen 2 — Language Select

`lib/features/onboarding/language_select_screen.dart`

- App bar: none (full-bleed screen), just the 🌐 icon centered near the top.
- Body: a responsive grid (2 columns on phone) of language buttons. Each button:
  - Rounded rectangle, Warm Off-White fill, Trust Blue border
  - Language name displayed in **its own native script**, large font (24sp+)
  - Tapping instantly highlights the selection (Marigold Orange border/fill flash) then
    auto-navigates after ~300ms — no separate "Confirm" button needed for this screen
    specifically (reduces one extra tap; this is the one screen where instant-navigate
    beats an explicit confirm step, since selection is low-stakes and changeable later
    in Profile settings)
- Languages to include: Hindi, Tamil, Telugu, Kannada, Bengali, Marathi, Malayalam,
  Gujarati, Punjabi, English (10 total — scrollable grid if needed)
- Store selection in both `shared_preferences` (key: `app_locale`) and, once the user is
  authenticated later, on their `users/{uid}.preferredLanguage` field.
- Wire this into `intl`/`flutter_localizations` so the rest of the onboarding flow (Phone
  Entry onward) immediately renders in the selected language.

---

## 5. Screen 3 — Phone Entry + OTP Verify

Two screens, one flow: `lib/features/onboarding/signup/phone_entry_screen.dart` and
`lib/features/onboarding/signup/otp_verify_screen.dart`

### Phone Entry
- Progress stepper at top: step 1 of 4, Trust Blue filled dot for current step.
- Large icon (📱) above the field.
- Single text field: country code fixed to `+91` (prefixed, non-editable, greyed), 10-digit
  numeric input, auto-formatted in groups of 5 (`98765 43210`) for readability.
- Button: "Send OTP" — Marigold Orange, full-width, bottom of screen (thumb zone).
  Disabled/greyed until exactly 10 digits entered.
- On tap: call Firebase Auth `verifyPhoneNumber`, show inline spinner in the button,
  navigate to OTP Verify screen on `codeSent` callback.
- Handle and surface errors inline (invalid number, quota exceeded, network error) with
  a small red-text banner below the field — never a disruptive dialog/popup for this.

### OTP Verify
- Progress stepper: still step 1 of 4 (OTP is part of phone verification, not a separate
  step in the user-facing count).
- Text: "Enter the code sent to +91 98765 43210" with an "Edit number" text-link to go
  back.
- 6 individual boxed digit inputs, auto-advance focus, auto-submit `PhoneAuthCredential`
  the instant the 6th digit is entered (no separate "Verify" button needed — auto-
  submit reduces friction here since a 6-digit code is a complete, unambiguous action).
- Resend OTP link, disabled with a 30-second countdown timer visible as small text
  (`Resend in 0:24`).
- On successful verification: sign in via Firebase Auth, create the `users/{uid}`
  document if it doesn't already exist (fields: `phone`, `createdAt`, `role: "citizen"`,
  `preferredLanguage`), then navigate to Basic Info screen.
- On failure (wrong code): shake animation on the boxes + red border flash + inline
  error text, clear the boxes, refocus first box. No blocking dialog.

---

## 6. Screen 4 — Basic Info

`lib/features/onboarding/signup/basic_info_screen.dart`

- Progress stepper: step 2 of 4.
- Icon (👤) above fields.
- Name field: text input, first name is enough, no validation beyond non-empty.
- Age field: numeric input OR a simple large +/- stepper control (numeric input is
  usually faster to build and equally accessible; use a plain numeric `TextFormField`
  with `keyboardType: TextInputType.number`).
- "Next" button, Marigold Orange, bottom, disabled until both fields have valid values.
- On submit: update `users/{uid}` with `name` and `age`, navigate to Location Setup.

---

## 7. Screen 5 — Location Setup

`lib/features/onboarding/signup/location_setup_screen.dart`

This is two sub-steps on one logical screen (can be a `PageView` of 2 pages within this
one route, sharing the same step-3-of-4 stepper position):

### Sub-step A — Pincode entry
- Icon (📍) above field.
- 6-digit numeric pincode field.
- The instant 6 valid digits are entered, call the pincode lookup service
  (`core/services/location_service.dart` — `pincode_lookup.dart`, per the master
  Firestore/architecture doc) and show a green checkmark + resolved
  "District, State" text beneath the field automatically — no manual "Lookup" button
  press required.
- Editable address free-text field below, pre-filled with nothing (user types their own
  address; do not attempt to auto-fill full address from pincode alone, only
  district/state).
- "Next" button advances to Sub-step B once pincode is validated.

### Sub-step B — Confirm on map
- Full-screen `google_maps_flutter` map, centered on the geocoded pincode area by
  default.
- A single draggable pin (Marigold Orange marker) the user can drag to their exact
  location.
- Small helper text overlay at top: "Drag the pin to your exact location" (in selected
  language) — dismissible/fades after first interaction.
- "Confirm Location" button, full-width, bottom, Marigold Orange.
- On confirm: write `pincodeHome`, `addressHome`, and `location: {lat, lng}` onto
  `users/{uid}`. Trigger (or stub, if Cloud Functions aren't built yet in this phase) the
  constituency/booth resolution step described in the master architecture doc —
  it's acceptable to leave this as a `// TODO: call resolveConstituency Cloud Function`
  comment if Cloud Functions haven't been scaffolded yet; don't block navigation on it.
- Navigate to the (placeholder, from Phase 1) Home screen on success.

---

## 8. State management notes

- Use Riverpod providers for:
  - `authStateProvider` — wraps `FirebaseAuth.instance.authStateChanges()`
  - `onboardingProgressProvider` — tracks which step the user is on, so app restarts
    mid-signup resume at the correct screen rather than restarting from Splash
  - `selectedLanguageProvider` — backed by `shared_preferences`
- Keep all Firebase calls inside `core/services/`, never directly inside widget files —
  screens should call service methods, not `FirebaseAuth`/`FirebaseFirestore` directly.

---

## 9. Definition of done for Phase 2

- [ ] Fresh install → Splash → Language Select → Phone Entry → OTP Verify → Basic
      Info → Location Setup → Home, with no dead ends or crashes.
- [ ] Killing and reopening the app mid-flow resumes at the correct step (not back to
      Splash/Language Select every time).
- [ ] A real `users/{uid}` Firestore document exists after completing the flow, with all
      fields listed above populated.
- [ ] All screens render correctly in at least 2 of the 10 supported languages (test with
      Hindi and English minimum) to confirm `intl` wiring works end-to-end.
- [ ] No Aadhaar/ID upload UI exists anywhere in this phase.

---

## 10. What to do right now

1. Confirm Phase 1 scaffold exists; if not, build it first per the master build plan.
2. Build screens in the order listed in Section 1.
3. After each screen, briefly summarize what was built and any assumptions made,
   then continue to the next screen without waiting for confirmation unless something
   is genuinely ambiguous.
4. At the end, run through the Definition of Done checklist in Section 9 and report
   status on each item.
