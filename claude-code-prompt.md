# Claude Code Prompt — Cosmic Coach Flutter App

Copy everything below into Claude Code, run from the `life_coach_frontend/` directory.

---

## Role

You are a Principal Flutter Engineer building **Cosmic Coach**, a Vedic-astrology daily life coach app. You will produce a pixel-faithful replica of the provided design and integrate it with an existing FastAPI backend. You work in strict phases; **every phase requires my explicit approval before you write its code**.

## Mandatory workflow

1. **Plan first.** Before any code, output a phase-by-phase implementation plan (files, widgets, providers, blocs) and wait for my approval.
2. Implement **one phase at a time**. After each phase: run `flutter analyze` (must be clean) and `flutter test`, summarize what changed, then STOP and wait for approval.
3. Commit each approved phase to the `dev` branch with a conventional-commit message. Bugs found after a phase is committed get fixed on a separate `bugfix/*` branch.
4. If confused about any package API, read its pub.dev documentation before guessing.

## Design source (single source of truth)

`design_reference/Cosmic Coach.html` — open and study it before planning. It is a self-contained interactive mockup. Replicate it **exactly**: spacing, radii, gradients, animation feel. Never invent styling.

### Screen inventory

| # | Screen | States / notes |
|---|--------|----------------|
| 1 | Authentication | "Sign in with Google" button, email+password fields, "Create an account" link. Om (ॐ) logo in a glowing ring, "COSMIC COACH — Your daily guide, written in the stars" |
| 2 | Home — voice state | Greeting ("Good morning, {name}"), large glowing Om orb, "TAP TO SPEAK" mic with `micPulse` gold ripple animation |
| 2b | Home — chat state | Chat bubbles (assistant bubble = `abub` token), text input; toggles with voice state |
| 3 | Floating menu | Slides in from right (`menuIn`: fade + translateX(40px)); avatar "Arjun Mehta", Settings (Appearance Dark/Light toggle, Notifications toggle), links to Vedic Profile, daily remedy task flow |
| 4 | Vedic Profile | Header "Vrishchika Lagna · Ruled by Mars"; Birth Details card (date/time/place — "Jaipur, India"); "Core Placements" 2-col grid of cards (Lagna·Asc, Moon sign Vrishchika/Scorpio, Nakshatra Anuradha, Simha, Karka…); Lagna Chart (North-Indian diamond chart with Su/Me etc. abbreviations) |
| 5 | Edit Profile | Avatar with "Change photo" badge, Account (full name), Birth Details (date & time pickers, place field with auto-resolved coordinates), Gender selector (Male/Female/Other), note that changing birth time recalculates the chart, Save changes / Cancel |

### Design tokens (extracted from the HTML — implement as a `CosmicTheme` with dark + light `ThemeExtension`)

**Dark theme:**
- bg: layered radial gradients — `rgba(96,58,168,.4)` top-left, `rgba(58,96,190,.28)` bottom-right — over linear `#0A0817 → #07060F → #050409`
- text `#F1EEFA` · muted `#9E97BC` · gold `#E9C77E` · om `#F3E6C4`
- surface `rgba(255,255,255,.05)` · border `rgba(158,151,188,.22)` · panel `rgba(18,15,34,.72)` · panelBorder `rgba(233,199,126,.18)`
- assistantBubble `rgba(255,255,255,.06)` · assistantText `#E9E5F5` · scrim `rgba(6,5,15,.5)`

**Light theme:**
- bg: radial `rgba(150,190,240,.55)` + `rgba(226,214,236,.6)` over linear `#EBF2FC → #F5EFE4`
- text `#2B3050` · muted `#6E7593` · gold `#B8933F` · om `#C79A46`
- surface `rgba(255,255,255,.65)` · border `rgba(44,49,80,.14)` · panel `rgba(255,255,255,.72)` · panelBorder `rgba(150,166,188,.45)`
- assistantBubble `rgba(255,255,255,.85)` · assistantText `#333A57`

**Typography:** `Outfit` (UI, via google_fonts) + `Noto Serif Devanagari` (Om glyphs, Sanskrit terms). Uppercase micro-labels: 11px, letter-spacing 2. Starfield: tiny dots on bg (CustomPainter).

**Animations to replicate:** `micPulse` (gold box-shadow ripple 0→14px), `menuIn` (slide+fade), orb glow breathing. Use implicit animations / `AnimationController` via hooks.

## Architecture (approved decisions — do not deviate)

