import 'dart:async';

import '../../models/agent_action.dart';
import '../../models/chat_message.dart';
import '../../models/task_plan.dart';
import '../../services/action_handler.dart';
import '../../services/ai_service.dart';
import '../../services/chat_history_service.dart';
import '../../services/screen_automation_service.dart';
import '../../services/user_memory_service.dart';
import 'screen_observation.dart';
import 'tool.dart';

/// Result of one agent task run.
///
/// [success] and [verified] currently share one source of truth: the
/// executor's verified-completion flag (`TaskExecutor.lastTaskCompleted`,
/// surfaced through `AgentActionResult.success`). They are kept as separate
/// fields so a future runtime can report "the action ran" and "the outcome
/// was machine-verified" independently without changing callers.
class AgentRunResult {
  final bool success;
  final bool verified;

  /// Honest human-readable outcome exactly as the existing executor
  /// reported it — partial completions stay partial here.
  final String summary;

  final int durationMs;

  const AgentRunResult({
    required this.success,
    required this.verified,
    required this.summary,
    required this.durationMs,
  });
}

/// Optional UI hooks observed while a task runs. The signatures match the
/// existing [ActionHandler.execute] parameters exactly so the adapter is a
/// pure delegation with no behavioral change.
class AgentRunHooks {
  final void Function(String message)? onProgress;
  final Future<bool> Function(TaskPlan plan)? onPlanPreview;
  final Future<bool> Function(PlanStep step)? onBeforePlanStep;

  const AgentRunHooks({
    this.onProgress,
    this.onPlanPreview,
    this.onBeforePlanStep,
  });
}

/// Coarse task state machine for the runtime surface. Values map onto what
/// the existing executor already reports; `planning` is reserved for a
/// planning-stage progress message (the planner currently reports through
/// the generic executing flow).
enum AgentTaskState {
  idle,
  understanding,
  planning,
  executing,
  verifying,
  recovering,
  success,
  failed,
  cancelled,
}

/// Real runtime events. Only emitted at points the runtime genuinely
/// observes — never synthesized from wishes.
enum AgentEventType {
  taskStarted,
  progress,
  toolStarted,
  toolCompleted,
  toolFailed,
  taskCompleted,
  cancelled,

  /// Emitted when a confirmation-required tool asks for approval.
  approvalRequired,

  /// Emitted when approval was denied (or the bounded approval window
  /// expired); the tool did NOT run.
  approvalDenied,

  /// Emitted when a run exceeded its bounded lifetime; downstream
  /// cancellation has been requested.
  runTimeout,
}

/// One observable runtime event for UI surfaces (chat, orb, overlay).
class AgentEvent {
  final DateTime timestamp;
  final String taskId;
  final AgentEventType type;
  final AgentTaskState state;
  final String message;

  const AgentEvent({
    required this.timestamp,
    required this.taskId,
    required this.type,
    required this.state,
    required this.message,
  });

  @override
  String toString() =>
      'AgentEvent($type, $state, $taskId): $message';
}

/// Read-only view of a stored chat session (session access boundary).
class AgentSessionSnapshot {
  final String sessionId;
  final String title;
  final DateTime timestamp;
  final List<Map<String, dynamic>> messages;

  const AgentSessionSnapshot({
    required this.sessionId,
    required this.title,
    required this.timestamp,
    required this.messages,
  });
}

/// One call inside a batch execution request (Phase 9).
class ToolCall {
  final String toolId;
  final Map<String, dynamic> arguments;

  const ToolCall({required this.toolId, this.arguments = const {}});
}

/// Stable UI → agent boundary.
///
/// The UI must not construct or drive `TaskExecutor`/`PlanExecutor` directly
/// through this interface; implementations adapt to the existing execution
/// components so there is exactly one executor per task, wired exactly as
/// the app wires it today.
abstract interface class AgentRuntime {
  /// True while a task is running. Implementations must reject concurrent
  /// [runTask] calls instead of interleaving executor state.
  bool get isBusy;

  /// Runs one user goal through the full existing execution path
  /// (fast path → skill replay → planner/reactive loop, with bounded
  /// retries, recovery, and verification). Step-level timeouts and retry
  /// bounds live inside the executor/plan layer and are not duplicated here.
  Future<AgentRunResult> runTask(String goal, {AgentRunHooks hooks});

  /// Requests cancellation of the running task. Safe to call when idle. A
  /// [taskId] that does not match the current run is ignored instead of
  /// cancelling the wrong work.
  void cancelTask([String? taskId]);

  /// Broadcast progress messages emitted by the running task.
  Stream<String> get progress;

  /// Typed runtime events (start/progress/tool/completion) for UI surfaces.
  Stream<AgentEvent> get events;

  /// Current task state of this runtime.
  AgentTaskState get taskState;

  /// Id of the currently running task, or null when idle.
  String? get activeTaskId;

  /// Executes one registered capability through the typed tool registry —
  /// the ONLY sanctioned path for calling Cypher capabilities; callers
  /// never touch Android services directly.
  Future<ToolExecutionResult> executeTool(
    String toolId,
    Map<String, dynamic> arguments,
  );

