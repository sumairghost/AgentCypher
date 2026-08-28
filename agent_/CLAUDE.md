--- BEGIN AGENT CYPHER DEVELOPMENT RULES ---

## Agent Cypher Development Rules

### Project identity

Agent Cypher is a Flutter/Dart and native Android/Kotlin AI assistant. It combines chat, task planning, accessibility-driven UI automation, action verification, recovery, voice/TTS, overlay windows, Android permissions, local persistence, OpenAI-compatible provider routing, and device automation.

Treat Android platform behavior as a first-class part of the app. Do not replace native Android functionality with Flutter mocks where real Android lifecycle, service, permission, accessibility, media, overlay, or system-setting behavior is required.

### Current truth and deferred features

Treat source code, analyzer results, tests, build results, logs, and real-device results as evidence. Treat README/status documents as claims until verified.

The project may not currently compile or have a complete local Flutter/Android toolchain. Never claim a feature is fully working from source inspection alone.

Do not implement, repair, remove, or redesign wake-word functionality or the self-upgrade/developer upgrade panel unless the user explicitly asks for that exact feature in a separate task.

### Change discipline

For every non-trivial task:

1. Inspect the relevant code and callers.
2. Explain the existing behavior and smallest safe change.
3. Make a focused plan before editing.
4. Implement the smallest maintainable vertical slice.
5. Add or update focused tests when practical.
6. Run only validation that is actually available.
7. Report changed files, exact commands/results, evidence, unresolved risks, and what remains unverified.

Do not perform broad rewrites, unnecessary formatting, dependency upgrades, or unrelated cleanup. Preserve existing verification, cancellation, recovery, credential, and accessibility logic unless a deliberate replacement is justified.

### Flutter to Android rule

Before changing a platform-dependent capability, trace:

Dart caller → MethodChannel/EventChannel → Kotlin implementation → Android component/service → AndroidManifest.xml/permission → lifecycle state → result/error mapping → tests.

Consider foreground, background, killed process, locked screen, reboot, network loss, permission denied/revoked, service restart, and device-specific restrictions.

### Complex task execution standard

For complex natural-language tasks, use a structured typed plan with stable step IDs, dependencies, preconditions, target/app context, action type, expected result, verification method, retry policy, reversibility, confirmation requirements, and explicit step status.

Separate observation, planning, action selection, execution, post-action observation, verification, recovery, and final reporting. Do not treat a non-throwing action call as success. Do not advance past a required failed or unverified step.

Use bounded retries, bounded waits, cancellation checks, and unchanged-state detection. Stop and report honestly when a capability is unsupported, permission is denied, the app context is wrong, the target cannot be identified safely, or progress stalls.

### Performance standard

Agent Cypher must be fast enough to be useful. Prefer deterministic direct actions, targeted accessibility queries, targeted screen observations, state reuse, short structured model prompts, and condition-based waits. Avoid repeated full-screen dumps, fixed long sleeps, redundant model calls, unnecessary screenshots, and duplicate retries.

Instrument latency for planning, observation, model calls, execution, verification, recovery, and total task time. Optimize without weakening confidence gating, permission checks, target safety, cancellation, verification, or honest error reporting. Never promise a speed result that was not benchmarked on a device.

### Voice, overlays, accessibility, and permissions

Treat microphone, background voice, overlay, accessibility, notifications, and system settings as sensitive Android capabilities. Never bypass Android permissions, user consent, platform restrictions, or accessibility enablement. Degrade gracefully when access is denied.

Treat voice as a state machine: idle, waiting, wake detected, recording, processing, speaking, cancelled, permission denied, service stopped, and recovery. Do not claim background operation without device evidence.

### Security and privacy

Never hardcode, print, commit, or expose API keys, provider tokens, authorization headers, keystores, signing passwords, or secrets in Dart, Kotlin, assets, resources, logs, tests, or Git history.

Review exported Android components, intents, deep links, WebViews, local server binding, sensitive logs, clipboard use, backup behavior, debug settings, permissions, and accessibility features. Do not weaken security controls merely to make a test pass.

Minimize screen text and sensitive observations sent to external models. Preserve sensitive-screen protections and redact sensitive content where practical.

### Validation standard

Use evidence-based status labels: implemented, statically reviewed, analyzer-validated, unit-tested, build-validated, emulator-tested, real-device-tested, blocked, or unverified.

When tooling exists, use suitable commands such as `flutter analyze`, `flutter test`, `flutter build apk --debug`, `adb devices`, and filtered `adb logcat`. If tooling is missing, report that limitation without installing anything unless asked.

### Delegation

Use the project-local specialist agents when relevant:

- `flutter-android-architect`: platform channels, Kotlin/Flutter integration, Android services, manifests, lifecycle, permissions.
- `task-execution-architect`: structured plans, actions, verification, recovery, dependencies, cancellation, partial completion.
- `execution-performance-engineer`: latency, fast paths, bounded waits, observation/model-call efficiency, benchmarking.
- `voice-runtime-engineer`: voice, microphone, audio focus, foreground-service lifecycle, background behavior.
- `overlay-accessibility-engineer`: overlays, AccessibilityService, consent, notifications, safe UI interaction.
- `device-test-engineer`: Flutter/Android tests, ADB, logcat, emulator and real-device matrices.
- `security-release-reviewer`: secrets, permissions, exported components, privacy, release safety.

Prefer a read-only specialist review before an architectural or security-sensitive edit. The main session should implement approved changes in small, reviewable slices.

--- END AGENT CYPHER DEVELOPMENT RULES ---
