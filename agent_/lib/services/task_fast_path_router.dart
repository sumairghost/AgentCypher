library;

import '../models/task_plan.dart';
import '../models/fast_path_route.dart';
import '../models/capability_registry.dart';
import '../config/feature_flags.dart';

/// Deterministic fast-path router. No LLM calls, no external APIs.
/// Only recognized clear, safe, low-risk patterns.
class TaskFastPathRouter {
  static final _youtubePattern = RegExp(
    r'(?i)(?:open\s+youtube|search\s+youtube).*?(?:search\s+for|search)\s+(.+)',
  );
  static final _volumePattern = RegExp(
    r'(?i)set\s+volume\s+to\s*(\d+)\s*$',
  );
  static final _brightnessPattern = RegExp(
    r'(?i)set\s+brightness\s+to\s*(\d+)\s*$',
  );

  /// Try to match the user goal to a deterministic plan.
  /// Returns matched=false for ambiguous, unsupported, or side-effecting requests.
  FastPathRoute tryRoute(String goal) {
    final normalized = goal.trim().toLowerCase();

    // Reject media-post / external-publishing intents when the workflow
    // gate is off (default) or when the capability requires fresh confirmation.
    if (CapabilityRegistry.isExternalPublishingIntent(normalized)) {
      if (!FeatureFlags.mediaPostWorkflowEnabled) {
        return const FastPathRoute(
          matched: false,
          reason: 'Media post workflow disabled (FeatureFlags.mediaPostWorkflowEnabled = false). Use main app for draft-to-confirm.',
        );
      }
      // Even when enabled, fast path rejects — requires full typed plan,
      // media picker, and fresh confirmation (CapabilityEntry.requiresFreshConfirmation = true).
      return const FastPathRoute(
        matched: false,
        reason: 'External publishing requires MediaPostPlan + fresh confirmation; fast-path excluded by design.',
      );
    }

    // Reject sensitive / unsupported / external side-effect patterns explicitly
    if (_isSensitiveOrUnsupported(normalized)) {
      return const FastPathRoute(
        matched: false,
        reason: 'Sensitive or unsupported request',
      );
    }

    // YouTube search only when clearly phrashed
    final youtubeMatch = _youtubePattern.firstMatch(goal);
    if (youtubeMatch != null) {
      final query = youtubeMatch.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return FastPathRoute(
          matched: true,
          routeName: 'youtube_search',
          plan: _buildYouTubeSearchPlan(query),
        );
      }
    }

    // Device state only when numeric unambiguous 0-100
    final vol = _volumePattern.firstMatch(goal);
    if (vol != null) {
      final v = int.tryParse(vol.group(1)!);
      if (v != null && v >= 0 && v <= 100) {
        return FastPathRoute(
          matched: true,
          routeName: 'volume',
          plan: _buildDeviceStatePlan('volume', v),
        );
      }
    }

    final bright = _brightnessPattern.firstMatch(goal);
    if (bright != null) {
      final b = int.tryParse(bright.group(1)!);
      if (b != null && b >= 0 && b <= 100) {
        return FastPathRoute(
          matched: true,
          routeName: 'brightness',
          plan: _buildDeviceStatePlan('brightness', b),
        );
      }
    }

    return const FastPathRoute(matched: false, reason: 'No clear fast path');
  }

  bool _isSensitiveOrUnsupported(String s) {
    // Messages, purchases, subscriptions, deletes, account, playback guarantees
    final bad = RegExp(
      r'(?i)(message|send|subscribe|purchase|buy|delete|remove|install|download|login|signup|pay|subscribe|account|video\s+seek|seek\s+to|start\s+at|halfway|full.screen|fullscreen)',
    );
    return bad.hasMatch(s);
  }

  TaskPlan _buildYouTubeSearchPlan(String query) => TaskPlan(
    rootGoal: 'Open YouTube and search for $query',
    steps: [
      PlanStep(
        id: 'yt_open',
        intent: 'Open YouTube',
        action: 'open_app',
        params: {'app_name': 'YouTube'},
        requiredApp: 'YouTube',
        verificationMethod: VerificationMethod.appForeground,
        expectedResult: 'YouTube foreground',
        retryPolicy: const RetryPolicy(maxAttempts: 2),
      ),
      PlanStep(
        id: 'yt_search',
        intent: 'Search for $query',
        action: 'click_text',
        params: {'text': 'Search'},
        requiredApp: 'YouTube',
        dependsOn: ['yt_open'],
        verificationMethod: VerificationMethod.contentVisible,
        expectedResult: 'search field',
      ),
      PlanStep(
        id: 'yt_type',
        intent: 'Type query $query',
        action: 'type_text',
        params: {'text': query},
        requiredApp: 'YouTube',
        dependsOn: ['yt_search'],
        verificationMethod: VerificationMethod.textTyped,
        expectedResult: query,
      ),
      PlanStep(
        id: 'yt_submit',
        intent: 'Submit search',
        action: 'press_enter',
        requiredApp: 'YouTube',
        dependsOn: ['yt_type'],
        verificationMethod: VerificationMethod.screenChanged,
        expectedResult: 'results',
      ),
    ],
  );

  TaskPlan _buildDeviceStatePlan(String kind, int value) => TaskPlan(
    rootGoal: 'Set $kind to $value',
    steps: [
      PlanStep(
        id: 'dev_${kind}_set',
        intent: 'Set $kind to $value',
        action: kind == 'volume' ? 'set_volume' : 'set_brightness',
        params: {'level': value},
        verificationMethod: VerificationMethod.deviceState,
        expectedValue: value,
        expectedResult: '$value',
        reversible: true,
        requiresConfirmation: false,
        retryPolicy: const RetryPolicy(maxAttempts: 2),
      ),
    ],
  );
}