  /// Loads a stored session snapshot by id, or null when not found.
  Future<AgentSessionSnapshot?> getSession(String sessionId);

  /// Persists a user fact to long-term memory. Returns false when memory is
  /// unavailable — never a silent fake success.
  Future<bool> saveMemory(String fact);

  /// Bounded observation of the current screen (accessibility-first; a
  /// screenshot only when allowed AND the tree is insufficient). Null when
  /// no screen automation bridge is wired.
  Future<ScreenObservation?> observeScreen({bool allowScreenshot = false});

  /// Dependency-aware batch execution: groups run strictly in sequence;
  /// read-only members of a group may run concurrently (bounded), while any
  /// mutating/exclusive call serializes its whole group. Results keep input
  /// order; failures stay per-call and never promote the batch to success.
  Future<List<ToolExecutionResult>> executeToolGroups(
    List<List<ToolCall>> groups,
  );
}

/// Adapter that reuses the app's existing execution seam exactly as the UI
/// uses it today: `ActionHandler.execute` with `action: 'execute_task'`,
/// which constructs and owns the `TaskExecutor` internally, and
/// `ActionHandler.cancelTask` for cancellation. No executor is created here,
/// so runtime wiring cannot drift from the existing behavior.
class CypherAgentRuntime implements AgentRuntime {
  final ActionHandler _actionHandler;
  final AiService _aiService;
  final ToolRegistry _tools;
  final UserMemoryService? _memory;
  final ScreenAutomationService? _screenAutomation;
  ScreenObserver? _screenObserver;
  final StreamController<String> _progress =
      StreamController<String>.broadcast();
  final StreamController<AgentEvent> _events =
      StreamController<AgentEvent>.broadcast();
  AgentTaskState _state = AgentTaskState.idle;
  String? _currentTaskId;
  bool _busy = false;
  bool _cancelRequested = false;

  /// Bounded parallelism for read-only tool batches (Phase 9).
  static const int _maxParallelReads = 3;

  /// Maximum wall-clock lifetime of one run. Required because the reactive
  /// loop can run up to 999 steps when the user disables the step cap, so
  /// the runtime — not a user setting — guarantees a bounded lifetime.
  final Duration runTimeout;

  /// Approver for confirmation-required tools. Null = default-deny, so the
  /// approval gate is enforced by the execution layer, not by UI convention.
  final Future<bool> Function(String toolId, String reason)? onApproval;

  CypherAgentRuntime({
    required ActionHandler actionHandler,
    required AiService aiService,
    ToolRegistry? tools,
    UserMemoryService? memory,
    ScreenAutomationService? screenAutomation,
    this.runTimeout = const Duration(minutes: 5),
    this.onApproval,
  }) : _actionHandler = actionHandler,
       _aiService = aiService,
       _tools = tools ?? ToolRegistry.withActionHandlerDefaults(actionHandler),
       _memory = memory,
       _screenAutomation = screenAutomation;

  @override
  bool get isBusy => _busy;

  @override
  String? get activeTaskId => _currentTaskId;

  @override
  Stream<String> get progress => _progress.stream;

  @override
  Stream<AgentEvent> get events => _events.stream;

  @override
  AgentTaskState get taskState => _state;

  void _emit(AgentEventType type, String message) {
    if (_events.isClosed) return;
    _events.add(
      AgentEvent(
        timestamp: DateTime.now(),
        taskId: _currentTaskId ?? '-',
        type: type,
        state: _state,
        message: message,
      ),
    );
  }

  /// Maps executor progress messages onto task states. The matched prefixes
  /// are the exact strings the existing TaskExecutor/PlanExecutor emit, so
  /// classification is grounded in real output; anything else maps to
  /// [AgentTaskState.executing].
  static AgentTaskState _classifyState(String message) {
    final lower = message.toLowerCase();
    if (lower.startsWith('starting task:')) {
      return AgentTaskState.understanding;
    }
    if (lower.contains('recovery applied') || lower.contains('retrying')) {
      return AgentTaskState.recovering;
    }
    if (lower.contains('verified') || lower.contains('could not be verified')) {
      return AgentTaskState.verifying;
    }
    if (lower.contains('fast path matched') ||
        lower.contains('found saved skill')) {
      return AgentTaskState.executing;
    }
    return AgentTaskState.executing;
  }

