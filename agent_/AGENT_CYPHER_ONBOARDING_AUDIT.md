# Agent Cypher — Onboarding Audit (Analysis-Only Pass)

**Date:** 2026-08-26
**Scope:** Read-only repository onboarding audit. **No source, config, or dependency file was modified, created (other than this report), deleted, or reformatted.** No build was attempted beyond read-only toolchain probing. No API keys or credentials were exposed.
**Source of truth:** local files under `C:\Users\Hp\Downloads\AgentCypher_latest_complete_project\agent_`. README/status docs (`FINAL_STATUS.md`, `IMPLEMENTATION_STATUS.md`, etc.) were treated as claims, not evidence; every status below cites code.

---

## 1. Project Identity & Architecture Summary

Agent Cypher is an **Android AI-assistant app built with Flutter (Dart) + native Kotlin**, whose core capability is LLM-driven **on-device UI automation** through an AccessibilityService. It talks to OpenAI-compatible chat APIs (DeepSeek default, NVIDIA NIM catalog), observes the screen via accessibility nodes, asks the model for JSON action decisions, executes them natively, verifies outcomes against the screen, recovers from failures, and persists skills/memories/history locally.

**Layer map (actual call graph):**

```
main.dart ──> AgentSetup.initialize()  (initializes ~10 singletons)
          ├──> HomeScreen (chat UI, agent mode toggle, voice, drawer, history)
          │      ├─ AiService.sendMessageStream()   → SSE streaming chat
          │      ├─ ActionHandler.execute(action)   → per-action services + VerificationService
          │      ├─ ActionHandler.execute(execute_task) → TaskExecutor (agentic loop)
          │      ├─ VoiceService (speech_to_text + flutter_tts)
          │      └─ ChatHistoryService / NotificationService / overlay window sync
          ├──> OnboardingScreen (permissions & API-key setup)
          └──> overlayMain() [separate Flutter entrypoint] ──> OverlayApp (overlay_main.dart)
                 └─ its own AiService/TaskExecutor/ScreenAutomationService instances,
                    handoff to main isolate via ChatHistoryService overlay-file protocol

Native side:
MainActivity.kt ── MethodChannel "com.cypherghost.agentcypher/accessibility"
                 ├─ EventChannel "...accessibility_events"  ← AgentAccessibilityService.eventListener
                 ├─ EventChannel "...wake_word_events"      ← BackgroundWakeWordService.eventListener ❌ class missing
                 └─ MethodChannel "com.cypherghost.agentcypher/files" (document picker → cache copies)
AgentAccessibilityService.kt — dumpScreen/clickByText/clickAt/typeText/pressEnter/
                               scroll/swipe/back/home/notifications/diagnostics/getCurrentPackage
Api30ScreenshotHelper.kt     — takeScreenshot (API ≥30) used by MainActivity "takeScreenshot"
BackgroundEngineReceiver     — re-registers channels onto cached engine "myCachedEngine"
```

**Key components inventory (all paths verified present unless noted):**

| Component | File | State |
|---|---|---|
| Entry points | `lib/main.dart`, `lib/overlay_main.dart` | Present |
| Screens | `home_screen.dart` (1612 ln), `settings_screen.dart` (2696 ln), `onboarding_screen.dart` (1397 ln), `task_history_screen.dart` | Present |
| AgentCore | `lib/services/agent_core.dart` | Present but **orphaned** (only initialized by AgentSetup/ExecutionPipeline; not used by the real task path) |
| TaskExecutor | `lib/services/task_executor.dart` (1181 ln) | Present, central |
| ActionHandler | `lib/services/action_handler.dart` | Present, wires 12+ services |
| ScreenAutomationService | `lib/services/screen_automation_service.dart` | Present, 3 s bounded `_invoke` on *some* methods only |
| VerificationService | `lib/services/verification_service.dart` | Present |
| RecoveryEngine | `lib/services/recovery_engine.dart` | Present, used by TaskExecutor |
| PermissionService / SettingsService | present | Used by onboarding/settings |
| AgentAccessibilityService.kt / Api30ScreenshotHelper.kt | android/…/kotlin | Present (452 ln service) |
| MainActivity.kt | present | References missing `BackgroundWakeWordService` |
| ProviderManager / OpenAiCompatibleProvider / ProviderConfiguration | `lib/services/provider/` | Present |
| AiService / SecureCredentialManager | present | DeepSeek default + NVIDIA catalog filter |
| TaskTelemetryService / DiagnosticsService | present | Telemetry OK; DiagnosticsService lacks method settings expects |
| UserMemoryService / SkillMemoryService / ChatHistoryService / TaskHistoryLogger | present | Memory service is write-only orphan (see §5) |
| Notification / Shizuku / AppLauncher / Contacts / Communication / Alarm / SystemControl / FileOps / WebOps / ExecutionPipeline / Biometric / TaskScheduling services | present | Several are initialized-but-unconsumed (see §5) |
| Local plugins | `local_plugins/flutter_overlay_window` (pubspec override), `local_plugins/agent_native` | `agent_native` is an unused scaffold ("getPlatformVersion" only), referenced nowhere |
| Tests | 5 files under `test/` | Present, small, pure-Dart testable |
| AGENTS.md | — | Not found |

