import 'dart:async';
import 'dart:developer' as developer;

import '../models/task_plan.dart';
import 'ai_service.dart';
import 'app_launcher_service.dart';
import 'recovery_engine.dart';
import 'screen_automation_service.dart';
import 'shizuku_service.dart';
import 'system_control_service.dart';
import 'verification_service.dart';

enum StepStatus { pending, running, verified, failed, skipped, blocked, cancelled }

/// Outcome of one executed plan step.
class StepResult {
  final PlanStep step;
  final StepStatus status;
  final String detail;

  /// Previous device value (volume/brightness) captured before a reversible
  /// step ran, offered back to the user as an optional restore.
  final num? previousValue;

  /// Wall-clock cost of this step including retries and verification (ms).
  final int durationMs;

  const StepResult({
    required this.step,
    required this.status,
    required this.detail,
    this.previousValue,
    this.durationMs = 0,
  });
}

/// Overall outcome of executing a [TaskPlan]. Partial completion is
/// first-class: steps 1-2 may be verified while step 3 failed and 4+ were
/// skipped — that exact state is what gets reported to the user.
class PlanExecutionResult {
  final TaskPlan plan;
  final List<StepResult> stepResults;
  final bool cancelledByUser;
  final int modelCalls;
  final Duration totalDuration;
  final List<String> stateFingerprints;

  const PlanExecutionResult({
    required this.plan,
    required this.stepResults,
    required this.cancelledByUser,
    required this.modelCalls,
    required this.totalDuration,
    required this.stateFingerprints,
  });

  bool get allVerified =>
      !cancelledByUser &&
      stepResults.isNotEmpty &&
      stepResults.every((r) => r.status == StepStatus.verified);

  bool get anyVerified => stepResults.any((r) => r.status == StepStatus.verified);

  /// Honest human-readable summary: exactly which steps verified, failed,
  /// blocked, or were skipped.
  String summarize() {
    if (stepResults.isEmpty) {
      return 'The task could not start: no plan steps were executable.';
    }
    final lines = <String>[];
    for (final result in stepResults) {
      final icon = switch (result.status) {
        StepStatus.verified => '✅',
        StepStatus.failed => '❌',
        StepStatus.blocked => '⛔',
        StepStatus.skipped => '⏭️',
        StepStatus.cancelled => '🛑',
        _ => '•',
      };
      lines.add('$icon ${result.step.intent} — ${result.detail}');
    }
    if (cancelledByUser) {
      lines.add('Task stopped by user.');
    } else if (allVerified) {
      lines.add('All ${stepResults.length} steps completed and verified.');
    } else {
      final verified = stepResults.where((r) => r.status == StepStatus.verified).length;
      final failed = stepResults.where((r) => r.status == StepStatus.failed).length;
      final blocked = stepResults.where((r) => r.status == StepStatus.blocked).length;
      lines.add(
          '$verified of ${stepResults.length} steps completed'
          '${failed > 0 ? ', $failed failed' : ''}'
          '${blocked > 0 ? ', $blocked blocked' : ''}.');
    }
    return lines.join('\n');
  }

  /// Restore hints for reversible settings that actually changed.
  List<String> restoreHints() {
    final hints = <String>[];
    for (final result in stepResults) {
      if (result.status == StepStatus.verified &&
          result.previousValue != null &&
          (result.step.action == 'set_volume' ||
              result.step.action == 'set_brightness')) {
        hints.add(
            'Previous ${result.step.action == 'set_volume' ? 'volume' : 'brightness'} '
            'was ${result.previousValue!.round()}%.');
      }
    }
    return hints;
  }
}

/// Executes a validated [TaskPlan] step by step with dependency gating,
/// bounded condition waits, per-step verification, bounded recovery, and
/// unchanged-screen/oscillation detection.
class PlanExecutor {
  final AiService aiService;
  final ScreenAutomationService screenService;
  final AppLauncherService appLauncher;
  final ShizukuService shizukuService;
  final VerificationService verification;
  final SystemControlService systemControl;
  final RecoveryEngine recoveryEngine = RecoveryEngine();

  /// Called before each step runs; returning false cancels remaining steps.
  /// Used by the UI for plan preview approval and sensitive-step prompts.
  final Future<bool> Function(PlanStep step)? onBeforeStep;

