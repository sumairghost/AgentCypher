import 'dart:async';

import '../../models/agent_action.dart';
import '../../models/chat_message.dart';
import '../../models/task_plan.dart';
import '../../services/action_handler.dart';
import '../../services/ai_service.dart';

/// Coarse grouping used by discovery surfaces. Only categories with real
/// tools exist in this app; there is deliberately no media or flashlight
/// category because no such capability exists in Cypher services today.
enum ToolCategory { android, system, web, files, communication, task, conversation }

/// Concurrency classification (Phase 9). Drives the runtime's bounded batch
/// scheduler: only [readOnly] tools may ever run concurrently.
enum ToolAccess {
  /// Pure observation; no user-visible state change.
  readOnly,

  /// Changes device/file state but does not touch foreground UI.
  mutating,

  /// Depends on or changes foreground UI, runs privileged shell, or
  /// orchestrates whole tasks; must never run alongside anything else.
  exclusive,
}

/// How a tool's outcome is actually verified by the existing code, in
/// increasing order of strength. This is a description of real behavior,
/// not an aspiration.
enum ToolVerificationStrategy {
  /// App actually became foreground (snapshot package check).
  foregroundPackage,

  /// Device value read back and compared within tolerance.
  stateReadBack,

  /// Post-action observation differs from the pre-action fingerprint.
  screenChanged,

  /// Expected words visible in the post-action observation.
  contentVisible,

  /// Typed text found in the post-action observation.
  textTyped,

  /// The observation capability itself succeeded (read/screenshot).
  captureSucceeded,

  /// Weakest: the native dispatch returned without an error string.
  nativeCallSucceeded,

  /// Every plan step is machine-verified by the plan executor.
  planStepVerification,

  none,
}

/// Failure classification for tool outcomes. Values are only produced where
/// they can be honestly derived from observed handler output; anything else
/// is [unknown] — never a guessed specific type.
enum ToolFailureType {
  none,
  permission,
  timeout,
  unavailableService,
  invalidArguments,
  uiStateMismatch,
  appNotFound,
  transient,
  unsupported,

  /// Consequential-action approval was denied by the user, or no approver
  /// was reachable within the bounded approval window. The tool did not run.
  approvalDenied,
  unknown,
}

/// One tool invocation. Optional fields mirror the existing
/// [ActionHandler.execute] parameters so the built-in adapter is pure
/// delegation; other implementations may ignore what they do not need.
class ToolInvocation {
  final Map<String, dynamic> params;
  final AiService? aiService;
  final void Function(String message)? onProgress;
  final Future<bool> Function(PlanStep step)? onBeforePlanStep;
  final Future<bool> Function(TaskPlan plan)? onPlanPreview;

  const ToolInvocation({
    this.params = const {},
    this.aiService,
    this.onProgress,
    this.onBeforePlanStep,
    this.onPlanPreview,
  });
}

/// Outcome of a tool execution.
///
/// [success] is the existing handler's verdict; for device actions that
/// already folds in real verification (e.g. `open_app` requires the target
/// app to actually become foreground). [failureType] only carries values
/// the adapter can honestly derive from observed handler output.
class ToolExecutionResult {
  final bool success;
  final String detail;

  /// Best-effort classification derived from the handler's own output;
  /// [ToolFailureType.none] exactly when [success] is true.
  final ToolFailureType failureType;

  /// Raw payload when the tool produces one (e.g. screenshot base64).
  final String? payloadBase64;

  final int durationMs;

  const ToolExecutionResult({
    required this.success,
    required this.detail,
    required this.durationMs,
    this.failureType = ToolFailureType.none,
    this.payloadBase64,
  });
}

/// Typed execution-unit boundary.
///
/// Describes "what can be done" with enough metadata for planning, UI, and
/// reliability layers, while execution and verification stay delegated to
/// the existing components. No behavior lives in the interface itself.
abstract interface class CypherTool {
  /// Stable identifier, equal to the existing action id
  /// (e.g. 'open_app', 'execute_task').
  String get id;

  /// One-line honest description of the effect.
  String get description;

  /// Coarse grouping used by discovery surfaces; see [ToolCategory].
  ToolCategory get category;

  /// Parameter names → coarse type tags ('string', 'int', ...). Same
  /// convention as `CapabilityEntry.inputSchema`; an open map means "no
  /// enforced schema", never "any input is safe".
  Map<String, String> get inputSchema;

