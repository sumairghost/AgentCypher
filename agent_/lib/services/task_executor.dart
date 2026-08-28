import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'ai_service.dart';
import 'screen_automation_service.dart';
import 'app_launcher_service.dart';
import 'notification_service.dart';
import 'task_history_logger.dart';
import 'task_telemetry_service.dart';
import 'shizuku_service.dart';
import 'skill_memory_service.dart';
import 'recovery_engine.dart';
import 'system_control_service.dart';
import 'plan_executor.dart';
import 'verification_service.dart';
import '../models/saved_skill.dart';
import '../models/task_plan.dart';
import 'task_fast_path_router.dart';
import '../models/fast_path_route.dart';
import '../models/capability_registry.dart';
import '../config/feature_flags.dart';
import '../services/confirmation_policy.dart';

/// Executes multi-step UI automation tasks using LLM-guided screen reading.
///
/// Flow: User gives high-level goal → LLM reads screen → decides next action →
/// executes → reads screen again → repeats until goal is complete.
class TaskExecutor {
  final AiService _aiService;
  final ScreenAutomationService _screenService;
  final AppLauncherService _appLauncher;
  final ShizukuService _shizukuService;
  final SystemControlService _systemControl = SystemControlService();
  final NotificationService _notificationService = NotificationService();
  final SkillMemoryService _skillMemory = SkillMemoryService();
  final RecoveryEngine _recoveryEngine = RecoveryEngine();
  final VerificationService _verification = VerificationService();

  /// Callback to report progress messages to the UI
  final void Function(String message)? onProgress;

  /// Called before each plan step runs; returning false cancels remaining
  /// steps. Wired from the UI for sensitive-step confirmation.
  final Future<bool> Function(PlanStep step)? onBeforePlanStep;

  /// Called once with the full plan before execution; returning false
  /// cancels the run. Wired from the UI for plan preview approval.
  final Future<bool> Function(TaskPlan plan)? onPlanPreview;

  /// Set to true to cancel the running task
  bool _cancelled = false;
  bool _lastTaskCompleted = false;
  Completer<void>? _cancelCompleter;

  /// Active while a structured plan is executing, so Stop reaches it too.
  PlanExecutor? _activePlanExecutor;

  /// Last observed screen state, reused across steps to avoid re-dumping.
  String _lastScreenFingerprint = '';
  ScreenSnapshot? _lastScreenSnapshot;
  int _lastScreenWidth = 0;
  int _lastScreenHeight = 0;

  /// True only after the final screen has passed goal-aware verification.
  bool get lastTaskCompleted => _lastTaskCompleted;

  /// Per-step latency log (ms) for the most recent task run.
  final List<Map<String, Object>> lastStepLatencies = [];

  TaskExecutor({
    required AiService aiService,
    required ScreenAutomationService screenService,
    required AppLauncherService appLauncher,
    required ShizukuService shizukuService,
    this.onProgress,
    this.onBeforePlanStep,
    this.onPlanPreview,
  }) : _aiService = aiService,
       _screenService = screenService,
       _appLauncher = appLauncher,
       _shizukuService = shizukuService;

  /// Cancel the currently running task — takes effect immediately
  void cancel() {
    _cancelled = true;
    _activePlanExecutor?.cancel();
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
  }

  static const String _taskSystemPrompt = '''
You are a phone automation agent. You are given a TASK and the current SCREEN content.
You must decide what single action to take next to accomplish the task.

Respond with ONLY one JSON object (no markdown, no code fences, no prose before or after):
{
  "action": "action_name",
  "params": {"key": "value"},
  "reasoning": "brief reason",
  "confidence": 0.0,
  "expected_result": "observable result after the action",
  "is_complete": false
}

Available actions:
- click_text: {"text": "exact text to click"} - Click an element by its visible text
- click_at: {"x": 540, "y": 960, "target_reason": "why this coordinate advances the sub-goal"} - Last-resort coordinate click using the current screen dump
- type_text: {"text": "hello", "field_hint": "optional hint"} - Type into the focused/first edit field
- press_enter: {} - Press the Enter/Search key on the keyboard to submit a search/form
- scroll: {"direction": "down"} - Scroll down/up on the current view
- swipe: {"startX": 540, "startY": 2000, "endX": 540, "endY": 500} - Swipe from start to end coordinates (e.g. open app drawer, navigate carousels)
- press_back: {} - Press the back button
- press_home: {} - Press the home button
- open_app: {"app_name": "WhatsApp"} - Open an app
- wait: {} - Wait a moment for content to load
- done: {} - Task is complete

Rules:
- You will receive a TEXT DUMP of the accessibility tree containing exact text strings and bounds.
- ALWAYS use the text dump and current package to decide your next action.
- Every action must reasonably advance the current task and sub-goal.
- For clicks, prefer `click_text`; use `click_at` only when the screen dump provides a target with no text and include `target_reason`.
- Confidence must be between 0 and 1. Do not guess or click a visually prominent unrelated control.
- Automatically execute only confidence >= 0.72. If lower, choose `wait`, `read_screen`, or a different semantic strategy.
- When typing in a search box, you MUST click it first, wait a step, and THEN type.
- After typing a search query, use `press_enter` once. If the screen does not change, click the exact visible suggestion text. Do not repeat the same submit action more than twice.
- Never scroll or swipe more than three times in a row. After three scrolls, choose the best visible result or take a different action instead of continuing to browse indefinitely.
- Set is_complete=true ONLY when the task is fully done.
- If you need to find something by scrolling, scroll and then check the screen again.
- If you need to open an app (like Wikipedia, Spotify, etc.) and you cannot find it after a couple of scrolls, ASSUME it is not installed. Immediately open Chrome or Google to search for the info on the web instead.
- If stuck after 3 attempts, set is_complete=true and explain in reasoning.
- Keep reasoning very brief (1 sentence).
- `expected_result` and the next observation must support the current task goal.
''';

  static const String _planSystemPrompt = '''
You are a phone automation PLANNER. Given a complex TASK, produce a short ordered plan of typed steps. Another executor will run each step with verification — you never execute anything yourself.

Respond with ONLY one JSON object (no markdown, no code fences, no prose):
{
  "steps": [
    {
      "id": "s1",
      "intent": "one-line human-readable description of this step",
      "action": "action_name",
      "params": {"key": "value"},
      "required_app": "app name or empty",
      "target": "what this acts on",
      "expected_result": "words expected visible on screen afterwards (for content_visible/text_typed)",
      "verification_method": "app_foreground|screen_changed|content_visible|text_typed|device_state|none",
      "expected_value": 60,
      "tolerance": 5,
      "reversible": false,
      "requires_confirmation": false,
      "depends_on": [],
      "retry": {"max_attempts": 2}
    }
  ]
}

Available actions:
open_app {"app_name"} | click_text {"text"} | click_at {"x","y","target_reason"} |
type_text {"text","field_hint"} | press_enter {} | scroll {"direction":"down|up"} |
swipe {"startX","startY","endX","endY"} | press_back {} | press_home {} |
set_volume {"level"} | set_brightness {"level"} | wait {} | done {}

Rules:
- 2 to 10 steps. Each id must be unique (s1, s2, ...).
- Order steps so dependencies come first; use depends_on when order matters.
- Prefer semantic actions (click_text) over coordinates. Use click_at only for unlabeled visible controls.
- For set_volume/set_brightness use verification_method device_state with expected_value 0-100.
- For app launches use verification_method app_foreground and set required_app.
- Every mutating step needs a realistic verification_method. If a result genuinely cannot be verified on this phone (e.g. exact video position inside a player), still give your best method but keep intent honest.
- Never invent actions outside the list above.
- Keep intents short; they are shown to the user as the plan preview.
''';