  /// Called once with the full plan before any step executes; returning
  /// false cancels the whole run. Used by the UI for plan preview.
  final Future<bool> Function(TaskPlan plan)? onPlanPreview;

  /// Progress callback for UI/overlay.
  final void Function(String message)? onProgress;

  /// Set from outside to cancel between steps, before retries, and before
  /// irreversible actions.
  bool cancelled = false;

  /// Rolling window of recent screen fingerprints for stall detection.
  final List<String> _recentFingerprints = [];
  static const int _fingerprintWindow = 4;

  PlanExecutor({
    required this.aiService,
    required this.screenService,
    required this.appLauncher,
    required this.shizukuService,
    required this.verification,
    required this.systemControl,
    this.onBeforeStep,
    this.onPlanPreview,
    this.onProgress,
  });

  void cancel() => cancelled = true;

  Future<PlanExecutionResult> execute(TaskPlan plan) async {
    final stopwatch = Stopwatch()..start();
    final results = <StepResult>[];
    final orderedSteps = plan.orderedSteps;
    final statusById = <String, StepStatus>{};
    var modelCalls = 0;

    void report(String message) {
      developer.log(message, name: 'AgentCypher.PlanExecutor');
      onProgress?.call(message);
    }

    // Plan preview: show the whole typed plan once for approval before any
    // step touches the device.
    if (onPlanPreview != null && (plan.needsConfirmation || orderedSteps.length >= 3)) {
      report('Waiting for plan approval…');
      final approved = await onPlanPreview!(plan);
      if (!approved || cancelled) {
        return PlanExecutionResult(
          plan: plan,
          stepResults: const [],
          cancelledByUser: true,
          modelCalls: modelCalls,
          totalDuration: stopwatch.elapsed,
          stateFingerprints: const [],
        );
      }
    }

    for (final step in orderedSteps) {
      // Cancellation point: between every step.
      if (cancelled) {
        results.addAll(_markRemaining(step, orderedSteps, results,
            StepStatus.cancelled, 'Cancelled'));
        break;
      }

      // Dependency gating: never run a step whose dependencies did not verify.
      final unmetDependencies = step.dependsOn
          .where((dep) => statusById[dep] != StepStatus.verified)
          .toList();
      if (unmetDependencies.isNotEmpty) {
        final detail =
            'Skipped because ${unmetDependencies.join(", ")} did not complete.';
        report('${step.intent}: $detail');
        results.add(StepResult(
            step: step, status: StepStatus.skipped, detail: detail));
        statusById[step.id] = StepStatus.skipped;
        continue;
      }

      // Sensitive or plan-flagged steps get explicit confirmation right
      // before execution.
      if (step.requiresConfirmation && onBeforeStep != null) {
        final approved = await onBeforeStep!(step);
        if (!approved) {
          results.add(StepResult(
            step: step,
            status: StepStatus.cancelled,
            detail: 'Not approved by user.',
          ));
          statusById[step.id] = StepStatus.cancelled;
          continue;
        }
      }

      results.add(await _executeStep(
        step,
        report,
        () => modelCalls++,
      ));
      statusById[step.id] = results.last.status;
    }

    stopwatch.stop();
    return PlanExecutionResult(
      plan: plan,
      stepResults: results,
      cancelledByUser: cancelled,
      modelCalls: modelCalls,
      totalDuration: stopwatch.elapsed,
      stateFingerprints: List.unmodifiable(_recentFingerprints),
    );
  }