---

## 2. Toolchain Status (verified by probing; nothing installed or changed)

| Tool | Status | Evidence |
|---|---|---|
| Flutter SDK | **NOT FOUND** | `flutter` not on PATH; no SDK dir found at common locations (`C:\src\flutter`, `%USERPROFILE%\flutter`) |
| Dart SDK | **NOT FOUND** | not on PATH; no pub cache at default location |
| Java/JDK | FOUND but **incompatible** | Only Java 8 (1.8.0_451) at `Program Files (x86)`; no `JAVA_HOME`; Gradle config requires **JDK 17** (`sourceCompatibility = VERSION_17` in `android/app/build.gradle.kts`) |
| Android SDK / adb | **NOT FOUND** | No `ANDROID_HOME`/`ANDROID_SDK_ROOT`; no SDK under `%LOCALAPPDATA%\Android\Sdk` |
| Gradle | NOT installed; wrapper present | `android/gradle/wrapper/gradle-wrapper.properties` → gradle-8.14-all (needs network download); AGP 8.11.1, Kotlin 2.2.20 declared in `settings.gradle.kts` |
| Pub/.gradle caches | **NOT FOUND** | First build will download all dependencies (~20 packages incl. heavy plugin builds) |
| Git | **NOT FOUND** | Not a git repo; no VCS metadata (none added, per constraints) |

**Validation blocker (exact):** `flutter pub get`, `flutter analyze`, and `flutter test` cannot run because no Flutter/Dart SDK exists on this machine. The Android Gradle build additionally requires JDK 17 (installed: none; Java 8 present is too old for AGP 8.x) and an Android SDK. Nothing was auto-installed per audit constraints.

---

## 3. File/Module Map

See §1 table for lib layout. Root also contains aspirational docs (`ACTIONS.md`, `ARCHITECTURE.md`, `FINAL_STATUS.md`, `IMPLEMENTATION_GUIDE.md`, `INTEGRATION_GUIDE.md`, `MASTER_PROMPT.md`, `PHASE1_2_STATUS.md`) — these describe features more broadly than the code supports and should not be trusted as status. `test_parse.dart` is a stray scratch script at root. `android/.../Test.kt` is dead scratch Kotlin compiled into the app. `assets/local_config/` exists but is empty (`.gitkeep` only).

---

## 4. Feature Status Table

Legend: exactly one state per feature. Evidence = file:line anchors.