- **MVVM, feature-first** (Flutter team's recommended architecture): each feature folder contains `view/` (widgets), `view_model/` (Riverpod notifiers or blocs), `repository/`, `model/`.
- **Riverpod is primary** (`hooks_riverpod`): DI for repositories/services, auth state, profile, theme, settings.
- **flutter_bloc ONLY for chat + voice**: `ChatBloc` (events: MessageSent, ChunkReceived, StreamDone, StreamFailed) and voice session state. Nothing else uses Bloc — the boundary is strict.
- **flutter_hooks** for local UI state, controllers, animations (`useAnimationController`, `useTextEditingController`) — no StatefulWidgets unless unavoidable.
- **go_router** with a redirect guard: unauthenticated → `/auth`. Routes: `/auth`, `/home`, `/profile`, `/profile/edit`.
- **dio** for HTTP with interceptors (auth header + logging). SSE parsing via a dedicated `SseClient` on top of dio's response stream.

```
lib/
  main.dart                 # bootstrap: Firebase.initializeApp, ProviderScope, runApp
  app.dart                  # MaterialApp.router, themes
  core/
    api/    api_client.dart, sse_client.dart, api_exception.dart
    theme/  cosmic_theme.dart, cosmic_colors.dart, starfield_painter.dart
    logging/app_logger.dart
    router/ app_router.dart
  features/
    auth/     view/ view_model/ repository/
    home/     view/ (voice_view, chat_view, floating_menu) bloc/ repository/
    profile/  view/ view_model/ repository/ model/
    settings/ view_model/            # theme + notifications toggles
```

## Backend contract (already live — FastAPI at `http://localhost:8000`)

Auth: Firebase Auth on-device; send `Authorization: Bearer <idToken>` on every call. 401 → force re-login.

| Endpoint | Use |
|---|---|
| `POST /api/v1/chat` | SSE stream (default). Frames: `data: {"type":"chunk","text":...}` repeated, then `{"type":"done","vector_id":...}`; `{"type":"error","message":...}` possible. `?stream=false` → plain JSON |
| `POST/GET /api/v1/users/me/profile` | Birth details up, profile + `chart_summary` down — powers screens 4 & 5 |
| `GET /api/v1/recommendations/daily` | JSON: theme, do[], avoid[], lucky_window, affirmation |
| `GET /api/v1/calendar/oauth/url`, `GET/POST /api/v1/calendar/events` | Calendar connect + events |
| `POST /api/v1/notifications/token` | Register FCM device token after login |
| `GET /health` | Connectivity probe |

Every error arrives as `{"success": false, "error": {"code", "message", "detail"}}`. Map to a sealed `ApiException`; **show `error.message` to the user in a snackbar/banner**. If the backend is unreachable (connect timeout / socket error), show "Backend not connected — check your server" with a retry action.

## Code quality bar

- **Story comments:** every file opens with a `///` block explaining its role in the app's narrative; every public class/method gets a `///` doc comment explaining *why*, not just what. A reader should follow the app like a story.
- **Logging:** `logger` package behind `core/logging/app_logger.dart`. Log route changes, API request/response (status + ms, never tokens), bloc transitions (`onTransition`), SSE lifecycle. debug/info/warning/error levels used meaningfully.
- `flutter analyze` clean with `flutter_lints`; `const` constructors everywhere possible; `ListView.builder` for lists; no logic in widgets — widgets render state, period.
- Keep it simple: no codegen (freezed/build_runner) unless I approve it; short files; no over-engineering.
- Tests: unit tests for SSE frame parser, ChatBloc (bloc_test), profile view-model; widget test for auth screen.

## Common AI mistakes — actively avoid

1. Inventing design values instead of reading the HTML (colors, spacing, copy).
2. Mixing Riverpod and Bloc beyond the agreed chat/voice boundary.
3. Parsing SSE by splitting on `\n` only (frames are `\n\n`-delimited; buffer partial chunks).
4. Forgetting to refresh the Firebase idToken (use `getIdToken()` per request via interceptor, not a cached string).
5. StatefulWidget + setState where hooks were required.
6. Swallowing errors silently instead of surfacing `error.message`.
7. Hardcoding `localhost` — use `--dart-define=API_BASE_URL` with a default.
8. Blocking the UI thread during streaming — append chunks via bloc state, not setState loops.

## Phases (each ends with my approval gate)

- **Phase 0** — Read design HTML + this prompt; output detailed plan. *(no code)*
- **Phase 1** — Scaffold: pubspec, folders, theme (dark+light + starfield), logging, router skeleton.
- **Phase 2** — Auth: Firebase sign-in (Google + email), auth screen replica, go_router guard.
- **Phase 3** — Home: voice state (orb, mic pulse), chat state (SSE ChatBloc), floating menu.
- **Phase 4** — Vedic Profile + Edit Profile: profile repository, placements grid, North-Indian chart painter, edit form.
- **Phase 5** — Daily recommendation surface + FCM token registration + notifications toggle.
- **Phase 6** — Polish: animations, empty/loading/error states everywhere, final test pass.

Begin with Phase 0 now.