  Future<StepResult> _executeStep(
    PlanStep step,
    void Function(String) report,
    void Function() recordModelCall,
  ) async {
    final stepStopwatch = Stopwatch()..start();
    report('Step "${step.intent}" starting…');
    final attempts = step.retryPolicy.maxAttempts.clamp(1, 4);

    StepResult finish(
      StepStatus status,
      String detail, {
      num? previousValue,
    }) {
      stepStopwatch.stop();
      developer.log(
        'Step "${step.id}" (${step.action}) finished status=${status.name} '
        'in ${stepStopwatch.elapsedMilliseconds}ms',
        name: 'AgentCypher.PlanExecutor',
      );
      return StepResult(
        step: step,
        status: status,
        detail: detail,
        previousValue: previousValue,
        durationMs: stepStopwatch.elapsedMilliseconds,
      );
    }

    // Capture pre-state ONCE; reused across retries so we don't re-dump
    // unless verification needs fresh data anyway.
    ScreenSnapshot? before;
    num? previousDeviceValue;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      if (cancelled) {
        return finish(StepStatus.cancelled, 'Cancelled.');
      }

      try {
        // Context check: wrong-app detection before every app-scoped step.
        if (step.requiredApp.isNotEmpty) {
          final current = await screenService.getCurrentPackage();
          final normalized = step.requiredApp.toLowerCase();
          final inRightApp = current != null &&
              (current.toLowerCase().contains(normalized) ||
                  normalized.contains(_lastSegment(current.toLowerCase())));
          if (!inRightApp) {
            report('Expected ${step.requiredApp}, found ${current ?? "unknown"} '
                '— reopening the correct context.');
            await appLauncher.openApp(step.requiredApp);
            final (ready, snapshot) =
                await verification.waitForCondition(
              (s) => VerificationPackageCheck.matches(s, step.requiredApp),
              timeout: const Duration(seconds: 5),
            );
            before = snapshot;
            if (!ready) {
              return finish(
                StepStatus.blocked,
                'Could not reach ${step.requiredApp} (wrong-app recovery exhausted).',
              );
            }
          }
        }

        before ??= await verification.captureSnapshot();

        // Record previous value for reversible settings before mutating them.
        if ((step.action == 'set_volume' || step.action == 'set_brightness') &&
            attempt == 1) {
          previousDeviceValue = step.action == 'set_volume'
              ? await systemControl.getVolume()
              : await systemControl.getBrightness();
        }

        final executed = await _runAction(step);
        if (!executed.success) {
          final failure = _classifyFailure(executed.detail, before);
          if (_isRetryable(failure) && attempt < attempts && !_wouldRepeatStaleState()) {
            report(
                '"${step.intent}" failed (${failure.name}); retrying safely…');
            await Future<void>.delayed(step.retryPolicy.initialBackoff * attempt);
            continue;
          }
          if (!_isRetryable(failure)) {
            return finish(
              StepStatus.failed,
              '${_failureExplanation(failure)} (${executed.detail})',
            );
          }
          // Fall through to post-checks; verification below decides honestly.
        }

        // Post-action observation & typed verification.
        final verified = await _verifyStep(step, before, expectedContentFallback: executed.detail);
        if (verified) {
          report('Step "${step.intent}" verified.');
          _recordFingerprint(before);
          return finish(
            StepStatus.verified,
            executed.detail.isEmpty ? 'Verified.' : executed.detail,
            previousValue: previousDeviceValue,
          );
        }

        final failure = _classifyFailure(executed.detail, before);
        if (attempt < attempts && _isRetryable(failure)) {
          report('"${step.intent}" could not be verified yet; retrying…');
          await Future<void>.delayed(step.retryPolicy.initialBackoff * attempt);
          continue;
        }

        // Bounded recovery before declaring failure: re-observe / navigate.
        final recovered = await _attemptRecovery(step, report);
        if (recovered) {
          report('Recovery applied; re-verifying "${step.intent}".');
          final reVerified = await _verifyStep(step, before);
          if (reVerified) {
            return finish(
              StepStatus.verified,
              'Verified after recovery.',
              previousValue: previousDeviceValue,
            );
          }
        }

        return finish(StepStatus.failed, _failureExplanation(failure));
      } catch (error) {
        developer.log(
          'Step "${step.id}" threw on attempt $attempt: $error',
          name: 'AgentCypher.PlanExecutor',
        );
        if (attempt >= attempts) {
          return finish(StepStatus.failed, 'Action error: ${error.toString()}');
        }
        await Future<void>.delayed(step.retryPolicy.initialBackoff * attempt);
      }
    }

