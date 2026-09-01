# Agent Cypher — Developer Mode & Developer Console

Status labels used below follow `CLAUDE.md`: implemented, analyzer-validated,
unit-tested, build-validated, emulator-tested, real-device-tested, blocked,
unverified.

## Developer mode activation (seven-tap)

**Status: implemented (static review only — analyzer/build unavailable in this
environment, see Tooling note)**

- Path: Settings → About Cypher → Build number → seven rapid taps.
- Timing rules live in `DeveloperTapActivator`
  (`lib/services/developer_config_service.dart`), a pure-Dart, unit-tested
  class:
  - taps closer than 80 ms are debounced (rejected);
  - a gap longer than 1800 ms resets the sequence;
  - feedback ("N steps away…") starts at the 3rd tap;
  - the 7th valid tap enables the mode.
- Feedback is visual (floating snack bar) and semantic
  (`SemanticsService.announce`); a haptic tick accompanies every tap.
- Persistence: the flag is stored under the same
  `developer_mode_enabled` preference key used by the legacy settings
  screen's explicit toggle, so both activation paths stay in sync.
- Disabling: toggle Developer Mode off in Settings → DEVELOPER, or use
  Reset Developer Configuration. Disabling also clears tap-sequence state.
- This is Cypher's own in-app developer mode. Android system Developer
  Options are never modified.
- Activation UI exists in two places, both driven by the same logic:
  - `lib/screens/settings/about_page.dart` (primary Android-style path)
  - `lib/screens/settings_screen.dart` ABOUT card build-number row

## Developer Console

**Status: implemented (static review only)** — entry points:
About page (when enabled), Settings hub (when enabled), and the legacy
Settings screen's Developer Mode card button.

`lib/screens/developer/developer_console_home.dart`

- **System**: app version/build (PackageInfo), Android version
  (`Platform.operatingSystemVersion`), Dart VM version, logical screen size
  and DPR, active theme summary (preset, mode, gradient, custom accent).
- **Runtime**: app lifecycle (WidgetsBindingObserver), voice STT readiness,
  wake word (honest UNAVAILABLE — no detector exists in this build), overlay
  permission, accessibility service, notification permission, network
  (connectivity_plus), provider configuration.
- **Health**: evidence-based `OK / WARNING / ERROR / UNAVAILABLE / NOT
  TESTED` only (`DevHealth` in `dev_console_utils.dart`). Probes run on page
  open and manual refresh; nothing polls in the background.
- **Quick actions**: Theme Studio, Orb Lab, Model Lab, Agent Diagnostics,
  Permission Matrix, Performance, Logs, Errors, Code Agent, Feature Flags,
  Reset Developer Configuration. Every action navigates to an implemented
  page — no dead navigation.

## Orb Lab

**Status: implemented (static review only)** —
`lib/screens/developer/orb_lab_page.dart`

Controls the REAL procedural orb (`lib/core/ui/cypher_voice_orb.dart`); the
lab does not duplicate the renderer. Architecture:

- `CypherOrbConfig` (`lib/core/ui/orb_config.dart`): per-state energy
  overrides (idle/listening/processing/executing/speaking) and multipliers —
  deformation, deformation speed, fluid speed, jelly softness, elasticity,
  damping, audio influence, tap response, touch influence, wave strength,
  glow, highlight, internal color mix, motion scale.
- `CypherOrbController`: programmatic control surface. The orb state
  registers itself as delegate; the lab can trigger tap pulses, swipes,
  press depth, simulated touch sequences, and reset physics. Calls are safe
  no-ops when no orb is attached.
- State buttons for all ten states: IDLE, OPENING, LISTENING, PROCESSING,
  EXECUTING, SPEAKING, CLOSING, CANCELLED, ERROR, UNAVAILABLE.
- Actions: play/pause (ticker stop/start), reset, simulate audio level
  (bounded timer), simulate touch, trigger tap, trigger swipe, trigger error.