  /// Permissions/capabilities this tool needs (e.g. 'AccessibilityService
  /// enabled', 'CALL_PHONE', 'Shizuku authorization'), derived from
  /// AndroidManifest.xml and the owning service. Empty = none beyond normal
  /// app operation. These describe requirements; the existing permission
  /// checks remain the enforcement point and are never bypassed.
  List<String> get permissionRequirements;

  /// How the outcome is verified (see [ToolVerificationStrategy]).
  ToolVerificationStrategy get verificationStrategy;

  /// Enforced whole-tool budget, or null when the tool is bounded internally
  /// per call AND cancellable (execute_task: bounded per plan step). Simple
  /// tools declare a budget derived from observed internal bounds (3s
  /// channel cap + up to ~5s verification) — never an invented number.
  Duration? get timeout;

  /// True only when a running execution can actually be cancelled through
  /// the underlying component.
  bool get supportsCancellation;

  /// True when the tool has consequential effects (calls, messages, emails,
  /// file deletion/moves/overwrites, privileged shell commands). The
  /// execution layer must obtain explicit approval before running such a
  /// tool; see the runtime's approval gate. Fast-path-routed tools are all
  /// `false`, so Fast Path latency is unaffected.
  bool get requiresConfirmation;

  /// Concurrency classification; see [ToolAccess].
  ToolAccess get toolAccess;

  Future<ToolExecutionResult> execute(ToolInvocation invocation);

  /// Best-effort cancellation; only meaningful when [supportsCancellation].
  void cancel() {}
}

/// Adapter exposing the EXISTING `ActionHandler` dispatch as typed tools.
/// Execution, verification, retry, and failure handling remain in
/// `ActionHandler`; nothing is duplicated here.
class ActionHandlerTool implements CypherTool {
  final ActionHandler _handler;

  @override
  final String id;

  @override
  final String description;

  @override
  final ToolCategory category;

  @override
  final Map<String, String> inputSchema;

  @override
  final List<String> permissionRequirements;

  @override
  final ToolVerificationStrategy verificationStrategy;

  @override
  final Duration? timeout;

  @override
  final bool supportsCancellation;

  @override
  final bool requiresConfirmation;

  @override
  final ToolAccess toolAccess;

  ActionHandlerTool({
    required ActionHandler handler,
    required this.id,
    required this.description,
    required this.category,
    this.inputSchema = const {},
    this.permissionRequirements = const [],
    required this.verificationStrategy,
    this.timeout,
    this.supportsCancellation = false,
    this.requiresConfirmation = false,
    this.toolAccess = ToolAccess.exclusive,
  }) : _handler = handler;

  @override
  Future<ToolExecutionResult> execute(ToolInvocation invocation) async {
    final watch = Stopwatch()..start();
    try {
      final pending = _handler.execute(
        AgentAction(action: id, params: invocation.params, response: ''),
        aiService: invocation.aiService,
        onProgress: invocation.onProgress,
        onBeforePlanStep: invocation.onBeforePlanStep,
        onPlanPreview: invocation.onPlanPreview,
      );
      final AgentActionResult result;
      if (timeout == null) {
        result = await pending;
      } else {
        // Safety net only: the handler is internally bounded (3s per
        // accessibility call). On expiry we stop waiting; the underlying
        // work remains bounded by those internal caps.
        result = await pending.timeout(
          timeout!,
          onTimeout: () =>
              throw TimeoutException('Tool "$id" exceeded $timeout.'),
        );
      }
      final detail = result.details ?? '';
      return ToolExecutionResult(
        success: result.success,
        detail: detail,
        payloadBase64: result.payloadBase64,
        failureType: _classifyFailure(result.success, detail),
        durationMs: watch.elapsedMilliseconds,
      );
    } on TimeoutException catch (error) {
      return ToolExecutionResult(
        success: false,
        detail: error.message ?? 'Tool "$id" timed out.',
        failureType: ToolFailureType.timeout,
        durationMs: watch.elapsedMilliseconds,
      );
    }
  }

  /// Best-effort classification from the handler's honest detail text.
  /// Defaults to [ToolFailureType.unknown]; never invents a specific type.
  static ToolFailureType _classifyFailure(bool success, String detail) {
    if (success) return ToolFailureType.none;
    final lower = detail.toLowerCase();
    if (detail.startsWith('Unsupported action:')) {
      return ToolFailureType.unsupported;
    }
    if (lower.contains('not enabled') ||
        lower.contains('not available') ||
        lower.contains('not configured')) {
      return ToolFailureType.unavailableService;
    }
    if (lower.contains('permission') || lower.contains('denied')) {
      return ToolFailureType.permission;
    }
    if (lower.contains('may not be installed') ||
        lower.contains('could not find app')) {
      return ToolFailureType.appNotFound;
    }
    if (lower.contains('did not become foreground') ||
        lower.contains('refused')) {
      return ToolFailureType.transient;
    }
    if (lower.contains('invalid') || lower.contains('expected 0-100')) {
      return ToolFailureType.invalidArguments;
    }
    if (lower.contains('could not verify')) {
      return ToolFailureType.uiStateMismatch;
    }
    return ToolFailureType.unknown;
  }