    return finish(
      StepStatus.failed,
      'Exhausted ${step.retryPolicy.maxAttempts} attempts.',
    );
  }

  Future<_ActionResult> _runAction(PlanStep step) async {
    switch (step.action) {
      case 'open_app':
        final result =
            await appLauncher.openApp((step.params['app_name'] ?? '') as String);
        return _ActionResult(result.startsWith('Opened'), result);

      case 'click_text':
        final text = (step.params['text'] ?? '') as String;
        final ok = await screenService.clickByText(text);
        return _ActionResult(ok, ok ? 'Tapped "$text".' : '"$text" not found.');

      case 'click_at':
        final x = (step.params['x'] as num?)?.toDouble() ?? -1;
        final y = (step.params['y'] as num?)?.toDouble() ?? -1;
        if (x < 0 || y < 0) {
          return _ActionResult(false, 'Invalid coordinates ($x, $y).');
        }
        final ok = await screenService.clickAt(x, y);
        return _ActionResult(ok, ok ? 'Tapped target point.' : 'Tap rejected.');

      case 'type_text':
        final text = (step.params['text'] ?? '') as String;
        final hint = step.params['field_hint'] as String?;
        final ok = await screenService.typeText(text, fieldHint: hint);
        return _ActionResult(ok, ok ? 'Entered text.' : 'No editable field.');

      case 'press_enter':
        final ok = await screenService.pressEnter();
        return _ActionResult(ok, ok ? 'Submitted.' : 'Submit failed.');

      case 'scroll':
        final direction = (step.params['direction'] ?? 'down') as String;
        final ok = await screenService.scroll(direction);
        return _ActionResult(ok, ok ? 'Scrolled $direction.' : 'Scroll failed.');

      case 'swipe':
        final startX = (step.params['startX'] as num?)?.toDouble() ?? 0;
        final startY = (step.params['startY'] as num?)?.toDouble() ?? 0;
        final endX = (step.params['endX'] as num?)?.toDouble() ?? 0;
        final endY = (step.params['endY'] as num?)?.toDouble() ?? 0;
        final ok = await screenService.swipe(startX, startY, endX, endY);
        return _ActionResult(ok, ok ? 'Swiped.' : 'Swipe rejected.');

      case 'press_back':
        final ok = await screenService.pressBack();
        return _ActionResult(ok, ok ? 'Went back.' : 'Back failed.');

      case 'press_home':
        final ok = await screenService.pressHome();
        return _ActionResult(ok, ok ? 'At home.' : 'Home failed.');

      case 'set_volume':
        final level = (step.expectedValue ?? step.params['level'] as num?)?.toInt();
        if (level == null) return _ActionResult(false, 'No volume level given.');
        final result = await systemControl.setVolume(level);
        return _ActionResult(!result.startsWith('Error'), result);

      case 'set_brightness':
        final level =
            (step.expectedValue ?? step.params['level'] as num?)?.toInt();
        if (level == null) return _ActionResult(false, 'No brightness level given.');
        final result = await systemControl.setBrightness(level);
        return _ActionResult(!result.startsWith('Error'), result);

      case 'wait':
        final ms = (step.params['ms'] as num?)?.toInt() ?? 800;
        await Future<void>.delayed(Duration(milliseconds: ms.clamp(100, 3000)));
        return _ActionResult(true, 'Waited briefly.');

      case 'done':
        return _ActionResult(true, '');

      default:
        // Unsupported capability: honest refusal, never fake success.
        return _ActionResult(false, 'Unsupported capability "${step.action}".');
    }
  }

  Future<bool> _verifyStep(
    PlanStep step,
    ScreenSnapshot? before, {
    String expectedContentFallback = '',
  }) async {
    final methodName =
        TaskPlan.verificationMethodName(step.verificationMethod) ?? 'screen_changed';
    return verification.verifyStepResult(
      action: step.action,
      verificationMethod: methodName,
      expectedContent: step.expectedResult.isNotEmpty
          ? step.expectedResult
          : (step.action == 'type_text' ? (step.params['text'] as String?) : null),
      expectedValue: step.expectedValue,
      tolerance: step.tolerance,
      requiredApp: step.requiredApp.isNotEmpty ? step.requiredApp : null,
      params: {...step.params, 'level': step.expectedValue},
      before: before,
    );
  }

  Future<bool> _attemptRecovery(PlanStep step, void Function(String) report) async {
    if (cancelled) return false;
    final snapshot = await verification.captureSnapshot();
    final strategies = await recoveryEngine.diagnoseWithAlternatives(
      step.action,
      snapshot.summary,
      lastAttemptedValue: step.params['text'] as String?,
    );
    strategies.sort((a, b) => a.priority.compareTo(b.priority));
    for (final strategy in strategies.take(2)) {
      if (cancelled) return false;
      try {
        switch (strategy.action) {
          case 'wait':
            await Future<void>.delayed(const Duration(milliseconds: 1200));
            return true;
          case 'press_back':
            await screenService.pressBack();
            return true;
          case 'press_home':
            await screenService.pressHome();
            return true;
          case 'read_screen':
            return true; // Next verification pass re-observes anyway.
          default:
            continue;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  FailureKind _classifyFailure(String detail, ScreenSnapshot? before) {
    final normalized = detail.toLowerCase();
    if (normalized.contains('unsupported')) return FailureKind.unsupportedCapability;
    if (normalized.contains('not found') || normalized.contains('no editable')) {
      return FailureKind.targetNotFound;
    }
    if (normalized.contains('rejected') || normalized.contains('failed')) {
      return FailureKind.actionRejected;
    }
    if (before != null && !before.readable) return FailureKind.staleScreen;
    return FailureKind.timeout;
  }

  static bool _isRetryable(FailureKind kind) {
    switch (kind) {
      case FailureKind.targetNotFound:
      case FailureKind.staleScreen:
      case FailureKind.actionRejected:
      case FailureKind.timeout:
        return true;
      case FailureKind.wrongApp:
      case FailureKind.unsupportedCapability:
        return false;
    }
  }

  static String _failureExplanation(FailureKind kind) {
    switch (kind) {
      case FailureKind.targetNotFound:
        return 'The target was not visible on screen.';
      case FailureKind.wrongApp:
        return 'The phone was showing a different app than expected.';
      case FailureKind.staleScreen:
        return 'The screen could not be read reliably at that moment.';
      case FailureKind.actionRejected:
        return 'The action was rejected by the system or app.';
      case FailureKind.timeout:
        return 'The step timed out before its result could be confirmed.';
      case FailureKind.unsupportedCapability:
        return 'This capability is not supported, so the step cannot be performed.';
    }
  }

  bool _wouldRepeatStaleState() {
    if (_recentFingerprints.length < _fingerprintWindow) return false;
    final recent = _recentFingerprints.sublist(
        _recentFingerprints.length - _fingerprintWindow);
    return recent.toSet().length == 1;
  }

  void _recordFingerprint(ScreenSnapshot? snapshot) {
    if (snapshot == null || !snapshot.readable) return;
    _recentFingerprints.add(snapshot.fingerprint);
    while (_recentFingerprints.length > _fingerprintWindow * 2) {
      _recentFingerprints.removeAt(0);
    }
    // Oscillation guard: same two fingerprints alternating forever.
    final tail = _recentFingerprints.length >= 4
        ? _recentFingerprints.sublist(_recentFingerprints.length - 4)
        : null;
    if (tail != null && tail[0] == tail[2] && tail[1] == tail[3] && tail[0] != tail[1]) {
      developer.log(
        'Oscillation detected: alternating screens without progress.',
        name: 'AgentCypher.PlanExecutor',
      );
      onProgress?.call('Detected repeated screen states without progress.');
    }
  }

  Iterable<StepResult> _markRemaining(
    PlanStep from,
    List<PlanStep> orderedSteps,
    List<StepResult> existing,
    StepStatus status,
    String detail,
  ) sync* {
    final handledIds = existing.map((r) => r.step.id).toSet();
    for (final step in orderedSteps) {
      if (step.id == from.id || handledIds.contains(step.id)) continue;
      yield StepResult(step: step, status: status, detail: detail);
    }
  }

  static String _lastSegment(String package) {
    final parts = package.split('.');
    return parts.isEmpty ? package : parts.last;
  }
}

class VerificationPackageCheck {
  static bool matches(ScreenSnapshot snapshot, String requiredApp) {
    final normalized = requiredApp.trim().toLowerCase();
    if (normalized.isEmpty || !snapshot.readable) return false;
    final package = snapshot.packageName.toLowerCase();
    final segment = package.split('.').last;
    return package.contains(normalized) ||
        normalized.contains(segment) ||
        package.endsWith(normalized.replaceAll(' ', ''));
  }
}

enum FailureKind {
  targetNotFound,
  wrongApp,
  staleScreen,
  actionRejected,
  timeout,
  unsupportedCapability,
}

class _ActionResult {
  final bool success;
  final String detail;
  const _ActionResult(this.success, this.detail);
}