  @override
  Future<AgentRunResult> runTask(
    String goal, {
    AgentRunHooks hooks = const AgentRunHooks(),
  }) async {
    if (_busy) {
      return const AgentRunResult(
        success: false,
        verified: false,
        summary: 'A task is already running.',
        durationMs: 0,
      );
    }
    _busy = true;
    _cancelRequested = false;
    _currentTaskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    _state = AgentTaskState.understanding;
    _emit(AgentEventType.taskStarted, 'Task started: $goal');
    final watch = Stopwatch()..start();
    var timedOut = false;
    try {
      AgentActionResult? result;
      try {
        result = await _actionHandler
            .execute(
              AgentAction(
                action: 'execute_task',
                params: {'goal': goal},
                response: '',
              ),
              aiService: _aiService,
              onProgress: (message) {
                _state = _classifyState(message);
                hooks.onProgress?.call(message);
                if (!_progress.isClosed) _progress.add(message);
                _emit(AgentEventType.progress, message);
              },
              onBeforePlanStep: hooks.onBeforePlanStep,
              onPlanPreview: hooks.onPlanPreview,
            )
            .timeout(runTimeout, onTimeout: () {
          // Bounded run lifetime: stop scheduling further work at the
          // executor's next cancellation checkpoint. An in-flight Android
          // operation may be uninterruptible and is never claimed cancelled.
          timedOut = true;
          _actionHandler.cancelTask();
          throw TimeoutException(
              'Run exceeded its ${runTimeout.inSeconds}s budget.');
        });
      } on TimeoutException {
        // Handled through [timedOut] below.
      }
      if (timedOut || result == null) {
        _state = AgentTaskState.failed;
        _emit(
          AgentEventType.runTimeout,
          'Run exceeded its ${runTimeout.inSeconds}s budget; '
          'cancellation was requested downstream.',
        );
        return AgentRunResult(
          success: false,
          verified: false,
          summary:
              'Task timed out after ${runTimeout.inSeconds}s and was stopped.',
          durationMs: watch.elapsedMilliseconds,
        );
      }
      final cancelled = _cancelRequested && !result.success;
      _state = cancelled
          ? AgentTaskState.cancelled
          : (result.success
              ? AgentTaskState.success
              : AgentTaskState.failed);
      _emit(
        AgentEventType.taskCompleted,
        result.details ??
            (result.success ? 'Task completed.' : 'Task failed.'),
      );
      return AgentRunResult(
        success: result.success,
        verified: result.success,
        summary:
            result.details ??
            (result.success ? 'Task completed.' : 'Task failed.'),
        durationMs: watch.elapsedMilliseconds,
      );
    } finally {
      _busy = false;
      _currentTaskId = null;
      _state = AgentTaskState.idle;
    }
  }

  @override
  void cancelTask([String? taskId]) {
    if (taskId != null &&
        _currentTaskId != null &&
        taskId != _currentTaskId) {
      return; // stale handle; never cancel the wrong run
    }
    _cancelRequested = true;
    _actionHandler.cancelTask();
    if (_currentTaskId != null) {
      _state = AgentTaskState.cancelled;
      _emit(
        AgentEventType.cancelled,
        'Cancellation requested for $_currentTaskId.',
      );
    }
  }

  @override
  Future<ToolExecutionResult> executeTool(
    String toolId,
    Map<String, dynamic> arguments,
  ) async {
    final tool = _tools.lookup(toolId);
    if (tool == null) {
      return const ToolExecutionResult(
        success: false,
        detail: 'Unknown tool.',
        failureType: ToolFailureType.unsupported,
        durationMs: 0,
      );
    }
    if (_busy && toolId == 'execute_task') {
      // Two executors would corrupt the handler's single current-task slot.
      return const ToolExecutionResult(
        success: false,
        detail: 'A task is already running; execute_task must go through '
            'runTask.',
        failureType: ToolFailureType.invalidArguments,
        durationMs: 0,
      );
    }
    // Approval gate (execution-layer enforced): confirmation-required tools
    // must be explicitly approved. No approver configured = default-deny, so
    // gating never depends on UI convention.
    if (tool.requiresConfirmation) {
      _emit(AgentEventType.approvalRequired, 'Approval required: $toolId');
      final approver = onApproval;
      final granted = approver != null &&
          await approver(toolId, tool.description).timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );
      if (!granted) {
        _emit(AgentEventType.approvalDenied, 'Approval denied: $toolId');
        return ToolExecutionResult(
          success: false,
          detail: 'Approval denied for "$toolId".',
          failureType: ToolFailureType.approvalDenied,
          durationMs: 0,
        );
      }
    }
    _emit(AgentEventType.toolStarted, 'Tool started: $toolId');
    final result = await tool.execute(
      ToolInvocation(params: arguments, aiService: _aiService),
    );
    _emit(
      result.success ? AgentEventType.toolCompleted : AgentEventType.toolFailed,
      'Tool ${result.success ? 'completed' : 'failed'}: $toolId — '
          '${result.detail}',
    );
    return result;
  }

  @override
  Future<AgentSessionSnapshot?> getSession(String sessionId) async {
    try {
      final sessions = await ChatHistoryService.loadSessions();
      for (final session in sessions) {
        if (session.id == sessionId) {
          return AgentSessionSnapshot(
            sessionId: session.id,
            title: session.title,
            timestamp: session.timestamp,
            messages: session.messages,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> saveMemory(String fact) async {
    final memory = _memory;
    if (memory == null) return false;
    try {
      await memory.rememberFact(fact);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Closes the broadcast streams. The runtime cannot be restarted after
  /// this; create a new instance instead.
  void dispose() {
    if (!_progress.isClosed) _progress.close();
    if (!_events.isClosed) _events.close();
  }
}