  @override
  void cancel() {
    if (supportsCancellation) _handler.cancelTask();
  }
}

/// Registry of typed tools. Lookup is O(1); registration is explicit and
/// deterministic (no runtime discovery).
class ToolRegistry {
  final Map<String, CypherTool> _tools = {};

  void register(CypherTool tool) => _tools[tool.id] = tool;

  CypherTool? lookup(String id) => _tools[id];

  bool contains(String id) => _tools.containsKey(id);

  List<CypherTool> get all => List.unmodifiable(_tools.values);

  List<CypherTool> inCategory(ToolCategory category) =>
      _tools.values.where((tool) => tool.category == category).toList();

  /// Budget for single native-dispatch tools, derived from observed bounds:
  /// the accessibility channel enforces a 3s per-call timeout and typed
  /// verification waits up to ~5s, so 10s covers the worst case with
  /// margin. `execute_task` is bounded per plan step and cancellable, so it
  /// declares no whole-tool budget instead.
  static const _defaultToolBudget = Duration(seconds: 10);

  /// Seeds the registry from the app's existing `ActionHandler` surface.
  /// Only action ids with a real handler case (verified in source) are
  /// advertised. `read_notifications` is listed in
  /// `AgentAction.availableActions` but has no handler case, so it is
  /// intentionally NOT registered; media/flashlight tools do not exist and
  /// are not fabricated.
  static ToolRegistry withActionHandlerDefaults(ActionHandler handler) {
    final registry = ToolRegistry();
    for (final spec in _specs) {
      registry.register(
        ActionHandlerTool(
          handler: handler,
          id: spec.id,
          description: spec.description,
          category: spec.category,
          inputSchema: spec.schema,
          permissionRequirements: spec.permissions,
          verificationStrategy: spec.verification,
          timeout: spec.cancellable ? null : _defaultToolBudget,
          supportsCancellation: spec.cancellable,
          requiresConfirmation: spec.confirmation,
          toolAccess: spec.access,
        ),
      );
    }
    return registry;
  }
}

/// Static description of one built-in tool. Kept as data so the registry is
/// a plain loop instead of a 30-branch factory.
class _ToolSpec {
  final String id;
  final String description;
  final ToolCategory category;
  final Map<String, String> schema;
  final List<String> permissions;
  final ToolVerificationStrategy verification;

  /// True only when the underlying dispatch actually supports cancellation.
  final bool cancellable;

  /// True when execution must pass the runtime's approval gate first.
  final bool confirmation;

  /// Concurrency classification; defaults to the safe [ToolAccess.exclusive].
  final ToolAccess access;

  const _ToolSpec(
    this.id,
    this.description,
    this.category, {
    this.schema = const {},
    this.permissions = const [],
    required this.verification,
    this.cancellable = false,
    this.confirmation = false,
    this.access = ToolAccess.exclusive,
  });
}

