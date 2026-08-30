# Cypher Developer Console Skill

## Purpose
Internal engineering console for Agent Cypher — not a cosmetic settings page. Hidden activation, live diagnostics, theme/orb/model/agent control, source-agent workflow, checkpoints.

## Activation
Settings → About Cypher → Build number: ~7 rapid taps → "Developer mode enabled" → Settings → Developer exposed.

## Safety
- No API keys or authorization headers exposed in UI/logs/exports.
- No silent source modification; Code Agent requires approval before write.
- No fake permission enablement; matrix reflects real Android states.
- Development-only features (dangerous diagnostics, code agent, checkpoints, reset destructive) guarded by build environment capability.
- Evidence-based status only: OK / WARNING / ERROR / UNAVAILABLE / NOT TESTED.

## Architecture
- CypherDeveloperConfig (ChangeNotifier, SharedPreferences) for runtime config.
- Theme Studio uses existing theme token architecture (cypher_theme, theme_controller) — do not bypass.
- Feature flags must map to actual behavior (feature_flags.dart, FeatureFlags static constants).
- Checkpoints integrate with existing ControlledUpgradeService / TaskTelemetryService when available.
- All diagnostics sanitize secrets before export (DiagnosticsService.buildSanitizedDeveloperReport).
