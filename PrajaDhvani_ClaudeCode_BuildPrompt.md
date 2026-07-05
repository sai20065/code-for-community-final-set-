# PROJECT BRIEF FOR CLAUDE CODE (Google Antigravity)
## App: "Praja Dhvani" (ಪ್ರಜಾ ಧ್ವನಿ / प्रजा ध्वनि — "Voice of the People") — AI-Powered Civic Grievance & Constituency Insights App

You are building a **Flutter Android app** from scratch. Read this entire document before
writing any code. It contains the product spec, data model, and a full UI/UX design
system grounded in human psychology. Follow it precisely, then propose a build plan and
start with Phase 1.

---

## 1. What this app is (one paragraph)

A civic-tech Android app where citizens report local problems (potholes, water issues,
electricity outages, sanitation, etc.) via **voice, text, or photo**, tagged with their location.
Submissions are auto-translated, AI-classified into themes, clustered with similar reports,
and routed to the correct MP's constituency dashboard. Citizens get a ticket number
instantly and can track status. MPs/officials see a color-coded map of their constituency
showing problem density, so nothing gets ignored. Think: **"Uber for civic complaints" —
report in 20 seconds, track like a delivery order.**

Two user roles, one codebase, different navigation shells:
- **Citizen** (default, mobile-first, low-literacy-friendly)
- **MP/Official** (dashboard-style, data-dense but still simple)

---

## 2. Non-negotiable legal/data rule (carry this into all screens)

**No Aadhaar scanning, no ID document storage.** Identity = phone number OTP only.
Location = manual pincode entry + optional map pin drop. Do not design any screen that
implies ID-card upload or OCR of identity documents.

---

## 3. UI/UX Design Philosophy — build the app around these psychology principles

This is the most important section. Every screen you generate must be checked against
this list. The goal: **a non-technical, possibly low-literacy citizen in rural or semi-urban
India should be able to file a complaint in under 30 seconds without reading much text.**

### 3.1 Color psychology — the palette and why
Use this exact palette across the app (define as a Flutter `ThemeData` / `ColorScheme`):

| Role | Color | Hex | Psychological reasoning |
|---|---|---|---|
| Primary brand | Trust Blue | `#1957D6` | Blue signals institutional trust, calm, government-adjacent credibility without feeling cold — used for AppBar, primary buttons, links |
| Secondary / Action | Marigold Orange | `#FF9933` | Warm, energetic, culturally resonant (Indian flag saffron association without being political) — used for the main "report" FAB and CTAs, drives action |
| Success / Resolved | Leaf Green | `#2E9E5B` | Universally read as "done, safe, good" — status chips, resolved tickets |
| Warning / In Progress | Amber | `#F5A623` | Signals "being handled," avoids alarm associated with red |
| Urgent / New unresolved | Coral Red | `#E4572E` | Used sparingly (only badge counts, urgent tags) — red overuse creates anxiety, so cap its use to small accents only |
| Neutral background | Warm Off-White | `#FAF8F5` | Paper-like warmth reduces the "cold tech" feeling; better for outdoor sunlight readability than pure white |
| Text primary | Charcoal | `#2B2B2B` | Higher readability than pure black on off-white, less harsh |
| Theme accent (per category) | Distinct hue per theme (roads=grey-brown, water=teal, electricity=yellow, health=pink-red, sanitation=green, education=indigo) | — | Color-coding categories lets low-literacy users recognize a theme by color/icon alone, without reading the label |

**Rule:** Never use more than 2 saturated colors in the same view besides the category
accent. Whitespace is part of the design — do not fill every pixel.

### 3.2 Cognitive load reduction (Hick's Law + Miller's Law)
- Home screen citizen view has **exactly one dominant action**: a large circular mic
  button, center-bottom, thumb-reachable. Everything else is secondary and visually
  smaller.
- Never show more than 4 choices on a decision screen (e.g. theme picker = icons in a
  2x2 or single-row grid, not a dropdown list of 8).
- Forms are **one question per screen** during onboarding (progressive disclosure),
  not one long scrollable form — reduces perceived effort and abandonment.

### 3.3 Icon-first, text-second (accessibility for low literacy)
- Every action has a large, universally recognizable icon (mic, camera, pencil, pin)
  BEFORE any label. Label text is secondary/smaller, and always in the user's chosen
  Indian language.
- Use filled, rounded icon style (not thin outline) — rounder shapes read as friendlier
  and are easier to parse at small sizes (this is why apps like WhatsApp/PhonePe use
  filled glyphs for primary actions).

### 3.4 Trust & institutional legitimacy signals (important for civic apps)
- Government-adjacent trust cues without impersonating government: an official-
  looking header band, a subtle tricolor-inspired accent line under the AppBar (not the
  flag itself, just a 3px gradient strip in blue/white/green), and a visible "ticket number"
  card immediately after submission (mirrors the trust citizens already have in
  RTI/complaint ticket systems, post office receipts, etc.)
