/// Typed representation of a multi-step task plan.
///
/// A plan is produced by one LLM planning call, then validated strictly
/// BEFORE any step executes. Malformed, ambiguous, out-of-bounds, or
/// unsupported steps are rejected at validation time so execution never
/// has to guess what the model meant.
library;

/// Verification strategies a step can declare. The plan executor picks the
/// machine-verifiable check from this value instead of trusting free text.
enum VerificationMethod {
  /// Foreground package matches [PlanStep.requiredPackage] or app name.
  appForeground,

  /// Post-action screen fingerprint differs from pre-action fingerprint.
  screenChanged,

  /// Expected content words appear in the post-action observation.
  contentVisible,

  /// Typed text is present in the post-action observation.
  textTyped,

  /// Device state (volume/brightness) read-back matches expectedValue
  /// within tolerance.
  deviceState,

  /// No verification possible — the executor must report the step as
  /// blocked/unverified rather than verified.
  none,
}

/// How failures of this step are retried.
class RetryPolicy {
  final int maxAttempts;
  final Duration initialBackoff;

  const RetryPolicy({
    this.maxAttempts = 2,
    this.initialBackoff = const Duration(milliseconds: 300),
  });

  static const RetryPolicy none = RetryPolicy(maxAttempts: 1);

  factory RetryPolicy.fromJson(dynamic raw) {
    if (raw is int) return RetryPolicy(maxAttempts: raw.clamp(1, 4));
    if (raw is Map<String, dynamic>) {
      return RetryPolicy(
        maxAttempts: ((raw['max_attempts'] as num?) ?? 2).toInt().clamp(1, 4),
        initialBackoff: Duration(
          milliseconds: ((raw['backoff_ms'] as num?) ?? 300).toInt(),
        ),
      );
    }
    return const RetryPolicy();
  }
}

/// A single typed step inside a [TaskPlan].
class PlanStep {
  final String id;
  final String intent;
  final String action;
  final Map<String, dynamic> params;

  /// App name or package this step must run in; empty when context-free.
  final String requiredApp;

  /// Human-readable target description used in progress reporting.
  final String targetDescription;

  /// Conditions that must hold BEFORE the step runs (e.g. 'app_foreground',
  /// 'search_field_focused'). Unmet preconditions block the step.
  final List<String> preconditions;

  /// Words that must appear on screen after the step for it to count as
  /// verified when [verificationMethod] is contentVisible/textTyped.
  final String expectedResult;

  final VerificationMethod verificationMethod;

  /// Numeric expectation for deviceState checks (e.g. volume 60).
  final num? expectedValue;

  /// Absolute tolerance for deviceState numeric comparison.
  final num tolerance;

  final bool reversible;
  final bool requiresConfirmation;
  final List<String> dependsOn;
  final RetryPolicy retryPolicy;

  const PlanStep({
    required this.id,
    required this.intent,
    required this.action,
    this.params = const {},
    this.requiredApp = '',
    this.targetDescription = '',
    this.preconditions = const [],
    this.expectedResult = '',
    this.verificationMethod = VerificationMethod.screenChanged,
    this.expectedValue,
    this.tolerance = 5,
    this.reversible = false,
    this.requiresConfirmation = false,
    this.dependsOn = const [],
    this.retryPolicy = const RetryPolicy(),
  });

  PlanStep copyWith({Map<String, dynamic>? params}) => PlanStep(
        id: id,
        intent: intent,
        action: action,
        params: params ?? this.params,
        requiredApp: requiredApp,
        targetDescription: targetDescription,
        preconditions: preconditions,
        expectedResult: expectedResult,
        verificationMethod: verificationMethod,
        expectedValue: expectedValue,
        tolerance: tolerance,
        reversible: reversible,
        requiresConfirmation: requiresConfirmation,
        dependsOn: dependsOn,
        retryPolicy: retryPolicy,
      );
}

/// Result of strict validation. [issues] carries every rejection reason so
/// the planner gets one repair round-trip with actionable feedback.
class PlanValidationResult {
  final TaskPlan? plan;
  final List<String> issues;