- Profiles (Phase 6): named, persistable configurations stored developer-only
  under `dev_orb_profiles` (save, restore, duplicate, delete). The working
  lab state persists under `dev_orb_lab_config`. User-facing theme settings
  (`cypher_*` keys owned by `ThemeController`) are never touched.

## Theme Studio

**Status: implemented (static review only)** —
`lib/screens/developer/theme_studio_page.dart`

- Mode (system/dark/light), all six presets (Crimson Night, Obsidian,
  Burgundy, Midnight, Ember, Platinum), custom accent (curated swatches +
  HSV blender), gradient style (ambient/radial/linear/dual glow/subtle
  mesh), intensity (the gradient opacity multiplier) and softness (blur
  radius).
- Everything routes through the existing `ThemeController` token system —
  no raw overrides, no token bypass. A read-only token inspector shows what
  the active tokens resolve to.
- Position/flow are derived from the selected gradient style by the token
  system itself; the page states this instead of exposing fake sliders.

## Code Agent workflow

**Status: implemented (static review only)** —
`lib/screens/developer/code_agent_page.dart`

Honest scope: the app cannot modify its own source or rebuild itself. The
page structures the workflow — request → analysis (files, reason, risk) →
proposed changes (summary + diff/patch) → explicit approval gate →
application **through the authorized development environment** (explicit
developer attestation switch, disabled until approval) → validation
(analyzer/tests/build, each not-tested/pass/fail) → result (unverified /
success / partial / failed) → checkpoint & revert notes.

Sessions persist developer-only (`dev_code_agent_sessions`, max 20) and can
be reloaded. A sanitized report can be copied to the clipboard. The app
never writes source files and never reports success without the developer's
recorded evidence.

## Supporting pages

| Page | Source of truth |
|------|-----------------|
| Agent Diagnostics | `TaskTelemetryService.shared.developerState` + capability registry + sanitized clipboard export |
| Logs | Snapshot execution events + workspace command records |
| Errors | Sanitized snapshot errors |
| Performance | Recorded stage latencies, guard counters, opt-in expensive diagnostics toggle (`dev_expensive_diagnostics`) |
| Permission Matrix | `PermissionService.getAllPermissionsStatus()` + explanations |
| Feature Flags | `FeatureFlags` compile-time constants (read-only, honest) |
| Checkpoints | `ControlledUpgradeService` published state — explicitly UNAVAILABLE in this build |
| Model Lab | `ProviderManager` + `AiService`, opt-in connectivity probe with latency |
| Reset | `CypherDeveloperConfig.resetDeveloperConfiguration()` — clears only developer state |

## Persistence boundaries

- Developer keys: `dev_orb_profiles`, `dev_orb_lab_config`,
  `dev_code_agent_sessions`, `dev_expensive_diagnostics`, plus the shared
  `developer_mode_enabled` flag.
- Reset clears only the keys above. User data (chats, provider credentials
  in secure storage, memory, skills, permissions, theme) is never touched.
- Corrupt developer JSON is swallowed safely (feature degrades to defaults).

## Tests

- `test/developer_tap_activator_test.dart` — activation, timeout reset,
  debounce, feedback thresholds, sparse-tap safety. **unit-tested (written;
  execution blocked — no toolchain)**
- `test/developer_config_service_test.dart` — persistence, orb profiles,
  lab config, bounded code sessions, reset isolation. **unit-tested
  (written; execution blocked)**
- `test/orb_config_test.dart` — defaults, copyWith/clear, JSON round-trip,
  clamping, profile round-trip, controller no-op safety. **unit-tested
  (written; execution blocked)**
- `test/settings_navigation_test.dart` — hub shows real categories, hides
  Developer until enabled, navigates to the real console/appearance pages.
  **widget-tested (written; execution blocked)**

## Tooling note

The environment used for this work has **no Flutter SDK, no Dart SDK, no
ADB, and only Java 1.8**. `flutter analyze`, `flutter test`,
`flutter build apk --debug`, and device QA could not be executed. Everything
above was verified by static review (structure, imports, token usage,
brace/paren balance, cross-references against existing API signatures).
Labels claim only what that evidence supports.
