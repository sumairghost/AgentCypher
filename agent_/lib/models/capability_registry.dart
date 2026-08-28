library;

import 'task_plan.dart';

/// Safety classification for a capability. Drives confirmation policy.
enum SafetyClass {
  /// Action can be undone on the same device with no external side effect.
  reversible,

  /// Action has effects outside the device (e.g. publish a post, send a
  /// message, complete a payment). Always requires fresh confirmation.
  irreversibleExternal,

  /// Action touches the user's account, identity, or installed software.
  /// Requires confirmation and may prompt main-app review.
  sensitiveAccount,
}

/// What the executor should do when verification fails or the capability
/// is unsupported. Never fabricate success.
enum FallbackBehavior {
  /// Stop and report an honest unverified result.
  abort,

  /// Continue execution but mark the step as unverified and surface the
  /// gap to the user in the final summary.
  reportUnverified,

  /// Do not attempt; prompt the user to review in the main app.
  promptReview,
}

/// Typed action contract for a single capability. Capabilities describe
/// "what we can do" without encoding the order of steps (the plan does that).
class CapabilityEntry {
  /// Stable id, e.g. `instagram.create_post`.
  final String id;

  /// Apps this capability targets. Empty when context-free (e.g. set_volume).
  final List<String> apps;

  /// Allowed action names from [TaskPlan.supportedActions].
  final List<String> actions;

  /// Human-readable assumption about the app version / UI shape. Not a
  /// guarantee; used for documentation and telemetry.
  final String appVersionAssumption;

  /// Required input fields and their type tag (string/int/bool/list/url/path).
  /// Used by the planner validator; enforced at the boundary, not at runtime.
  final Map<String, String> inputSchema;

  /// Observed output fields the verifier can check. Values are
  /// semantic expectations, not raw coordinates.
  final Map<String, String> outputSchema;

  final SafetyClass safety;
  final VerificationMethod defaultVerification;
  final FallbackBehavior fallback;

  /// Bounded wait for the whole capability (planning + execution + verify).
  final Duration timeout;

  /// True when the final action needs a fresh user confirmation at the
  /// moment of execution — never cached from earlier confirmations.
  final bool requiresFreshConfirmation;

  const CapabilityEntry({
    required this.id,
    required this.apps,
    required this.actions,
    required this.appVersionAssumption,
    this.inputSchema = const {},
    this.outputSchema = const {},
    this.safety = SafetyClass.reversible,
    this.defaultVerification = VerificationMethod.screenChanged,
    this.fallback = FallbackBehavior.abort,
    this.timeout = const Duration(seconds: 30),
    this.requiresFreshConfirmation = false,
  });
}

/// Registry of supported capabilities. Hard-coded for the initial release —
/// no runtime plugin discovery, no external API. New capabilities are added
/// by listing them here and referencing from the planner.
class CapabilityRegistry {
  static const CapabilityEntry instagramCreatePost = CapabilityEntry(
    id: 'instagram.create_post',
    apps: ['Instagram', 'com.instagram.android'],
    actions: [
      'open_app',
      'click_text',
      'click_at',
      'type_text',
      'press_enter',
    ],
    appVersionAssumption:
        'Instagram Android with a Create (+) affordance and New Post flow.',
    inputSchema: {
      'image_ref': 'path', // user-confirmed picker result, not auto-scanned
      'caption': 'string',
    },
    outputSchema: {
      'preview_visible': 'bool',
      'post_observed': 'bool',
    },
    safety: SafetyClass.irreversibleExternal,
    defaultVerification: VerificationMethod.contentVisible,
    fallback: FallbackBehavior.reportUnverified,
    timeout: const Duration(seconds: 90),
    requiresFreshConfirmation: true,
  );

  static const CapabilityEntry youtubeSearch = CapabilityEntry(
    id: 'youtube.search',
    apps: ['YouTube', 'com.google.android.youtube'],
    actions: ['open_app', 'click_text', 'type_text', 'press_enter'],
    appVersionAssumption: 'YouTube Android with visible Search affordance.',
    inputSchema: {'query': 'string'},
    outputSchema: {'results_visible': 'bool'},
    safety: SafetyClass.reversible,
    defaultVerification: VerificationMethod.contentVisible,
    fallback: FallbackBehavior.reportUnverified,
    timeout: const Duration(seconds: 45),
    requiresFreshConfirmation: false,
  );

  static const CapabilityEntry setDeviceState = CapabilityEntry(
    id: 'device.set_volume_or_brightness',
    apps: [],
    actions: ['set_volume', 'set_brightness'],
    inputSchema: {'level': 'int', 'kind': 'string'},
    outputSchema: {'verified_value': 'int'},
    safety: SafetyClass.reversible,
    defaultVerification: VerificationMethod.deviceState,
    fallback: FallbackBehavior.abort,
    timeout: const Duration(seconds: 8),
    requiresFreshConfirmation: false,
  );

  static const List<CapabilityEntry> all = [
    instagramCreatePost,
    youtubeSearch,
    setDeviceState,
  ];

  static CapabilityEntry? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// True when the natural-language goal matches a known capability
  /// heuristic. Used by the router to decide between fast-path,
  /// planner, and explicit rejection.
  static bool isExternalPublishingIntent(String goal) {
    final lower = goal.toLowerCase();
    const externalPostVerbs = [
      'post',
      'publish',
      'share to',
      'upload to',
      'tweet',
      'reel',
      'story',
    ];
    const socialTargets = [
      'instagram',
      'twitter',
      'x (',
      'x app',
      'tiktok',
      'facebook',
      'snapchat',
      'linkedin',
    ];
    final hasVerb = externalPostVerbs.any(lower.contains);
    final hasTarget = socialTargets.any(lower.contains);
    return hasVerb && hasTarget;
  }
}