- Every submission instantly shows a **receipt-style confirmation** (ticket ID, date,
  "we've got this") — this exploits the same psychological relief people get from a
  courier tracking number. Never let a user submit into a void.

### 3.5 Feedback loops & the "seen, not ignored" effect
- Status chips (New → Reviewed → In Progress → Resolved) with a horizontal stepper
  UI, animated when status changes — visible progress reduces the feeling that a
  complaint disappeared into a bureaucracy (a major trust-killer for civic apps).
- Micro-animations on submit (checkmark bounce, subtle confetti burst on "Resolved")
  — small dopamine hits that encourage continued civic participation without feeling
  like a game/gimmick.

### 3.6 Reduce anxiety around voice/photo recording
- Big, obvious record button with a pulsing ring animation while recording (signals
  "it's working" — silence/uncertainty causes people to abandon the action).
- Always show a live waveform or timer during voice recording — confirms the mic is
  actually capturing audio (a common trust gap in voice-first apps for first-time users).
- Playback-before-submit step, always, with a re-record option — gives users control
  and reduces submission anxiety.

### 3.7 Language & localization UX
- First-launch = single screen, large flag/language name buttons (Hindi, Tamil, Telugu,
  Kannada, Bengali, Marathi, English, +more), no back button needed, no explanatory
  paragraph — the choice itself is the onboarding.
- Once chosen, static UI strings load from that locale (Flutter `intl`), never mixed with
  English mid-flow.