| # | Feature | Status | Evidence / Rationale |
|---|---|---|---|
| 4.1 | Text chat + SSE streaming response rendering | SOURCE PRESENT UNVERIFIED | `ai_service.dart:433 sendMessageStream`, `home_screen.dart:170-204` streams chunks into bubble; 90 s timeout. Never compiled/run here — unverified. |
| 4.2 | Agent-mode interpretation (imperative routing, root-goal preservation) | PARTIALLY IMPLEMENTED | `home_screen.dart:305-328 _looksLikeAgentTask` keyword router → direct `execute_task`; root goal threaded through executor prompts & final verification (`task_executor.dart:758`). But routing is crude keyword matching; ambiguous phrasing falls into chat mode silently. Unverified at runtime. |
| 4.3 | Ordered sub-goals / expected-result planning | PARTIALLY IMPLEMENTED | Executor prompt requires `expected_result` per step (`task_executor.dart:92-100`); `expectedResult` parsed (:467) but **only stored/parsed — never compared against observation before acting**; `AgentCore.planTask` (:116-153) exists but is orphaned (never called by real path). |
| 4.4 | Semantic target selection + confidence gating (0.72) | VERIFIED WORKING* (code-complete, logic consistent; runtime unproven) | `task_executor.dart:520-556`: confidence <0.72 blocks click/type/scroll/swipe/open_app, forces re-observe, escalates after 3; `click_at` additionally requires non-empty `target_reason` + in-bounds coords (:556-562). *No runtime evidence possible without toolchain. |
| 4.5 | Accessibility observation (bounded native timeouts) | PARTIALLY IMPLEMENTED | `screen_automation_service.dart:14-29`: `_invoke` wrapper applies 3 s timeout, **but only some methods use it** — `dumpScreen`, `clickByText`, `typeText`, `scroll`, `getCurrentPackage`, etc. use raw `_channel.invokeMethod` with plain try/catch (:81, :289, :309…), so a hung channel can block indefinitely on the hot loop's most-used calls. |
| 4.6 | Screenshot/vision fallback gating | SOURCE PRESENT UNVERIFIED | `Api30ScreenshotHelper.kt` + MainActivity gate on API ≥30 (`MainActivity.kt:272-289`); Dart gates on `_aiService.supportsVision` and skips when screen flagged sensitive (`screen_automation_service.dart:102-114`, `task_executor.dart:317-326`). |
| 4.7 | Action execution + cancellation | VERIFIED WORKING* (design) | Stop button → `ActionHandler.cancelTask()` → `TaskExecutor.cancel()` completes a `Completer` racing the AI call (`task_executor.dart:52-57, 360-377`); cancellation checked between every step. *Runtime unproven. |
| 4.8 | Action verification (pre/post snapshots) | VERIFIED WORKING* | `VerificationService.hasChanged` fingerprint diffing (`verification_service.dart:77-81, 224-248`); every mutating action in both ActionHandler and TaskExecutor wraps capture→act→verify. Unit-tested in `test/verification_test.dart`. |
| 4.9 | Final goal verification (app-hint package checks, visible-outcome regex) | VERIFIED WORKING* | `verification_service.dart:108-144 verifyTaskGoal`; `done` action refuses completion unless verified, re-observes up to 3 times (`task_executor.dart:755-772`). |
| 4.10 | Recovery / bounded retries / stuck-task handling | PARTIALLY IMPLEMENTED | RecoveryEngine categorizes failures & proposes alternatives (`recovery_engine.dart`); consecutive-failure stuck exit at 5 (`task_executor.dart:807-827`); low-confidence escalation at 3. **But unchanged-screen (fingerprint-stall) detection is NOT wired into the executor loop** — `hasChanged` exists yet no `fingerprint`/`unchanged` reference appears in `task_executor.dart`; a task can ping-pong two alternating screens forever within maxSteps. |
| 4.11 | Deterministic fast paths (skill replay + navigation shortcuts) | PARTIALLY IMPLEMENTED | SavedSkill replay gated on `verifyTaskGoal` (`task_executor.dart:158-190`); hardcoded shortcuts for dark mode/wifi/bluetooth/app opens (`task_executor.dart:1213-1260`). Shortcut failure falls back to AI mid-sequence; replay records failures. Runtime unverified. |
| 4.12 | WhatsApp messaging w/ explicit confirmation | PARTIALLY IMPLEMENTED | Confirmation dialog for sensitive goals incl. whatsapp markers (`home_screen.dart:330-368`) happens **before** execution; actual WhatsApp message composition relies purely on generic type/click actions + goal verification hints (`verification_service.dart:115`). No dedicated WhatsApp deep-intent flow. |
| 4.13 | YouTube search/play/subscribe w/ confirmation | PARTIALLY IMPLEMENTED | Same generic path: 'subscribe' is a confirmation marker (`home_screen.dart:337`) and a verification outcome word (`verification_service.dart:134`). No YouTube-specific fast path beyond open-app shortcut. |
| 4.14 | App launch / Google search / settings / attachments / Shizuku / notifications | PARTIALLY IMPLEMENTED | App launch verified via foreground-package check (`action_handler.dart:48-73`); Google search via `web_operation_service.search` (browser URL); Shizuku optional with availability probe (`shizuku_service.dart:12`); notifications via flutter_local_notifications + permission request. **Attachments: native picker fully implemented (`MainActivity.kt:57-140`, files channel) but NO Dart-side caller exists — `pickDocuments` referenced nowhere in lib/**; dead native feature. |
| 4.15 | Microphone/speech input, TTS, stop button, listening states | SOURCE PRESENT UNVERIFIED | `voice_service.dart` full stt+tts lifecycle with event stream; mic button toggles listening (`home_screen.dart:511-540`); TTS speaks plain-text replies (`home_screen.dart:271`). |
| 4.16 | TRUE wake-word detection ("Hey Cypher") | **BROKEN** | Native channel handlers + EventChannel registered (`MainActivity.kt:23, 142-158, 168-210`) referencing **`BackgroundWakeWordService`, a class that does not exist anywhere** → Kotlin won't compile. Dart side equally broken: `settings_screen.dart:547-548, 579, 603` calls `voiceService.wakeWordAvailable / wakeWordListening / startWakeWordMode / stopWakeWordMode` — **none exist in VoiceService** → Dart won't compile. Settings tile, persistence (`settings_service.dart:127-140`), and manifest lack of a foreground-service declaration confirm design intent without implementation. There is **no real detector and no background lifecycle**; the feature must not be claimed as working. |
| 4.17 | Floating orb/overlay + permission + entrypoint + handoff | SOURCE PRESENT UNVERIFIED | `flutter_overlay_window` (locally patched, path override `pubspec.yaml:58-60`); overlay entrypoint `overlayMain` (`main.dart:13-40`); lifecycle-gated show/hide with generation guards (`home_screen.dart:639-703`); bubble→chat handoff via file-based protocol (`chat_history_service.dart:39-86`, polled every 500 ms `home_screen.dart:594-605`). |
| 4.18 | Conversations persistence / new chat / load / delete | SOURCE PRESENT UNVERIFIED | `ChatHistoryService.saveSession/loadSessions/deleteSession/clearAll` + session list in drawer (`home_screen.dart:1053-1150`). |
| 4.19 | Message regeneration / edit-resend / per-message cancel | **NOT IMPLEMENTED** | Zero references to regeneration/edit/resend anywhere in lib/. Only global Stop during load (`home_screen.dart:897-922`) and new-chat reset. |
| 4.20 | Developer Mode + telemetry panel + sanitized export | PARTIALLY IMPLEMENTED | Toggle + live snapshot panel + diagnostics refresh exist (`settings_screen.dart:76-300, 2089+`); telemetry sanitization unit-tested. **BUT export path calls `DiagnosticsService.buildSanitizedDeveloperReport` (does not exist — see §6) and reads nonexistent `snapshot.upgradeFinalResult` → Developer Mode export crashes at compile time.** |
| 4.21 | Self-development / controlled upgrade / checkpoints / rollback | **BROKEN (UI-only shell)** | Entire panel (`settings_screen.dart:1851+, 2347`) depends on three **missing files**: `controlled_upgrade_service.dart`, `artifact_service.dart`, `widgets/unified_task_workspace.dart`. No IDENTIFY→PROPOSE→APPLY→VALIDATE machinery exists in the repo. |
| 4.22 | Responsive UI overflow risk | PARTIALLY IMPLEMENTED | Fixed-width rows exist (`SizedBox(width: 118)` upgrade rows `settings_screen.dart:1866`, suggestion chips fixed height 52); chat ListView uses Expanded properly. Small-screen landscape overflow plausible in settings panels but not confirmed without running. |
| 4.23 | Credential handling / secret leakage prevention | VERIFIED WORKING* (static review) | Keys in `flutter_secure_storage` with legacy-migration (`ai_service.dart:63-170`); `normalizeApiKey` strips Bearer/quotes, rejects newlines (`secure_credential_manager.dart:16`); header builder omits referral headers; repo scan found **no hardcoded keys** (the one regex hit is a UI placeholder hint `sk-xxxx…`, `onboarding_screen.dart:1171`). Diagnostics export passes endpoint/model but not key. |

---

## 5. Declaration vs Call-Site Findings (compile/type/API inconsistencies)

**Compile-breaking (would fail `flutter analyze` / Kotlin build today):**

1. **Missing Dart files imported by `settings_screen.dart`** (lines 20, 21, 32):
   - `../services/controlled_upgrade_service.dart` — symbols used: `ControlledUpgradeService.shared` (:94), `.loadHistory` (:244), `.restoreLastKnownWorking` (:1845) — defined nowhere in repo.
   - `../services/artifact_service.dart` — `ArtifactService.shared.exportText(...)` (:286) — defined nowhere.
   - `../widgets/unified_task_workspace.dart` — `const UnifiedTaskWorkspace()` (:2347) — defined nowhere.
2. **Missing symbol `DiagnosticsService.buildSanitizedDeveloperReport`** — called at `settings_screen.dart:263` with named args `{snapshot:, system:}`; `diagnostics_service.dart` defines only instance `Future<DiagnosticResult>` checks and no such static.
3. **Nonexistent field `snapshot.upgradeFinalResult`** — read at `settings_screen.dart:291,293` on `TaskDeveloperSnapshot` (`task_telemetry_service.dart:226-277` has no such field).
4. **Missing Kotlin class `BackgroundWakeWordService`** — referenced 6× in `MainActivity.kt` (:147, :154, :169, :174-177, :189, :195-197). No such file under kotlin/. Native build fails.
5. **Missing VoiceService wake-word API** — `wakeWordAvailable`, `wakeWordListening`, `startWakeWordMode()`, `stopWakeWordMode()` called from `settings_screen.dart` (:547-548, :579, :603); absent from `voice_service.dart`.

**Stale/dead artifacts (non-breaking but misleading):**

6. `Test.kt` — leftover scratch file compiled into the APK.
7. `local_plugins/agent_native` — full plugin scaffold bound to nothing; not in pubspec, not imported.
8. `pickDocuments` files-channel (`MainActivity.kt:57-140`) — complete native implementation with zero Dart callers.
9. `AgentCore`, `ExecutionPipeline`, `BiometricService`, `TaskSchedulingService` — initialized in `AgentSetup` but never consumed by any screen or executor; the live task path uses AiService+ActionHandler instead. `UserMemoryService.getMemorySummary()` (`user_memory_service.dart:176`) — designed "to include in AI context" — **is never called**; memories can be written from Settings but never reach the model.
10. Manifest declares no `BackgroundWakeWordService` service either — consistent with it never existing, contradicting the manifest's FOREGROUND_SERVICE comment trail.
11. Bounded-timeout inconsistency: `ScreenAutomationService._invoke` (3 s) applied to `ping/takeScreenshot/logToNative/isServiceRunning/getAccessibilityDiagnostics` only; hot-loop methods (`dumpScreen`, `getCurrentPackage`, `clickByText`, `typeText`, `scroll`, …) bypass it.
12. Tests import mix `package:agent_cypher/...` and relative `../lib/...`; both work under Flutter tooling but the suite is unrunnable here (no SDK). Test expectations checked against source constants (e.g., `nvidiaDefaultModel = 'nvidia/nemotron-3-nano-30b-a3b'` matches `ai_service_test.dart`) — no stale assertions found in static comparison.

---

## 6. Runtime Blockers (ordered)

1. **App does not compile** — findings §6 items 1–5 above (3 missing Dart modules + 1 missing symbol + 1 missing field + 1 missing Kotlin class + missing Dart API).
2. No Flutter/Dart SDK on this machine → cannot validate anything post-repair until installed.
3. JDK 17 required for Android build; only Java 8 present.
4. No Android SDK/device → accessibility automation, screenshots (API≥30 gate), overlay, speech cannot be exercised even after compilation.
5. First `pub get` downloads ~20 plugins including the locally-patched overlay window — needs network.

---

## 7. Security & Privacy Findings

- ✅ No secrets committed (full lib scan; assets/local_config empty).
- ✅ Keys stored via `flutter_secure_storage`; legacy SharedPreferences migration normalizes then stores securely; logs never print the key (header construction only).
- ⚠️ `QUERY_ALL_PACKAGES` permission granted — broad, Play-policy-sensitive; justified for an automation app but worth narrowing to queried packages.
- ⚠️ Screen-content summaries (potentially including notification text/message previews) go to third-party LLM endpoints as plain HTTPS payloads; there IS an `is_sensitive` guard for screenshots (`getVisualObservation`) but **no equivalent redaction for text dumps** — user consent surface only at onboarding.
- ⚠️ Diagnostics export includes provider endpoint/model + permission state; sanitized by design, but export currently unreachable (§6 item 2) so sanitization path itself is unverified at runtime.
- ⚠️ `ShizukuProvider` exported with `INTERACT_ACROSS_USERS_FULL` permission attribute — standard for Shizuku but exposes the provider to other apps holding that system permission.

## 8. UI/Layout Findings

- Overlay show/hide races guarded by generation counters and lifecycle checks (`home_screen.dart:639-703`) — solid pattern; double-snapshot cold-start workaround acknowledged in comments.
- Fixed-width label column (118 px) in upgrade panel risks overflow on small screens with large font scale; suggestion chip row is horizontally scrollable (OK); chat list uses Expanded + BouncingScrollPhysics (OK).
- Mode selector, input bar, drawer all use theme-aware colors; no obvious hard-coded light-only colors except overlay MaterialApp in `main.dart:19-33` which pins a light ColorScheme for the overlay bubble regardless of app theme (cosmetic inconsistency).

## 9. Automation-Reliability Findings

- Strengths: confidence gating, per-action pre/post verification, final-goal gating with re-observe, recovery strategy fan-out, skill replay with reliability decay, cancellation racing, bounded AI-call latency via `Future.any`-style race.
- Gaps: (a) no unchanged-fingerprint stall detector inside the loop despite the primitive existing; (b) `expected_result` captured but never machine-checked; (c) timeout wrapper inconsistently applied to hot-path channels; (d) shortcut steps that partially complete leave state half-navigated before AI fallback; (e) WhatsApp/YouTube rely on generic loops — brittle against app updates.

## 10. Smallest Prioritized Repair Plan (for a future implementation pass — NOT executed)

| P# | Repair | Files changed | Tests required |
|---|---|---|---|
| P1 | Restore compilability: create minimal `controlled_upgrade_service.dart`, `artifact_service.dart`, `unified_task_workspace.dart` stubs OR remove the three imports + upgrade panel + export call; add `buildSanitizedDeveloperReport` to DiagnosticsService or inline report building; remove `upgradeFinalResult` reads | `settings_screen.dart`, `diagnostics_service.dart`, (+3 new or −~500 lines) | `flutter analyze` clean; widget test for settings render |
| P2 | Wake-word decision: implement `BackgroundWakeWordService.kt` + add VoiceService wake API + manifest service entry, **or** remove channel registration + settings tile. Do not ship half | `MainActivity.kt` (or new .kt), `AndroidManifest.xml`, `voice_service.dart`, `settings_screen.dart` | analyze + Kotlin compile; manual device test for detection lifecycle |
| P3 | Apply `_invoke` timeout to all hot-path methods | `screen_automation_service.dart` | extend `screen_automation_service_test.dart` |
| P4 | Wire unchanged-screen stall detection into executor loop using existing `VerificationService.hasChanged` | `task_executor.dart` | unit test with fake snapshots |
| P5 | Delete dead code: `Test.kt`, `agent_native/` (or wire intentionally), decide fate of `AgentCore/ExecutionPipeline/Biometric/TaskScheduling` (consume or remove) | those files | analyze |
| P6 | Attachments: implement Dart caller for `pickDocuments` or remove channel | `MainActivity.kt` + new Dart service | integration test |
| P7 | Memory injection: call `getMemorySummary()` in prompt assembly or hide memory UI | `ai_service.dart` or `user_memory_service.dart` | prompt-construction unit test |

## 11. Risks & Rollback

- All repairs touch few files; since **there is no git repo**, establish VCS (or at minimum a full-folder backup copy) **before** any repair pass — rollback otherwise means restoring from that copy manually.
- Highest-risk edits: removing the upgrade panel (large UI surgery in a 2696-line file) vs stubbing (fastest, keeps UI inert). Stubbing recommended first; removal later.
- Wake-word implementation requires mic foreground-service battery/permission behavior testing on real devices — highest uncertainty; removal is zero-risk.
- After repairs: `flutter analyze` → `flutter test` → debug build on device → manual automation scenarios (WhatsApp send w/ confirm, YouTube search, app open verification) before any "working" claim.

---

### Bottom line

The architecture is coherent and unusually disciplined about verification (snapshots, fingerprints, confidence gates, goal re-checks), but **the project does not compile today**: five independent missing-symbol/class/file defects, concentrated in the Developer/self-upgrade area and the wake-word feature, which together are UI shells over non-existent implementations. Everything else ranges from code-complete-unverified to partial. No feature may be claimed working until the toolchain exists, the build passes, and a real device exercises the automation loop.