  /// True when the goal looks compound enough that planning beats reacting.
  bool _isCompoundGoal(String goal) {
    final normalized = goal.toLowerCase();
    final separators = RegExp(r'\b(and then|then|after that|afterwards|'
            r'also|finally|and (set|turn|put|make|enter|play|search|open))\b')
        .hasMatch(normalized);
    final actionCount =
        RegExp(r'\b(open|launch|play|search|find|type|click|scroll|swipe|set '
                r'|turn |press|enter|subscribe|send|message|download)\b')
            .allMatches(normalized)
            .length;
    return separators || actionCount >= 3;
  }

  /// Ask the model for a validated structured plan. One repair round-trip on
  /// validation failure; null when no valid plan could be produced.
  Future<TaskPlan?> _generatePlan(String goal) async {
    final prompt = 'TASK: $goal\n\nProduce the plan JSON now.';
    List<String> lastIssues = const [];
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final repairNote = lastIssues.isEmpty
            ? ''
            : '\n\nYour previous plan was rejected:\n${lastIssues.join("\n")}\nFix these problems and respond with the corrected plan JSON only.';
        final response = await _aiService.sendTaskMessage(
          _planSystemPrompt,
          '$prompt$repairNote',
          temperature: 0.1,
        );
        final decoded = jsonDecode(_extractJson(response.content));
        final result = TaskPlan.parse(decoded, rootGoal: goal);
        if (result.isValid) return result.plan;
        lastIssues = result.issues;
      } catch (error) {
        lastIssues = const ['Planner output was not valid JSON.'];
      }
    }
    return null;
  }

  /// Generates a validated plan for a compound goal and executes it through
  /// the typed [PlanExecutor]. Returns the final report string, or null when
  /// no valid plan could be produced (caller falls back to the reactive loop).
  Future<String?> _runPlannedTask(
    String userGoal,
    List<String> results,
  ) async {
    final planWatch = Stopwatch()..start();
    TaskTelemetryService.shared.setTaskContext(
      rootGoal: userGoal,
      stage: 'Planning',
    );
    final plan = await _generatePlan(userGoal);
    if (_cancelled) {
      results.add('Task cancelled by user.');
      _report('Task cancelled.');
      await _notificationService.showTaskCompleteNotification(
        'Task Cancelled',
        'Task was stopped by the user.',
      );
      await _screenService.showToast('Task Cancelled');
      return 'Task cancelled.';
    }
    if (plan == null) {
      developer.log(
        'No valid plan for compound goal; falling back to reactive loop',
        name: 'AgentCypher',
      );
      _report('Using step-by-step mode instead of a full plan.');
      return null;
    }

    _report('Plan ready: ${plan.steps.length} steps.');
    lastStepLatencies.clear();

    final executor = PlanExecutor(
      aiService: _aiService,
      screenService: _screenService,
      appLauncher: _appLauncher,
      shizukuService: _shizukuService,
      verification: _verification,
      systemControl: _systemControl,
      onBeforeStep: onBeforePlanStep,
      onPlanPreview: onPlanPreview,
      onProgress: onProgress,
    );
    _activePlanExecutor = executor;
    PlanExecutionResult executionResult;
    try {
      executionResult = await executor.execute(plan);
    } finally {
      _activePlanExecutor = null;
    }
    planWatch.stop();

    // Per-step latency log for benchmarking.
    for (final r in executionResult.stepResults) {
      lastStepLatencies.add({
        'step': r.step.id,
        'action': r.step.action,
        'status': r.status.name,
        'ms': r.durationMs,
      });
    }
    developer.log(
      'Plan executed: goal_chars=${userGoal.length} '
      'steps=${executionResult.stepResults.length} '
      'model_calls=${executionResult.modelCalls} '
      'total_ms=${planWatch.elapsedMilliseconds}',
      name: 'AgentCypher.Performance',
    );

    final summary = executionResult.summarize();
    results.add(summary);
    _report(summary);

    final restoreHints = executionResult.restoreHints();
    for (final hint in restoreHints) {
      _report(hint);
      results.add(hint);
    }

    if (executionResult.cancelledByUser) {
      await _notificationService.showTaskCompleteNotification(
        'Task Cancelled',
        'Task was stopped by the user.',
      );
      await _screenService.showToast('Task Cancelled');
      await TaskHistoryLogger.logTask(
        userGoal,
        'Cancelled',
        0,
        executionResult.stepResults.length,
        results,
      );
      return 'Task cancelled.';
    }

    if (executionResult.allVerified) {
      _lastTaskCompleted = true;
      await _skillMemory.saveSkill(
        userGoal,
        executionResult.stepResults
            .map(
              (r) => ActionStep(action: r.step.action, params: r.step.params),
            )
            .toList(),
      );
      await _notificationService.showTaskCompleteNotification(
        'Task Completed',
        'All ${plan.steps.length} steps verified.',
      );
      await _screenService.showToast('Task completed');
      TaskTelemetryService.shared.finish(status: 'success');
      return summary;
    }

    // Partial completion is reported honestly — never claimed as success.
    await _notificationService.showTaskCompleteNotification(
      'Task Partially Completed',
      'Some steps could not be verified.',
    );
    await _screenService.showToast('Task finished with unverified steps');
    TaskTelemetryService.shared.finish(status: 'failed');
    return summary;
  }


  /// Extract exactly one JSON object. Prose and truncated output are rejected.
  String _extractJson(String text) {
    var candidate = text.trim();
    if (candidate.startsWith('```')) {
      final match = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$')
          .firstMatch(candidate);
      if (match == null) {
        throw const FormatException('Incomplete JSON code fence');
      }
      candidate = match.group(1)!.trim();
    }
    if (!candidate.startsWith('{')) {
      throw const FormatException('AI response contained prose before JSON');
    }
    final decoded = jsonDecode(candidate);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI response was not one JSON object');
    }
    return candidate;
  }

  /// Execute a multi-step task with LLM guidance
  Future<String> executeTask(String userGoal) async {
    await ScreenAutomationService.logToNative(
      "[TaskExecutor] executeTask() CALLED with goal_chars=${userGoal.length}",
    );
    _cancelled = false;
    _lastTaskCompleted = false;

    await ScreenAutomationService.logToNative(
      "[TaskExecutor] Checking if accessibility service is running...",
    );
    final isRunning = await _screenService.isServiceRunning();
    await ScreenAutomationService.logToNative(
      "[TaskExecutor] Accessibility service isRunning = $isRunning",
    );
    if (!isRunning) {
      await ScreenAutomationService.logToNative(
        "[TaskExecutor] Accessibility service not running, returning early.",
      );
      return 'Accessibility service is not enabled. Go to Settings → Accessibility → Agent Cypher Screen Control and enable it.';
    }

    TaskTelemetryService.shared.start(rootGoal: userGoal);
    TaskTelemetryService.shared.setTaskContext(
      rootGoal: userGoal,
      stage: 'Understanding',
    );
    final results = <String>[];
    results.add('Starting task: $userGoal');
    _report('Starting task: $userGoal');

    // A. Media-post / external-publishing gate: never auto-route through
    // fast path or reactive loop when the capability requires fresh
    // confirmation and the media picker hasn't been confirmed.
    if (CapabilityRegistry.isExternalPublishingIntent(userGoal)) {
      if (!FeatureFlags.mediaPostWorkflowEnabled) {
        results.add('Blocked: media-post workflow disabled by FeatureFlags.');
        _report('Media post blocked: workflow disabled. Confirm in main app.');
        await _notificationService.showTaskCompleteNotification(
          'Media Post Blocked',
          'Workflow disabled; confirm media + caption manually.',
        );
        return 'Media post blocked: workflow disabled (enable via FeatureFlags.mediaPostWorkflowEnabled).';
      }
      // When enabled, require a confirmed MediaReference; never auto-pick.
      results.add('Blocked: external publishing requires MediaPostPlan draft with confirmed media reference.');
      _report('External publishing requires draft + media picker confirmation.');
      await _notificationService.showTaskCompleteNotification(
        'Confirmation Required',
        'Confirm image + caption in main app before posting.',
      );
      return 'Blocked: external publishing requires a confirmed media reference and fresh confirmation (see confirmation_policy).';
    }

    // A. Fast-path: deterministic, no LLM, runs before replay/planner/reactive
    final router = TaskFastPathRouter();
    final fastPath = router.tryRoute(userGoal);
    if (fastPath.matched && fastPath.plan != null) {
      TaskTelemetryService.shared.setTaskContext(
        rootGoal: userGoal,
        stage: 'FastPathRouting',
      );
      TaskTelemetryService.shared.recordRoute('fast_path:${fastPath.routeName}');
      _report('Fast path matched: ${fastPath.routeName}');
      final executor = PlanExecutor(
        aiService: _aiService,
        screenService: _screenService,
        appLauncher: _appLauncher,
        shizukuService: _shizukuService,
        verification: _verification,
        systemControl: _systemControl,
        onBeforeStep: onBeforePlanStep,
        onPlanPreview: null, // safe deterministic plan skips full preview dialog
        onProgress: onProgress,
      );
      final executionResult = await executor.execute(fastPath.plan!);
      final summary = executionResult.summarize();
      results.add('Fast path result: $summary');
      _report('Fast path finished (verified=${executionResult.allVerified}, modelCalls=${executionResult.modelCalls}, duration=${executionResult.totalDuration.inMilliseconds}ms)');
      final status = executionResult.allVerified ? 'success' : 'partial';
      TaskTelemetryService.shared.finish(status: status);
      await TaskHistoryLogger.logTask(
        userGoal,
        executionResult.allVerified ? 'Success' : 'Partial',
        executionResult.modelCalls,
        executionResult.stepResults.length,
        results,
      );
      return executionResult.allVerified ? 'Done.' : summary;
    } else {
      TaskTelemetryService.shared.recordRoute('no_fast_path');
    }

    // B. Existing replay/planner/reactive flow preserved unchanged in behavior
    // Check skill memory first
    final savedSkill = await _skillMemory.findSkill(userGoal);
    if (savedSkill != null && savedSkill.isReliable) {
      _report(
        'Found saved skill! Replaying ${savedSkill.steps.length} steps...',
      );
      final replaySuccess = await _replaySkill(savedSkill, results);
      final replayVerified =
          replaySuccess && await _verification.verifyTaskGoal(userGoal);
      if (replayVerified) {
        results.add('Task complete via skill memory.');
        _report('Task complete (via skill memory).');
        await _notificationService.showTaskCompleteNotification(
          'Task Completed',
          'Agent finished its goal using memory.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Success',
          0,
          savedSkill.steps.length,
          results,
        );
        await _screenService.showToast('Task Complete! (Memory)');
        _lastTaskCompleted = true;
        TaskTelemetryService.shared.finish(status: 'success');
        return 'Done.';
      } else {
        _report('Replay failed or was not verified, falling back to AI...');
        await _skillMemory.recordFailure(savedSkill.id);
      }
    }

    // Smart pre-launch shortcuts: execute common sequences without LLM
    final shortcut = _getNavigationShortcut(userGoal);
    bool shortcutCompleted = false;
    String lastAction = '';
    int sameActionCount = 0;
    int consecutiveFailures = 0;
    String lastFailedAction = '';
    int totalTokens = 0;
    final List<ActionStep> executedSteps = [];

    if (shortcut != null && shortcut.isNotEmpty) {
      results.add('Using navigation shortcut: ${shortcut.length} steps');
      _report('Using navigation shortcut...');
      for (final step in shortcut) {
        if (_cancelled) break;

        bool success = false;
        if (step.action == 'open_app') {
          final appName = step.params['app_name'] as String? ?? '';
          final res = await _appLauncher.openApp(appName);
          success = res.startsWith('Opened');
          if (success) {
            // Condition wait: proceed as soon as the app is foreground.
            final (ready, _) = await _verification.waitForCondition(
              (snapshot) => snapshot.readable,
              timeout: const Duration(seconds: 4),
            );
            if (!ready) {
              success = await _verification.verifyAppOpened(null, appName);
            }
          }
        } else if (step.action == 'click_text') {
          final text = step.params['text'] as String? ?? '';
          success = await _screenService.clickByText(text);
          if (success) {
            // Brief bounded settle instead of a fixed 1.5s sleep.
            await _verification.waitForCondition(
              (snapshot) => snapshot.readable,
              timeout: const Duration(milliseconds: 1200),
              pollInterval: const Duration(milliseconds: 150),
            );
          }
        }

        if (success) {
          executedSteps.add(step);
          lastAction = step.action;
        } else {
          break; // Fall back to AI if shortcut step fails
        }
      }
      shortcutCompleted = executedSteps.length == shortcut.length && !_cancelled;
    } else {
      // If no shortcut is used, and we are currently inside the Agent Cypher app,
      // press Home so the AI doesn't see its own chat bubbles and get confused by the task text.
      final currentPkg = await _screenService.getCurrentPackage();
      if (currentPkg == 'com.cypherghost.agentcypher') {
        _report('Moving to background...');
        await _screenService.pressHome();
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    // Compound goals run through a structured, verified plan instead of the
    // reactive loop. Simple goals keep the fast single-action loop below.
    if (!_cancelled && !shortcutCompleted && _isCompoundGoal(userGoal)) {
      final planned = await _runPlannedTask(userGoal, results);
      if (planned != null) return planned;
      // No valid plan could be produced; fall through to the reactive loop
      // so the task still gets an honest attempt.
    }

    if (shortcutCompleted && _isSimpleOpenGoal(userGoal)) {
      final verified = await _verification.verifyTaskGoal(userGoal);
      TaskTelemetryService.shared.recordVerification(
        verified ? 'Shortcut goal verified' : 'Shortcut goal not verified',
      );
      if (verified) {
        _lastTaskCompleted = true;
        TaskTelemetryService.shared.finish(status: 'success');
        await _notificationService.showTaskCompleteNotification(
          'Task Completed',
          'Opened the requested app.',
        );
        return 'Done.';
      }
    }

    for (int step = 0; step < _aiService.maxSteps; step++) {
      // Check for cancellation
      if (_cancelled) {
        results.add('Task cancelled by user.');
        _report('Task cancelled.');
        await _notificationService.showTaskCompleteNotification(
          'Task Cancelled',
          'Task was stopped by the user.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Cancelled',
          totalTokens,
          step,
          results,
        );
        await _screenService.showToast('Task Cancelled');
        return 'Task cancelled.';
      }

      // Performance pass: replace the old unconditional 1-3s sleep with a
      // short condition-based wait — poll until the screen actually changes
      // (or a bounded cap), so fast transitions proceed immediately.
      if (step > 0) {
        TaskTelemetryService.shared.stageStart('screen_settle');
        final beforeFingerprint = _lastScreenFingerprint;
        final (_, settledSnapshot) = await _verification.waitForCondition(
          (snapshot) =>
              !snapshot.readable ||
              beforeFingerprint.isEmpty ||
              snapshot.fingerprint != beforeFingerprint,
          timeout: lastAction == 'open_app'
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2),
          pollInterval: const Duration(milliseconds: 200),
        );
        TaskTelemetryService.shared.stageEnd('screen_settle');
        _lastScreenSnapshot = settledSnapshot;
      }

      // 1. Read the current screen — reusing the settle-wait observation
      // when it is readable so a full re-dump is not needed.
      TaskTelemetryService.shared.stageStart('screen_observation');
      Map<String, dynamic> screenState;
      final reused = _lastScreenSnapshot;
      if (reused != null && reused.readable && step > 0) {
        screenState = {
          'package': reused.packageName,
          'summary': reused.summary,
          'elements': reused.elements,
          'element_count': reused.elements.length,
          'screen_width': _lastScreenWidth,
          'screen_height': _lastScreenHeight,
          'orientation':
              _lastScreenWidth > _lastScreenHeight ? 'landscape' : 'portrait',
        };
      } else {
        screenState = await _screenService.getCompactScreenState(
          task: userGoal,
        );
      }
      _lastScreenWidth = (screenState['screen_width'] as num?)?.toInt() ?? 0;
      _lastScreenHeight = (screenState['screen_height'] as num?)?.toInt() ?? 0;
      final reusedSnapshot =
          VerificationService.fromScreenState(screenState);
      _lastScreenFingerprint = reusedSnapshot.fingerprint;
      TaskTelemetryService.shared.stageEnd('screen_observation');
      TaskTelemetryService.shared.recordObservation(source: 'accessibility');
      final screenContent =
          screenState['summary'] as String? ??
          (_aiService.useScreenCompression
              ? await _screenService.getCompressedScreenDescription(userGoal)
              : await _screenService.getScreenDescription());
      String? visualImageBase64;
      final summary = screenContent.trim().toLowerCase();
      final rawElements = screenState['elements'];
      final actionableElementCount = rawElements is List
          ? rawElements.where((element) {
              if (element is! Map) return false;
              final label = '${element['text'] ?? ''}${element['contentDescription'] ?? ''}'.trim();
              return label.isNotEmpty &&
                  (element['clickable'] == true || element['editable'] == true || element['scrollable'] == true);
            }).length
          : 0;
      final needsVisualFallback =
          (screenState['element_count'] as int? ?? 0) == 0 ||
          actionableElementCount == 0 ||
          summary.contains('could not read screen');
      if (needsVisualFallback && _aiService.supportsVision) {
        final visual = await _screenService.getVisualObservation();
        final image = visual?['image_base64'] as String?;
        if (image != null && image.isNotEmpty) {
          visualImageBase64 = image;
          TaskTelemetryService.shared.recordObservation(source: 'screenshot');
          _report('Accessibility data was insufficient; using visual fallback.');
        }
      } else if (needsVisualFallback) {
        _report('Screen could not be read and the selected model has no vision capability.');
      }
      developer.log(
        'Screen state collected (step ${step + 1}, package=${screenState['package']}, elements=${screenState['element_count']}, observation=${visualImageBase64 == null ? 'accessibility' : 'hybrid'})',
        name: 'AgentCypher',
      );
      _report('Observing screen state (${screenState['package']})...');

      // Determine previous result string
      final prevResultStr = step > 0 && results.isNotEmpty
          ? '\nPREVIOUS ACTION RESULT: ${results.last}\n'
          : '';

      // Build failure hint if agent is stuck in a loop
      String failureHint = '';
      if (consecutiveFailures >= 3) {
        failureHint =
            '\n\nWARNING: You have failed $consecutiveFailures times in a row with the same approach. You MUST try a completely different action. If open_app failed, try press_home and look for the app icon on the home screen instead. If click_text failed, re-observe and choose a different semantic target. Use click_at only for a visible unlabeled control with valid bounds and target_reason. Do NOT repeat the same failed action.';
      }

      // 2. Build the prompt (system prompt is sent separately via sendTaskMessage)
      final prompt =
          '''TASK: $userGoal

CURRENT SCREEN TEXT DUMP:
$screenContent$prevResultStr$failureHint
SCREEN CONTEXT: package=${screenState['package']}, width=${screenState['screen_width']}, height=${screenState['screen_height']}, orientation=${screenState['orientation']}, observation=${visualImageBase64 == null ? 'accessibility' : 'hybrid'}
Step ${step + 1}/${_aiService.maxSteps}. Look at the text dump and coordinates. What is the next action?''';

      developer.log(
        'AI request prepared (step ${step + 1}, prompt_chars=${prompt.length})',
        name: 'AgentCypher',
      );

      // 3. Get AI response — races against cancel signal so Stop works immediately
      String response;
      try {
        _cancelCompleter = Completer<void>();
        TaskTelemetryService.shared.stageStart('ai_request');
        TaskTelemetryService.shared.recordAiCall(stage: 'task step');
        final aiFuture = _aiService.sendTaskMessage(
          _taskSystemPrompt,
          prompt,
          imageBase64: visualImageBase64,
        );

        // Race: whichever finishes first wins
        final result = await Future.any([
          aiFuture.then((r) => r),
          _cancelCompleter!.future.then((_) => null),
        ]);

        if (result == null || _cancelled) {
          results.add('Task cancelled by user.');
          _report('Task cancelled.');
          await _notificationService.showTaskCompleteNotification(
            'Task Cancelled',
            'Task was stopped by the user.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Cancelled',
            totalTokens,
            step,
            results,
          );
          await _screenService.showToast('Task Cancelled');
          return 'Task cancelled.';
        }

        final aiResponse = result;
        response = aiResponse.content;
        totalTokens += aiResponse.totalTokens;
        TaskTelemetryService.shared.stageEnd('ai_request');

        developer.log(
          'AI response received (step ${step + 1}, chars=${response.length}, tokens=$totalTokens)',
          name: 'AgentCypher',
        );
      } catch (e) {
        if (_cancelled) {
          results.add('Task cancelled by user.');
          _report('Task cancelled.');
          await _notificationService.showTaskCompleteNotification(
            'Task Cancelled',
            'Task was stopped by the user.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Cancelled',
            totalTokens,
            step,
            results,
          );
          await _screenService.showToast('Task Cancelled');
          await Future.delayed(const Duration(seconds: 2));
          return 'Task cancelled.';
        }
        results.add('AI error: $e');
        _report('Error: $e');
        await _notificationService.showTaskCompleteNotification(
          'Task Error',
          'AI encountered an error.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Failed',
          totalTokens,
          step,
          results,
        );
        await _screenService.showToast('AI Error: $e');
        await Future.delayed(const Duration(seconds: 3));
        return 'I could not complete the task because the AI service failed.';
      }

      // Check for cancellation after AI response
      if (_cancelled) {
        results.add('Task cancelled by user.');
        _report('Task cancelled.');
        await _notificationService.showTaskCompleteNotification(
          'Task Cancelled',
          'Task was stopped by the user.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Cancelled',
          totalTokens,
          step,
          results,
        );
        await _screenService.showToast('Task Cancelled');
        await Future.delayed(const Duration(seconds: 2));
        return 'Task cancelled.';
      }

      // 4. Parse the action (with one retry on failure)
      Map<String, dynamic>? actionJson;
      try {
        String jsonStr = _extractJson(response);

        actionJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (firstError) {
        // First attempt failed — retry once
        developer.log(
          'JSON parse failed; retrying (step ${step + 1}, error_type=${firstError.runtimeType})',
          name: 'AgentCypher',
        );
        _report('Retrying step ${step + 1}...\n(Failed to parse: $firstError)');
        // Wait 2 seconds before retrying to prevent rate-limit spam
        await Future.delayed(const Duration(seconds: 2));
        TaskTelemetryService.shared.retry();
        TaskTelemetryService.shared.recordAiCall(stage: 'format retry');
        try {
          final retryResponse = await _aiService.sendTaskMessage(
            _taskSystemPrompt,
            prompt,
            imageBase64: visualImageBase64,
          );
          totalTokens += retryResponse.totalTokens;
          developer.log(
            'Retry response received (step ${step + 1}, chars=${retryResponse.content.length})',
            name: 'AgentCypher',
          );

          String jsonStr = _extractJson(retryResponse.content);
          actionJson = jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (e) {
          results.add('Step ${step + 1}: Error after retry: $e');

          final debugInfo = 'AI formatting error (type=${e.runtimeType}).';
          _report(debugInfo);

          await _notificationService.showTaskCompleteNotification(
            'Task Error',
            'AI formatting error.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Failed',
            totalTokens,
            step,
            results,
          );
          await _screenService.showToast('Agent response format error.');
          await Future.delayed(const Duration(seconds: 3));
          return 'I could not understand the AI response. Please try again.';
        }
      }

      final action = actionJson['action'] as String? ?? 'done';
      final params = actionJson['params'] as Map<String, dynamic>? ?? {};
      final reasoning = actionJson['reasoning'] as String? ?? '';
      final expectedResult = actionJson['expected_result'] as String? ?? '';
      final confidence = (actionJson['confidence'] as num?)?.toDouble();
      final isComplete = actionJson['is_complete'] == true;
      TaskTelemetryService.shared.setTaskContext(
        rootGoal: userGoal,
        subGoal: expectedResult,
        stage: 'Selecting target',
      );
      TaskTelemetryService.shared.setConfidence(confidence);

      const confidenceActions = {
        'click_text',
        'click_at',
        'type_text',
        'scroll',
        'swipe',
        'open_app',
      };
      if (confidenceActions.contains(action) &&
          (confidence == null || confidence < 0.72)) {
        final blocked =
            'Blocked $action because confidence is below the 72% safety threshold.';
        results.add(blocked);
        _report('$blocked Re-observing before another action.');
        TaskTelemetryService.shared.recordVerification('Low confidence: action blocked');
        TaskTelemetryService.shared.recordRecovery('Re-observe after low confidence');
        consecutiveFailures++;
        if (consecutiveFailures >= 3) {
          TaskTelemetryService.shared.finish(status: 'failed');
          return 'I could not safely identify a target with enough confidence.';
        }
        continue;
      }

      if (action == 'click_at') {
        final targetReason = (params['target_reason'] as String? ?? '').trim();
        final width = (screenState['screen_width'] as num?)?.toDouble() ?? 0;
        final height = (screenState['screen_height'] as num?)?.toDouble() ?? 0;
        final x = (params['x'] as num?)?.toDouble() ?? -1;
        final y = (params['y'] as num?)?.toDouble() ?? -1;
        if (targetReason.isEmpty ||
            (width > 0 && height > 0 && (x < 0 || y < 0 || x > width || y > height))) {
          const blocked = 'Blocked coordinate action because its target reason or bounds were invalid.';
          results.add(blocked);
          _report(blocked);
          TaskTelemetryService.shared.recordVerification('Invalid coordinate target');
          continue;
        }
      }

      developer.log(
        'Parsed action=$action confidence=${confidence ?? 'missing'} expected_result=${expectedResult.isEmpty ? 'missing' : 'present'} complete=$isComplete',
        name: 'AgentCypher',
      );

      _report('Step ${step + 1}: $reasoning');
      if (action == 'press_enter' ||
          action == 'type_text' ||
          action == 'click_text') {
        _report('Verifying UI change after action...');
      }

      sameActionCount = action == lastAction ? sameActionCount + 1 : 1;
      final repeatLimit = action == 'press_enter'
          ? 2
          : (action == 'scroll' || action == 'swipe' ? 3 : 1000);
      if (sameActionCount > repeatLimit) {
        final blockedResult =
            'Blocked repeated $action action. Use a different action on the visible screen.';
        results.add(blockedResult);
        _report(blockedResult);
        consecutiveFailures = 3;
        lastFailedAction = action;
        lastAction = action;
        continue;
      }
      lastAction = action; // Track for adaptive delay

      // 5. Execute the action
      bool success = false;
      String actionResult = '';

      switch (action) {
        case 'click_text':
          final text = params['text'] as String? ?? '';
          if (!_containsSemanticText(screenState, text)) {
            actionResult = 'Target "$text" was not present in the current observation';
            break;
          }
          final before = await _verification.captureSnapshot();
          success = await _screenService.clickByText(text);
          if (success) {
            success = await _verification.verifyScreenAction(
              'click_text',
              expectedResult.isEmpty ? null : expectedResult,
              before: before,
            );
          }
          actionResult = success
              ? 'Clicked "$text"'
              : 'Could not find "$text" or verify a screen change';
          break;

        case 'click_at':
          final x = (params['x'] as num?)?.toDouble() ?? 0;
          final y = (params['y'] as num?)?.toDouble() ?? 0;
          final before = await _verification.captureSnapshot();
          success = await _screenService.clickAt(x, y);
          if (success) {
            success = await _verification.verifyScreenAction(
              'click_at',
              expectedResult.isEmpty ? null : expectedResult,
              before: before,
            );
          }
          actionResult = success
              ? 'Clicked at ($x, $y)'
              : 'Click failed or screen did not change';
          break;

        case 'type_text':
          final text = params['text'] as String? ?? '';
          final hint = params['field_hint'] as String?;
          if (!_hasEditableTarget(screenState, hint)) {
            actionResult = 'No suitable editable target was present in the current observation';
            break;
          }
          final before = await _verification.captureSnapshot();
          success = await _screenService.typeText(text, fieldHint: hint);
          if (success) {
            success = await _verification.verifyTextTyped(
              text,
              fieldHint: hint,
              before: before,
            );
          }
          actionResult = success
              ? 'Typed "$text"'
              : 'Could not type text or verify the typed value';
          break;

        case 'press_enter':
          final before = await _verification.captureSnapshot();
          success = await _submitKeyboardAction();
          if (success) {
            success = await _verification.verifyScreenAction(
              'press_enter',
              expectedResult.isEmpty ? null : expectedResult,
              before: before,
            );
          }
          actionResult = success
              ? 'Submitted the focused search/form field'
              : 'Could not submit the focused field or verify the result';
          break;

        case 'swipe':
          final startX = (params['startX'] as num?)?.toDouble() ?? 540;
          final startY = (params['startY'] as num?)?.toDouble() ?? 2000;
          final endX = (params['endX'] as num?)?.toDouble() ?? 540;
          final endY = (params['endY'] as num?)?.toDouble() ?? 500;

          final before = await _verification.captureSnapshot();
          success = await _performSwipe(startX, startY, endX, endY);
          if (success) {
            success = await _verification.verifyScreenAction(
              'swipe',
              expectedResult.isEmpty ? null : expectedResult,
              before: before,
            );
          }
          actionResult = success
              ? 'Swiped from ($startX,$startY) to ($endX,$endY)'
              : 'Swipe failed or screen did not move as expected';
          break;

        case 'scroll':
          final direction = params['direction'] as String? ?? 'down';
          final before = await _verification.captureSnapshot();
          success = await _performScroll(direction);
          if (success) {
            success = await _verification.verifyScreenAction(
              'scroll',
              expectedResult.isEmpty ? null : expectedResult,
              before: before,
            );
          }
          actionResult = success
              ? 'Scrolled $direction'
              : 'Could not scroll $direction or verify a screen change';
          break;

        case 'press_back':
          final before = await _verification.captureSnapshot();
          success = await _screenService.pressBack();
          if (success) {
            success = await _verification.verifyScreenAction(
              'press_back',
              expectedResult.isEmpty ? null : expectedResult,
              before: before,
            );
          }
          actionResult = success
              ? 'Pressed back'
              : 'Could not press back or verify the result';
          break;

        case 'press_home':
          final before = await _verification.captureSnapshot();
          success = await _screenService.pressHome();
          if (success) {
            success = await _verification.verifyScreenAction(
              'press_home',
              expectedResult.isEmpty ? null : expectedResult,
              before: before,
            );
          }
          actionResult = success
              ? 'Pressed home'
              : 'Could not press home or verify the result';
          break;

        case 'open_app':
          final appName = params['app_name'] as String? ?? '';
          actionResult = await _appLauncher.openApp(appName);
          success = actionResult.startsWith('Opened');
          if (success) {
            success = await _verification.verifyAppOpened(null, appName);
          }
          break;

        case 'wait':
          await Future.delayed(const Duration(seconds: 1));
          actionResult = 'Waited';
          success = true;
          break;

        case 'set_volume':
        case 'set_brightness':
          final level = (params['level'] as num?)?.toInt();
          if (level == null || level < 0 || level > 100) {
            actionResult = 'Blocked $action: level must be 0-100.';
            break;
          }
          final setResult = action == 'set_volume'
              ? await _systemControl.setVolume(level)
              : await _systemControl.setBrightness(level);
          success = !setResult.startsWith('Error');
          if (success) {
            // Real read-back verification — a non-throwing call is not
            // treated as success.
            success = await _verification.verifyDeviceState(action, params);
          }
          actionResult = success
              ? '$action set to $level and verified by read-back'
              : 'Could not verify $action reached $level';
          break;

        case 'done':
          TaskTelemetryService.shared.stageStart('verification');
          final goalVerified = await _verification.verifyTaskGoal(userGoal);
          TaskTelemetryService.shared.stageEnd('verification');
          TaskTelemetryService.shared.recordVerification(
            goalVerified ? 'Final goal verified' : 'Final goal not verified',
          );
          if (!goalVerified) {
            const notVerified =
                'The agent reported completion, but the requested outcome was not verified on screen.';
            results.add(notVerified);
            _report('$notVerified Re-observing instead of reporting success.');
            TaskTelemetryService.shared.recordRecovery('Re-observe after unverified completion');
            consecutiveFailures++;
            if (consecutiveFailures >= 3) {
              TaskTelemetryService.shared.finish(status: 'failed');
              return 'I could not verify that the requested task was completed.';
            }
            break;
          }
          results.add('Task complete: $reasoning');
          _report('Task complete: $reasoning');
          await _notificationService.showTaskCompleteNotification(
            'Task Completed',
            reasoning.trim().isEmpty ? 'Agent finished its goal.' : reasoning,
          );
          await _screenService.showToast('Task completed');
          TaskTelemetryService.shared.finish(status: 'success');
          _lastTaskCompleted = true;
          return reasoning.trim().isEmpty ? 'Done.' : reasoning.trim();

        default:
          actionResult = 'Unknown action: $action';
      }

      developer.log(
        'Native execution result: action=$action success=$success',
        name: 'AgentCypher',
      );
      TaskTelemetryService.shared.recordAction(action: action);
      TaskTelemetryService.shared.recordVerification(success ? 'Passed' : 'Failed');

      // Track consecutive failures to detect stuck loops
      if (!success) {
        if (action == lastFailedAction) {
          consecutiveFailures++;
        } else {
          consecutiveFailures = 1;
          lastFailedAction = action;
        }

        // If stuck for 5+ consecutive failures, give up on this task
        if (consecutiveFailures >= 5) {
          results.add(
            'Agent is stuck. Stopping task after $consecutiveFailures consecutive failures.',
          );
          _report('Agent stuck — stopping task.');
          await _notificationService.showTaskCompleteNotification(
            'Task Stuck',
            'Agent could not complete the task after repeated failures.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Failed',
            totalTokens,
            step,
            results,
          );
          TaskTelemetryService.shared.finish(status: 'failed');
          await _screenService.showToast('Agent stuck. Task stopped.');
          await Future.delayed(const Duration(milliseconds: 1200));
          return 'I could not complete the task. Please try again.';
        }

        // Use the existing recovery engine to get multiple recovery strategies.
        TaskTelemetryService.shared.recordRecovery('Diagnosing bounded alternatives');
        final recoveryActions = await _recoveryEngine.diagnoseWithAlternatives(
          action,
          screenContent,
          lastAttemptedValue: action == 'click_text'
              ? params['text'] as String?
              : action == 'type_text'
              ? params['text'] as String?
              : null,
        );

        if (recoveryActions.isNotEmpty) {
          // Try recovery actions in priority order (lowest priority number first)
          recoveryActions.sort((a, b) => a.priority.compareTo(b.priority));

          bool recoverySucceeded = false;
          for (final recovery in recoveryActions.take(2)) {
            // Try first 2 alternatives max
            if (recovery.action == 'give_up') {
              // Don't attempt recovery if engine recommends giving up
              results.add('Recovery: Too many failures. Giving up.');
              _report('Too many failures. Stopping task.');
              consecutiveFailures = 5; // Trigger stop condition
              break;
            }

            _report('Attempting recovery: ${recovery.description}');

            try {
              if (recovery.action == 'wait') {
                final ms = (recovery.params['milliseconds'] as int?) ?? 1000;
                await Future.delayed(Duration(milliseconds: ms));
                recoverySucceeded = true;
              } else if (recovery.action == 'press_back') {
                await _screenService.pressBack();
                recoverySucceeded = true;
              } else if (recovery.action == 'scroll') {
                final dir = recovery.params['direction'] as String? ?? 'down';
                final amount = (recovery.params['amount'] as int?) ?? 3;
                for (int i = 0; i < amount; i++) {
                  await _performScroll(dir);
                  await Future.delayed(const Duration(milliseconds: 400));
                }
                recoverySucceeded = true;
              } else if (recovery.action == 'press_home') {
                await _screenService.pressHome();
                recoverySucceeded = true;
              } else if (recovery.action == 'read_screen') {
                // Just a signal to re-read the screen on next iteration
                recoverySucceeded = true;
              } else if (recovery.action == 'click_text') {
                final text = recovery.params['text'] as String?;
                if (text != null) {
                  await _screenService.clickByText(text);
                  recoverySucceeded = true;
                }
              } else if (recovery.action == 'wait_for_user') {
                results.add(
                  'Recovery: ${recovery.description} Human input is required to continue.',
                );
                _report(
                  'Waiting for human verification on the current screen.',
                );
                recoverySucceeded = true;
                _cancelled = true;
              }

              if (recoverySucceeded) {
                results.add('Recovery: ${recovery.description}');
                break; // Success - don't try more recovery actions
              }
            } catch (e) {
              developer.log(
                'Recovery action ${recovery.action} failed: $e',
                name: 'AgentCypher',
              );
              // Continue to next recovery strategy
            }
          }

          if (!recoverySucceeded) {
            _report('Recovery failed. Retrying task...');
            results.add('Recovery actions exhausted, continuing with task...');
          }
        }
        continue;
      } else {
        consecutiveFailures = 0;
        lastFailedAction = '';
        executedSteps.add(ActionStep(action: action, params: params));
      }

      results.add('Step ${step + 1}: $actionResult ($reasoning)');

      // Provide progress feedback
      if (!isComplete && (step + 1) % 3 == 0) {
        await _screenService.showToast('Working... (Step ${step + 1})');
      }

      if (isComplete) {
        results.add('Task complete.');
        _report('Task complete.');
        await _notificationService.showTaskCompleteNotification(
          'Task Completed',
          'Agent finished its goal.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Success',
          totalTokens,
          step,
          results,
        );

        // Save to skill memory
        await _skillMemory.saveSkill(userGoal, executedSteps);

        TaskTelemetryService.shared.finish(status: 'success');
        // Brief pause so the user can see the toast before jumping back.
        await Future.delayed(const Duration(milliseconds: 1200));
        return reasoning.trim().isEmpty ? 'Done.' : reasoning.trim();
      }
    }

    results.add(
      'Reached maximum steps (${_aiService.maxSteps}). Task may be incomplete.',
    );
    _report('Reached maximum steps.');
    await _notificationService.showTaskCompleteNotification(
      'Task Stopped',
      'Reached maximum steps (${_aiService.maxSteps}).',
    );
    await TaskHistoryLogger.logTask(
      userGoal,
      'Failed',
      totalTokens,
      _aiService.maxSteps,
      results,
    );
    await _screenService.showToast('Reached maximum steps.');
    await Future.delayed(const Duration(milliseconds: 1200));

    return 'I could not complete the task within the allowed steps.';
  }

  bool _containsSemanticText(Map<String, dynamic> screenState, String target) {
    final normalizedTarget = target.trim().toLowerCase();
    if (normalizedTarget.isEmpty) return false;
    final rawElements = screenState['elements'];
    if (rawElements is! List) return false;
    return rawElements.any((raw) {
      if (raw is! Map) return false;
      final text = (raw['text'] ?? '').toString().trim().toLowerCase();
      final description = (raw['contentDescription'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return text == normalizedTarget ||
          description == normalizedTarget ||
          text.contains(normalizedTarget) ||
          description.contains(normalizedTarget);
    });
  }

  bool _hasEditableTarget(Map<String, dynamic> screenState, String? hint) {
    final rawElements = screenState['elements'];
    if (rawElements is! List) return false;
    final normalizedHint = hint?.trim().toLowerCase() ?? '';
    return rawElements.any((raw) {
      if (raw is! Map || raw['editable'] != true) return false;
      if (normalizedHint.isEmpty) return true;
      final text = (raw['text'] ?? '').toString().toLowerCase();
      final description = (raw['contentDescription'] ?? '').toString().toLowerCase();
      return text.contains(normalizedHint) || description.contains(normalizedHint);
    });
  }

  void _report(String message) {
    onProgress?.call(message);
  }

  Future<bool> _submitKeyboardAction() async {
    if (await _screenService.pressEnter()) return true;

    final shizukuAvailable = await _shizukuService.checkAvailability();
    if (!shizukuAvailable) return false;

    final result = await _shizukuService.runCommand('input keyevent 66');
    final normalized = result.toLowerCase();
    return !normalized.contains('not running') &&
        !normalized.contains('permission denied') &&
        !normalized.startsWith('error');
  }

  Future<bool> _performScroll(String direction) async {
    if (await _screenService.scroll(direction)) return true;

    final isDown = direction.toLowerCase() == 'down';
    return _performSwipe(540, isDown ? 1800 : 600, 540, isDown ? 600 : 1800);
  }

  Future<bool> _performSwipe(
    double startX,
    double startY,
    double endX,
    double endY,
  ) async {
    if (await _screenService.swipe(startX, startY, endX, endY)) return true;

    final shizukuAvailable = await _shizukuService.checkAvailability();
    if (!shizukuAvailable) return false;

    final result = await _shizukuService.runCommand(
      'input swipe ${startX.toInt()} ${startY.toInt()} '
      '${endX.toInt()} ${endY.toInt()} 600',
    );
    final normalized = result.toLowerCase();
    return !normalized.contains('not running') &&
        !normalized.contains('permission denied') &&
        !normalized.startsWith('error');
  }

  /// Replays a saved skill without using the LLM
  Future<bool> _replaySkill(SavedSkill skill, List<String> results) async {
    for (int i = 0; i < skill.steps.length; i++) {
      if (_cancelled) return false;

      final step = skill.steps[i];
      _report('Replaying step ${i + 1}/${skill.steps.length}: ${step.action}');

      // Condition-based readiness instead of fixed fixed delay
      if (step.action == 'open_app') {
        final appName = step.params['app_name'] as String? ?? '';
        await _appLauncher.openApp(appName);
        final (ready, _) = await _verification.waitForCondition(
          (s) => s.readable,
          timeout: const Duration(seconds: 4),
          pollInterval: const Duration(milliseconds: 200),
        );
        if (!ready) {
          // Honest failure — do not claim success without evidence
        }
      } else {
        // For click/type/enter: brief bounded condition wait, not fixed 1-3s
        await _verification.waitForCondition(
          (s) => s.readable,
          timeout: const Duration(milliseconds: 1200),
          pollInterval: const Duration(milliseconds: 150),
        );
      }

      bool success = false;
      String actionResult = '';

      switch (step.action) {
        case 'click_text':
          final text = step.params['text'] as String? ?? '';
          final before = await _verification.captureSnapshot();
          success = await _screenService.clickByText(text);
          if (success) {
            success = await _verification.verifyScreenAction(
              'click_text',
              null,
              before: before,
            );
          }
          actionResult = success
              ? 'Clicked "$text"'
              : 'Could not find "$text" or verify a screen change';
          break;
        case 'click_at':
          final x = (step.params['x'] as num?)?.toDouble() ?? 0;
          final y = (step.params['y'] as num?)?.toDouble() ?? 0;
          final before = await _verification.captureSnapshot();
          success = await _screenService.clickAt(x, y);
          if (success) {
            success = await _verification.verifyScreenAction(
              'click_at',
              null,
              before: before,
            );
          }
          actionResult = success
              ? 'Clicked at ($x, $y)'
              : 'Click failed or screen did not change';
          break;
        case 'type_text':
          final text = step.params['text'] as String? ?? '';
          final hint = step.params['field_hint'] as String?;
          final before = await _verification.captureSnapshot();
          success = await _screenService.typeText(text, fieldHint: hint);
          if (success) {
            success = await _verification.verifyTextTyped(
              text,
              fieldHint: hint,
              before: before,
            );
          }
          actionResult = success
              ? 'Typed "$text"'
              : 'Could not type text or verify the typed value';
          break;
        case 'press_enter':
          success = await _submitKeyboardAction();
          actionResult = success
              ? 'Submitted the focused search/form field'
              : 'Could not submit the focused field';
          break;
        case 'swipe':
          final startX = (step.params['startX'] as num?)?.toDouble() ?? 540;
          final startY = (step.params['startY'] as num?)?.toDouble() ?? 2000;
          final endX = (step.params['endX'] as num?)?.toDouble() ?? 540;
          final endY = (step.params['endY'] as num?)?.toDouble() ?? 500;
          success = await _performSwipe(startX, startY, endX, endY);
          actionResult = 'Swiped from ($startX,$startY) to ($endX,$endY)';
          break;
        case 'scroll':
          final direction = step.params['direction'] as String? ?? 'down';
          final before = await _verification.captureSnapshot();
          success = await _performScroll(direction);
          if (success) {
            success = await _verification.verifyScreenAction(
              'scroll',
              null,
              before: before,
            );
          }
          actionResult = success
              ? 'Scrolled $direction'
              : 'Could not scroll $direction or verify a screen change';
          break;
        case 'press_back':
          success = await _screenService.pressBack();
          actionResult = 'Pressed back';
          break;
        case 'press_home':
          success = await _screenService.pressHome();
          actionResult = 'Pressed home';
          break;
        case 'open_app':
          final appName = step.params['app_name'] as String? ?? '';
          actionResult = await _appLauncher.openApp(appName);
          success = actionResult.startsWith('Opened');
          break;
        case 'wait':
          await _verification.waitForCondition(
            (s) => s.readable,
            timeout: const Duration(milliseconds: 800),
            pollInterval: const Duration(milliseconds: 150),
          );
          actionResult = 'Waited (bounded condition)';
          success = true;
          break;
        case 'done':
          success = true;
          actionResult = 'Done step reached';
          break;
        default:
          success = false;
          actionResult = 'Unknown action: ${step.action}';
      }

      results.add('Memory Replay Step ${i + 1}: $actionResult');
      developer.log(
        '=== MEMORY REPLAY RESULT ===\n$actionResult',
        name: 'AgentCypher',
      );

      if (!success) {
        return false; // Break out of replay if a step fails
      }
    }

    return true; // All steps succeeded
  }

  bool _isSimpleOpenGoal(String goal) {
    final normalized = goal
        .toLowerCase()
        .replaceAll(RegExp(r'[.!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return RegExp(
      r'^(open|launch|start)\s+(the\s+)?[a-z0-9][a-z0-9 ]*$',
    ).hasMatch(normalized) &&
        !RegExp(
          r'\b(search|find|send|message|play|subscribe|download|install|set|turn|type|click|scroll|navigate)\b',
        ).hasMatch(normalized);
  }

  /// Returns predefined navigation steps for common tasks
  List<ActionStep>? _getNavigationShortcut(String goal) {
    final lower = goal.toLowerCase();

    if (lower.contains('dark mode') || lower.contains('dark theme')) {
      return [
        ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
        ActionStep(action: 'click_text', params: {'text': 'Display'}),
      ];
    }
    if (lower.contains('wifi') || lower.contains('wi-fi')) {
      return [
        ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
        ActionStep(
          action: 'click_text',
          params: {'text': 'Network & internet'},
        ),
      ];
    }
    if (lower.contains('bluetooth')) {
      return [
        ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
        ActionStep(action: 'click_text', params: {'text': 'Connected devices'}),
      ];
    }

    final appPatterns = <String, List<String>>{
      'Settings': ['settings', 'brightness', 'display', 'notification'],
      'Play Store': [
        'play store',
        'playstore',
        'download',
        'install app',
        'google play',
      ],
      'YouTube': ['youtube'],
      'WhatsApp': ['whatsapp'],
      'Chrome': ['chrome', 'browse', 'search google'],
      'Camera': ['camera', 'take a photo', 'take photo', 'take a picture'],
      'Gallery': ['gallery', 'photos'],
      'Messages': ['message', 'sms', 'text to'],
      'Phone': ['call', 'dial'],
      'Gmail': ['gmail', 'email'],
      'Maps': ['maps', 'navigate to', 'directions'],
      'Clock': ['alarm', 'timer', 'stopwatch'],
      'Calculator': ['calculator', 'calculate', 'calc'],
    };

    final hasFollowUpAction = RegExp(
      r'\b(search|find|send|message|play|subscribe|download|install|set|turn|type|click|scroll|navigate)\b',
    ).hasMatch(lower);
    if (!hasFollowUpAction) {
      for (final entry in appPatterns.entries) {
        for (final keyword in entry.value) {
          if (lower.contains(keyword)) {
            return [
              ActionStep(action: 'open_app', params: {'app_name': entry.key}),
            ];
          }
        }
      }
    }

    // Generic fallback for "open X"
    final openMatch = RegExp(r'^open\s+([a-zA-Z0-9]+)').firstMatch(lower);
    if (openMatch != null) {
      String app = openMatch.group(1)!;
      app = app[0].toUpperCase() + app.substring(1);
      return [
        ActionStep(action: 'open_app', params: {'app_name': app}),
      ];
    }

    return null;
  }
}