### 3.8 MP/Official dashboard psychology (different user, different needs)
- Officials are time-poor: lead with a **single glanceable number** at the top (e.g. "42
  new this week") before any chart — satisfies the "can a busy person understand
  value in 5 minutes" test.
- Map first, table second — spatial pattern recognition (a red cluster on a map) is
  processed faster than scanning a list, and prompts quicker action.
- Use progressive disclosure: tapping a booth reveals detail, rather than showing every
  submission at once — avoids overwhelming a non-technical official user.

---

## 4. Screen-by-screen spec (citizen flow)

Build these as separate Flutter screens/widgets. Use `go_router` for navigation.

1. **Splash** — logo, tricolor-accent line, auto-navigates after 1.5s.
2. **Language Select** — grid of language buttons, no header text needed beyond a
   universal 🌐 icon.
3. **Phone OTP Signup** — phone number field (large, numeric keypad), "Send OTP"
   button in Marigold Orange, 6-box OTP input with auto-focus advance.
4. **Basic Info** — name, age (single question per screen, big Next button bottom-
   right, thumb zone).
5. **Location Setup** — pincode input (auto-validates + shows resolved area name),
   then "Confirm on map" full-screen Google Map with a draggable pin, big "Confirm
   Location" button.
6. **Home (Citizen)** — warm off-white background, greeting with name, big central
   mic FAB (Marigold Orange, pulsing subtle glow), secondary row of 2 smaller buttons
   (📷 photo, ✏️ text) below it, and a scrollable "My Reports" card list underneath
   showing ticket status chips.
7. **Record/Compose screen** — depends on mode:
   - Voice: big mic button, waveform animation, timer, playback + re-record + submit.
   - Text: large text field, language-aware keyboard, optional photo attach.
   - Photo/Video: camera/gallery picker, optional caption field.
   - All three end in the same **Theme Picker** (2x2 icon grid: Roads 🛣️, Water 💧,
     Electricity ⚡, More …) — optional, AI will also auto-classify.
8. **Submission Confirmation** — receipt-card UI: large checkmark animation, ticket
   ID in monospace font (e.g. `PD-2026-004821`), "Track this report" button.
9. **My Reports (ticket list)** — card per submission: theme icon + color, short
   snippet, status stepper (New/Reviewed/In Progress/Resolved), tap for detail.
10. **Report Detail** — original submission (audio player / text / photo), transcript +
    translation shown collapsed under "See details," status stepper large at top.
11. **Profile/Settings** — language switch, edit address, logout.

## 5. Screen-by-screen spec (MP/Official dashboard — separate nav shell)

1. **Official Login** — same phone OTP, role-detected from Firestore `role` field.
2. **Dashboard Home** — top: big glanceable stat cards (New this week / Resolved
   rate / Avg response time). Below: Google Map of constituency with booth markers
   color-coded green/amber/red by open-issue density.
3. **Booth Detail (bottom sheet on tap)** — cluster summaries (AI-written one-liners)
   listed first, raw submissions expandable underneath, sorted by priority score.
4. **Themes Overview** — simple bar chart (submissions by theme) + line chart (trend
   over time) — use `fl_chart` or `syncfusion_flutter_charts`, keep max 2 chart types
   visible at once.
5. **Ticket Management** — searchable/filterable list, status update dropdown per
   ticket, bulk status update option.

---

## 6. Flutter technical architecture

```
lib/
  main.dart
  app/
    theme.dart            // ColorScheme, TextTheme per Section 3.1
    router.dart           // go_router config, citizen vs official shells
    localization/          // intl arb files per language
  core/
    services/
      auth_service.dart          // Firebase Auth phone OTP
      firestore_service.dart
      storage_service.dart       // Cloud Storage uploads
      location_service.dart      // pincode lookup + geocoding
      pincode_lookup.dart        // static/csv-backed lookup, Section 6 of PDF
    models/
      user_model.dart
      submission_model.dart
      constituency_model.dart
      booth_model.dart
      cluster_model.dart
  features/
    onboarding/
      splash_screen.dart
      language_select_screen.dart
      signup/
        phone_entry_screen.dart
        otp_verify_screen.dart
        basic_info_screen.dart
        location_setup_screen.dart
    citizen/
      home/home_screen.dart
      compose/
        voice_record_screen.dart
        text_compose_screen.dart
        photo_video_screen.dart
        theme_picker_widget.dart
      confirmation/submission_confirmation_screen.dart
      reports/
        my_reports_screen.dart
        report_detail_screen.dart
      profile/profile_screen.dart
    official/
      dashboard/dashboard_home_screen.dart
      map/constituency_map_screen.dart
      booth/booth_detail_sheet.dart
      themes/themes_overview_screen.dart
      tickets/ticket_management_screen.dart
  shared/
    widgets/
      primary_button.dart
      status_stepper.dart
      ticket_receipt_card.dart
      language_grid_button.dart
      recording_waveform.dart
      theme_icon_chip.dart
```

### Key packages to use
- `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`
- `google_maps_flutter`, `geocoding`
- `go_router`
- `intl` + `flutter_localizations`
- `record` or `flutter_sound` (voice recording)
- `image_picker`
- `fl_chart` (official dashboard charts)
- `lottie` (checkmark/confetti micro-animations — keep files small)
- `flutter_riverpod` or `provider` for state management (pick one, stay consistent)

### Firestore data model
Use exactly the collections and fields from the source build plan:
- `users/{uid}` — name, age, phone, pincodeHome, addressHome, role, constituencyId, createdAt
- `submissions/{submissionId}` — userId, type, inputMode, rawText, mediaUrl, transcript,
  translatedText, language, theme, clusterId, priorityScore, location {lat, lng, pincode,
  boothId, constituencyId}, status, tokenId, createdAt
- `constituencies/{constituencyId}` — name, state, mpUserId, boundaryGeoJson
- `booths/{boothId}` — constituencyId, name, lat, lng, pincodesCovered[]
- `clusters/{clusterId}` — constituencyId, theme, centroidVector, submissionCount,
  sampleSubmissionIds[], summaryText

**Critical rule to preserve in code:** the `tokenId` (e.g. `PD-2026-004821`) must be
generated and written to Firestore **at document creation time**, before any AI/Cloud
Function processing runs. The citizen must never lose their ticket even if the AI pipeline
fails downstream.

---

## 7. Build order — start here, stop wherever time runs out

Each phase should be independently demoable. Confirm each phase works before moving
to the next.

1. **Phase 1:** Project scaffold, Firebase project wiring, theme.dart with the full color
   system from Section 3.1, go_router skeleton with placeholder screens for every
   route listed in Section 6.
2. **Phase 2:** Language select + phone OTP signup + basic info + pincode/location
   setup, fully working against Firebase Auth + Firestore.
3. **Phase 3:** Citizen home screen + text submission end-to-end (typed → Firestore →
   visible in My Reports list). This alone proves the core loop — prioritize getting this
   pixel-polished per Section 3.
4. **Phase 4:** Voice recording UI (waveform, playback) + photo/video picker, uploading
   to Cloud Storage, submission confirmation receipt screen with ticket ID.
5. **Phase 5:** My Reports list + Report Detail screen with status stepper widget.
6. **Phase 6:** Official dashboard shell — stat cards, Google Map with booth markers
   (use dummy/sample constituency data if live Cloud Function pipeline isn't ready yet).
7. **Phase 7:** Booth detail bottom sheet, themes overview charts, ticket management
   list.
8. **Phase 8:** Polish pass — micro-animations (Lottie checkmark, pulsing mic ring),
   empty states, error states, accessibility check (font scaling, color contrast).

---

## 8. What to do right now

1. Propose the Flutter project structure matching Section 6.
2. Scaffold `theme.dart` with the full `ColorScheme` from Section 3.1.
3. Scaffold `router.dart` with every screen as a named route (placeholder
   `Scaffold(body: Text('TODO: screen name'))` is fine initially).
4. Then begin Phase 2 from Section 7.

Ask me only if something is genuinely ambiguous (e.g. state management choice) —
otherwise default to Riverpod and proceed.