  const PlanValidationResult.valid(this.plan)
      : issues = const [],
        assert(plan != null);

  const PlanValidationResult.invalid(this.issues) : plan = null;

  bool get isValid => issues.isEmpty;
}

class TaskPlan {
  final String rootGoal;
  final List<PlanStep> steps;

  const TaskPlan({required this.rootGoal, required this.steps});

  /// Actions the executor can actually perform. Anything else is rejected as
  /// an unsupported capability instead of being attempted and faked.
  static const Set<String> supportedActions = {
    'open_app',
    'click_text',
    'click_at',
    'type_text',
    'press_enter',
    'scroll',
    'swipe',
    'press_back',
    'press_home',
    'set_volume',
    'set_brightness',
    'wait',
    'done',
  };

  static const Map<VerificationMethod, String> _verificationNames = {
    VerificationMethod.appForeground: 'app_foreground',
    VerificationMethod.screenChanged: 'screen_changed',
    VerificationMethod.contentVisible: 'content_visible',
    VerificationMethod.textTyped: 'text_typed',
    VerificationMethod.deviceState: 'device_state',
    VerificationMethod.none: 'none',
  };

  static String? verificationMethodName(VerificationMethod method) =>
      _verificationNames[method];

  /// Parse and validate a raw planner JSON object. Never throws — all
  /// problems are reported as strings so callers can feed them back to the
  /// model for exactly one repair attempt.
  static PlanValidationResult parse(Object? decoded, {required String rootGoal}) {
    if (decoded == null) {
      return const PlanValidationResult.invalid(['Planner returned nothing.']);
    }
    if (decoded is! Map<String, dynamic>) {
      return const PlanValidationResult.invalid(
          ['Planner output was not a JSON object.']);
    }

    final issues = <String>[];
    final rawSteps = decoded['steps'];

    // A planner may legitimately answer with a single-step plan wrapper.
    final List<dynamic> stepList;
    if (rawSteps is List) {
      stepList = rawSteps;
    } else if (decoded['action'] is String) {
      stepList = [decoded];
    } else {
      return const PlanValidationResult.invalid(
          ['Planner output contained no "steps" list.']);
    }

    if (stepList.isEmpty) {
      return const PlanValidationResult.invalid(
          ['Plan contained zero steps.']);
    }
    if (stepList.length > 15) {
      return PlanValidationResult.invalid(
          ['Plan exceeded 15 steps (${stepList.length}).']);
    }

    final parsedSteps = <PlanStep>[];
    final seenIds = <String>{};

    for (var i = 0; i < stepList.length; i++) {
      final raw = stepList[i];
      if (raw is! Map<String, dynamic>) {
        issues.add('Step ${i + 1}: not a JSON object.');
        continue;
      }
      final stepIssues = <String>[];

      final id = (raw['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) {
        stepIssues.add('missing "id"');
      } else if (!seenIds.add(id)) {
        stepIssues.add('duplicate id "$id"');
      }

      final intent = (raw['intent'] as String?)?.trim() ?? '';
      if (intent.isEmpty) stepIssues.add('missing "intent"');

      final action = (raw['action'] as String?)?.trim() ?? '';
      if (!supportedActions.contains(action)) {
        stepIssues.add('unsupported action "$action"');
      }

      var params = raw['params'];
      if (params is! Map<String, dynamic>) {
        params = <String, dynamic>{};
      }

      stepIssues.addAll(
          _validateActionParams(action, params).map((p) => '$p'));

      final verificationRaw =
          (raw['verification_method'] as String?)?.trim() ??
              _defaultVerificationFor(action);
      final verification = _verificationNames.entries
          .where((entry) => entry.value == verificationRaw)
          .map((entry) => entry.key)
          .toList();

      VerificationMethod? verificationMethod;
      if (verification.isEmpty) {
        stepIssues.add(
            'unknown verification_method "$verificationRaw" '
            '(use ${_verificationNames.values.join(", ")})');
      } else {
        verificationMethod = verification.first;
        if ((action == 'click_at' || action == 'swipe') &&
            verificationMethod == VerificationMethod.none) {
          stepIssues.add('${action}_requires an explicit verification_method');
        }
        if (verificationMethod == VerificationMethod.deviceState &&
            !(action == 'set_volume' || action == 'set_brightness')) {
          stepIssues
              .add('device_state verification only applies to volume/brightness');
        }
      }

      num? expectedValue;
      if (verificationMethod == VerificationMethod.deviceState ||
          action == 'set_volume' ||
          action == 'set_brightness') {
        final rawValue = (raw['expected_value'] ?? params['level']) as num?;
        if (rawValue == null) {
          stepIssues.add('missing "expected_value" for $action');
        } else if (rawValue < 0 || rawValue > 100) {
          stepIssues.add(
              '"expected_value" must be within 0-100 (got $rawValue)');
        } else {
          expectedValue = rawValue;
        }
      }

      if (verificationMethod == VerificationMethod.contentVisible &&
          ((raw['expected_result'] as String?) ?? '').trim().isEmpty &&
          expectedValue == null) {
        stepIssues.add(
            'content_visible verification requires non-empty "expected_result"');
      }

      final dependsOnRaw = raw['depends_on'];
      final dependsOn = dependsOnRaw is List
          ? dependsOnRaw.whereType<String>().toList()
          : <String>[];
      if (dependsOn.contains(id)) {
        stepIssues.add('step cannot depend on itself');
      }

      if (stepIssues.isNotEmpty) {
        issues.add('Step ${i + 1}${id.isEmpty ? '' : ' ($id)'}: '
            '${stepIssues.join('; ')}.');
        continue;
      }

      parsedSteps.add(PlanStep(
        id: id,
        intent: intent,
        action: action,
        params: params,
        requiredApp: ((raw['required_app'] as String?) ?? '').trim(),
        targetDescription:
            ((raw['target'] as String?) ?? '').trim(),
        preconditions: (raw['preconditions'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        expectedResult: ((raw['expected_result'] as String?) ?? '').trim(),
        verificationMethod: verificationMethod!,
        expectedValue: expectedValue,
        tolerance: ((raw['tolerance'] as num?) ?? 5).toDouble().clamp(0, 50),
        reversible: raw['reversible'] == true,
        requiresConfirmation: raw['requires_confirmation'] == true ||
            _isSensitiveAction(action, params),
        dependsOn: dependsOn,
        retryPolicy: RetryPolicy.fromJson(raw['retry']),
      ));
    }

    if (parsedSteps.isNotEmpty && issues.isNotEmpty) {
      // Partial parse failure still invalidates the whole plan: executing a
      // subset could skip dependencies we can no longer see.
      return PlanValidationResult.invalid(issues);
    }
    if (parsedSteps.isEmpty && issues.isNotEmpty) {
      return PlanValidationResult.invalid(issues);
    }

    // Dependency graph checks: unknown refs and cycles.
    final ids = parsedSteps.map((s) => s.id).toSet();
    for (final step in parsedSteps) {
      for (final dep in step.dependsOn) {
        if (!ids.contains(dep)) {
          issues.add('Step "${step.id}" depends on unknown step "$dep".');
        }
      }
    }
    if (issues.isNotEmpty) return PlanValidationResult.invalid(issues);

    final orderIssues = _topologicalOrder(parsedSteps);
    if (orderIssues != null) {
      issues.add(orderIssues);
      return PlanValidationResult.invalid(issues);
    }

    return PlanValidationResult.valid(
        TaskPlan(rootGoal: rootGoal, steps: parsedSteps));
  }

  static String? _topologicalOrder(List<PlanStep> steps) {
    final byId = {for (final s in steps) s.id: s};
    final visiting = <String>{};
    final visited = <String>{};

    String? visit(String id) {
      if (visited.contains(id)) return null;
      if (visiting.contains(id)) return 'Dependency cycle involving "$id".';
      visiting.add(id);
      for (final dep in byId[id]?.dependsOn ?? const <String>[]) {
        if (byId.containsKey(dep)) {
          final error = visit(dep);
          if (error != null) return error;
        }
      }
      visiting.remove(id);
      visited.add(id);
      return null;
    }

    for (final step in steps) {
      final error = visit(step.id);
      if (error != null) return error;
    }
    return null;
  }

  /// Steps ordered so dependencies always come first (stable for equal ranks).
  List<PlanStep> get orderedSteps {
    final remaining = [...steps];
    final ordered = <PlanStep>[];
    final completedIds = <String>{};
    while (remaining.isNotEmpty) {
      final readyIndex = remaining
          .indexWhere((s) => s.dependsOn.every(completedIds.contains));
      if (readyIndex == -1) {
        // Should be impossible after validation; fail safe by appending rest.
        ordered.addAll(remaining);
        break;
      }
      final ready = remaining.removeAt(readyIndex);
      ordered.add(ready);
      completedIds.add(ready.id);
    }
    return ordered;
  }

  bool get needsConfirmation =>
      steps.any((step) => step.requiresConfirmation);

  /// Sensitive actions always require explicit confirmation regardless of
  /// what the planner claims.
  static bool _isSensitiveAction(String action, Map<String, dynamic> params) {
    switch (action) {
      case 'open_app':
      case 'click_text':
      case 'click_at':
      case 'type_text':
      case 'press_enter':
        final haystack =
            '${params['text'] ?? ''} ${params['target_description'] ?? ''}'
                .toLowerCase();
        return RegExp(r'\b(send|post|publish|delete|purchase|buy|pay|'
                r'subscribe|share|install|uninstall|logout|sign out)\b')
            .hasMatch(haystack);
      default:
        return false;
    }
  }

  static String _defaultVerificationFor(String action) {
    switch (action) {
      case 'open_app':
        return 'app_foreground';
      case 'type_text':
        return 'text_typed';
      case 'set_volume':
      case 'set_brightness':
        return 'device_state';
      case 'wait':
      case 'done':
        return 'none';
      default:
        return 'screen_changed';
    }
  }

  static List<String> _validateActionParams(
    String action,
    Map<String, dynamic> params,
  ) {
    switch (action) {
      case 'open_app':
        final app = (params['app_name'] as String?)?.trim() ?? '';
        return app.isEmpty ? ['open_app requires "app_name"'] : const [];
      case 'click_text':
      case 'type_text':
        final text = (params['text'] as String?)?.trim() ?? '';
        return text.isEmpty ? ['$action requires "text"'] : const [];
      case 'click_at':
        final x = (params['x'] as num?)?.toDouble() ?? -1;
        final y = (params['y'] as num?)?.toDouble() ?? -1;
        final reason = (params['target_reason'] as String?)?.trim() ?? '';
        final issues = <String>[
          if (x < 0 || y < 0 || x > 4096 || y > 4096)
            'click_at coordinates out of bounds ($x, $y)',
          if (reason.isEmpty) 'click_at requires "target_reason"',
        ];
        return issues;
      case 'swipe':
        final issues = <String>[];
        for (final axis in ['startX', 'startY', 'endX', 'endY']) {
          final value = (params[axis] as num?)?.toDouble() ?? -1;
          if (value < 0 || value > 4096) {
            issues.add('swipe $axis missing or out of bounds ($value)');
          }
        }
        return issues;
      case 'scroll':
        final direction = (params['direction'] as String?)?.toLowerCase();
        return (direction != 'down' && direction != 'up')
            ? ['scroll direction must be down/up']
            : const [];
      case 'set_volume':
      case 'set_brightness':
        final level = (params['level'] as num?) ?? -1;
        return (level < 0 || level > 100)
            ? ['$action level must be within 0-100 (got $level)']
            : const [];
      case 'press_enter':
      case 'press_back':
      case 'press_home':
      case 'wait':
      case 'done':
        return const [];
      default:
        return ['unknown action "$action"'];
    }
  }
}