const List<_ToolSpec> _specs = [
  // ── Android ──
  _ToolSpec('open_app', 'Open an installed app by name (fuzzy match, verified foreground).',
      ToolCategory.android,
      schema: {'app_name': 'string'},
      verification: ToolVerificationStrategy.foregroundPackage),
  _ToolSpec('launch_package', 'Open an app by exact package name.', ToolCategory.android,
      schema: {'package_name': 'string'},
      verification: ToolVerificationStrategy.foregroundPackage),
  _ToolSpec('read_screen', 'Read the current screen as structured text.', ToolCategory.android,
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.captureSucceeded),
  _ToolSpec('click_element', 'Click on-screen text and verify the result.', ToolCategory.android,
      schema: {'text': 'string'},
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.screenChanged),
  _ToolSpec('type_on_screen', 'Type text into a field and verify it landed.', ToolCategory.android,
      schema: {'text': 'string', 'field_hint': 'string'},
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.textTyped),
  _ToolSpec('scroll_screen', 'Scroll the screen and verify the change.', ToolCategory.android,
      schema: {'direction': 'string'},
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.screenChanged),
  _ToolSpec('press_back', 'Press the system back button.', ToolCategory.android,
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('press_home', 'Press the system home button.', ToolCategory.android,
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('take_screenshot', 'Capture the screen (Android 11+); reports size and payload.',
      ToolCategory.android,
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.captureSucceeded),
  // ── System ──
  _ToolSpec('set_volume', 'Set the volume level (0-100) with read-back verification.',
      ToolCategory.system,
      schema: {'level': 'int'},
      permissions: ['MODIFY_AUDIO_SETTINGS'],
      verification: ToolVerificationStrategy.stateReadBack),
  _ToolSpec('set_brightness', 'Set the screen brightness (0-100) with read-back verification.',
      ToolCategory.system,
      schema: {'level': 'int'},
      permissions: ['WRITE_SETTINGS'],
      verification: ToolVerificationStrategy.stateReadBack),
  _ToolSpec('set_alarm', 'Create an alarm.', ToolCategory.system,
      schema: {'hour': 'int', 'minute': 'int', 'label': 'string'},
      permissions: ['SET_ALARM'],
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('set_timer', 'Start a countdown timer.', ToolCategory.system,
      schema: {'seconds': 'int', 'label': 'string'},
      permissions: ['SET_ALARM'],
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('run_adb_command', 'Run a shell command via Shizuku (requires authorized Shizuku).',
      ToolCategory.system,
      schema: {'command': 'string'},
      permissions: ['Shizuku authorization'],
      verification: ToolVerificationStrategy.nativeCallSucceeded,
      confirmation: true),
  // ── Web ──
  _ToolSpec('search', 'Run a web search in the browser.', ToolCategory.web,
      schema: {'query': 'string', 'engine': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('open_url', 'Open a URL in the browser.', ToolCategory.web,
      schema: {'url': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('get_page_content', 'Read readable content from the current page.', ToolCategory.web,
      verification: ToolVerificationStrategy.captureSucceeded),
  _ToolSpec('navigate_back', 'Navigate back in the browser.', ToolCategory.web,
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  // ── Communication ──
  _ToolSpec('make_call', 'Place a phone call for a contact name or raw number.',
      ToolCategory.communication,
      schema: {'contact_name': 'string', 'phone_number': 'string'},
      permissions: ['CALL_PHONE'],
      verification: ToolVerificationStrategy.nativeCallSucceeded,
      confirmation: true),
  _ToolSpec('send_sms', 'Send an SMS to a contact or raw number.', ToolCategory.communication,
      schema: {'contact_name': 'string', 'phone_number': 'string', 'message': 'string'},
      permissions: ['SEND_SMS'],
      verification: ToolVerificationStrategy.nativeCallSucceeded,
      confirmation: true),
  _ToolSpec('send_email', 'Compose/send an email via the system handler.',
      ToolCategory.communication,
      schema: {'to': 'string', 'subject': 'string', 'body': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded,
      confirmation: true),
  _ToolSpec('search_contact', 'Look up a contact by name or number.', ToolCategory.communication,
      schema: {'query': 'string'},
      permissions: ['READ_CONTACTS'],
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  // ── Files ──
  _ToolSpec('read_file', 'Read a text file.', ToolCategory.files,
      schema: {'path': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('write_file', 'Write a text file (may overwrite existing content).',
      ToolCategory.files,
      schema: {'path': 'string', 'content': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded,
      confirmation: true),
  _ToolSpec('list_directory', 'List a directory.', ToolCategory.files,
      schema: {'path': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('create_directory', 'Create a directory.', ToolCategory.files,
      schema: {'path': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('copy_file', 'Copy a file.', ToolCategory.files,
      schema: {'source': 'string', 'destination': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  _ToolSpec('move_file', 'Move a file (may overwrite the destination).', ToolCategory.files,
      schema: {'source': 'string', 'destination': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded,
      confirmation: true),
  _ToolSpec('delete_file', 'Delete a file.', ToolCategory.files,
      schema: {'path': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded,
      confirmation: true),
  _ToolSpec('search_files', 'Search files in a directory.', ToolCategory.files,
      schema: {'directory': 'string', 'query': 'string'},
      verification: ToolVerificationStrategy.nativeCallSucceeded),
  // ── Task / conversation ──
  _ToolSpec('execute_task',
      'Run a multi-step device task through the planner/executor (fast path, skill replay, or LLM-guided loop).',
      ToolCategory.task,
      schema: {'goal': 'string'},
      permissions: ['AccessibilityService enabled'],
      verification: ToolVerificationStrategy.planStepVerification,
      cancellable: true),
  _ToolSpec('general_query',
      'Conversational reply carried in the action response; tool calls with an empty response report failure honestly.',
      ToolCategory.conversation,
      verification: ToolVerificationStrategy.none),
];

