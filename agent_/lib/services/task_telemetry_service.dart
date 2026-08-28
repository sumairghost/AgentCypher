import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Records bounded timing and task-state data without persisting prompts,
/// screenshots, API keys, credentials, or accessibility content.
class TaskTelemetryService {
  static final TaskTelemetryService shared = TaskTelemetryService._();

  TaskTelemetryService._();

  final ValueNotifier<TaskDeveloperSnapshot> developerState =
      ValueNotifier<TaskDeveloperSnapshot>(TaskDeveloperSnapshot.idle());

  DateTime? _startedAt;
  final Map<String, Stopwatch> _stages = <String, Stopwatch>{};
  final Map<String, int> _stageCounts = <String, int>{};
  final Map<String, int> _actionTimings = <String, int>{};
  final List<TaskExecutionEvent> _events = <TaskExecutionEvent>[];
  final List<WorkspaceCommandRecord> _workspaceCommands =
      <WorkspaceCommandRecord>[];
  int _retries = 0;
  int _actionCount = 0;
  int _screenObservations = 0;
  int _aiCalls = 0;
  int _recoveryAttempts = 0;
  int _duplicateActionBlocks = 0;
  int _staleScreenBlocks = 0;
  String _routeSelection = 'none';
  int _observationsReused = 0;
  String _rootGoal = '';
  String _currentSubGoal = '';
  String _executionStage = 'Idle';
  String _verificationResult = 'Not measured';
  double? _confidence;
  bool _isRunning = false;
  String? _lastStatus;
  TaskTelemetrySnapshot? _lastSnapshot;

  // Controlled self-upgrade state (published by ControlledUpgradeService).
  String _upgradeStage = '';
  String _upgradeProblem = '';
  String _upgradeFiles = '';
  String _upgradeReason = '';
  String _upgradeEvidence = '';
  String _upgradeFinalResult = '';
  bool _upgradeCanApply = false;
  UpgradePlanSnapshot? _upgradePlan;
  List<UpgradeHistoryEntry> _upgradeHistory = const <UpgradeHistoryEntry>[];

  TaskTelemetrySnapshot? get lastSnapshot => _lastSnapshot;
  String? get lastStatus => _lastStatus;

  void start({String? rootGoal}) {
    _startedAt = DateTime.now();
    _stages.clear();
    _stageCounts.clear();
    _actionTimings.clear();
    _events.clear();
    _workspaceCommands.clear();
    _retries = 0;
    _actionCount = 0;
    _screenObservations = 0;
    _aiCalls = 0;
    _recoveryAttempts = 0;
    _duplicateActionBlocks = 0;
    _staleScreenBlocks = 0;
    _routeSelection = 'none';
    _observationsReused = 0;
    _rootGoal = (rootGoal ?? '').trim();
    _currentSubGoal = '';
    _executionStage = 'Starting';
    _verificationResult = 'Not measured';
    _confidence = null;
    _isRunning = true;
    _lastStatus = null;
    _publish();
  }

  void setTaskContext({String? rootGoal, String? subGoal, String? stage}) {
    if (rootGoal != null && rootGoal.trim().isNotEmpty) {
      _rootGoal = rootGoal.trim();
    }
    if (subGoal != null) _currentSubGoal = subGoal.trim();
    if (stage != null && stage.trim().isNotEmpty) _executionStage = stage.trim();
    _publish();
  }

  void addEvent(String stage, String detail) {
    final normalizedStage = stage.trim().isEmpty ? 'Event' : stage.trim();
    final normalizedDetail = _sanitizeDetail(detail);
    _events.add(TaskExecutionEvent(
      stage: normalizedStage,
      detail: normalizedDetail,
      timestamp: DateTime.now(),
    ));
    if (_events.length > 80) _events.removeRange(0, _events.length - 80);
    _executionStage = normalizedStage;
    _publish();
  }

  void stageStart(String stage) {
    final normalized = stage.trim().isEmpty ? 'unknown' : stage.trim();
    _stages[normalized] = Stopwatch()..start();
    _stageCounts[normalized] = (_stageCounts[normalized] ?? 0) + 1;
    _executionStage = normalized;
    addEvent(normalized, 'Stage started');
  }

  void stageEnd(String stage) {
    final normalized = stage.trim().isEmpty ? 'unknown' : stage.trim();
    final stopwatch = _stages[normalized];
    if (stopwatch != null && stopwatch.isRunning) {
      stopwatch.stop();
      _actionTimings[normalized] = stopwatch.elapsedMilliseconds;
    }
    _publish();
  }

  void recordAction({String? action, int? elapsedMs}) {
    _actionCount++;
    if (elapsedMs != null && action != null && action.trim().isNotEmpty) {
      _actionTimings[action.trim()] = elapsedMs;
    }
    addEvent('Action', action?.trim().isEmpty == false ? action!.trim() : 'Action executed');
  }

  void recordObservation({String source = 'accessibility'}) {
    _screenObservations++;
    addEvent('Observing', 'Screen observation via ${_safeLabel(source)}');
  }

  void recordAiCall({String? stage}) {
    _aiCalls++;
    addEvent('AI', stage?.trim().isEmpty == false ? stage!.trim() : 'AI request');
  }

  void recordRecovery(String detail) {
    _recoveryAttempts++;
    addEvent('Recovering', detail);
  }

  void recordVerification(String result) {
    _verificationResult = _safeLabel(result);
    addEvent('Verifying', _verificationResult);
  }

  void setConfidence(double? confidence) {
    if (confidence == null || confidence.isNaN || confidence.isInfinite) {
      _confidence = null;
    } else {
      _confidence = confidence.clamp(0.0, 1.0).toDouble();
    }
    _publish();
  }

  void recordRoute(String route) {
    _routeSelection = route.trim();
    addEvent('Route', 'Selected: $_routeSelection');
  }

  void recordDuplicateActionBlock() {
    _duplicateActionBlocks++;
    addEvent('Safety', 'Blocked duplicate submit/action');
  }

  void recordStaleScreenBlock() {
    _staleScreenBlocks++;
    addEvent('Safety', 'Blocked due to unchanged/stale screen');
  }

  void retry() {
    _retries++;
    _publish();
  }

  void recordObservationReused() {
    _observationsReused++;
  }

  void recordWorkspaceCommand({
    required String command,
    required bool succeeded,
    int exitCode = 0,
    int elapsedMs = 0,
    String workingDirectory = '',
  }) {
    _workspaceCommands.add(WorkspaceCommandRecord(
      command: _sanitizeDetail(command),
      succeeded: succeeded,
      exitCode: exitCode,
      elapsedMs: elapsedMs,
      workingDirectory: _sanitizeDetail(workingDirectory),
    ));
    if (_workspaceCommands.length > 40) {
      _workspaceCommands.removeRange(0, _workspaceCommands.length - 40);
    }
    _publish();
  }

  TaskTelemetrySnapshot finish({required String status}) {
    for (final stopwatch in _stages.values) {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    for (final entry in _stages.entries) {
      _actionTimings[entry.key] = entry.value.elapsedMilliseconds;
    }
    final snapshot = TaskTelemetrySnapshot(
      totalMs: _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inMilliseconds,
      stageMs: {
        for (final entry in _stages.entries)
          entry.key: entry.value.elapsedMilliseconds,
      },
      retries: _retries,
      status: status,
      routeSelection: _routeSelection,
      duplicateActionBlocks: _duplicateActionBlocks,
      staleScreenBlocks: _staleScreenBlocks,
      observationsReused: _observationsReused,
    );
    _lastStatus = status;
    _lastSnapshot = snapshot;
    _isRunning = false;
    _executionStage = status == 'success' ? 'Completed' : 'Finished';
    _publish(totalTaskDurationMs: snapshot.totalMs);
    developer.log(snapshot.toSafeLogString(), name: 'AgentCypher.Telemetry');
    return snapshot;
  }

  /// Publishes controlled self-upgrade progress into the developer snapshot.
  ///
  /// The stock [ControlledUpgradeService] is a no-op stub; a real upgrade
  /// workflow would call this to surface IDENTIFY→PROPOSE→APPLY→VALIDATE
  /// state in the Developer Mode panel.
  void publishUpgradeState({
    String upgradeStage = '',
    String upgradeProblem = '',
    String upgradeFiles = '',
    String upgradeReason = '',
    String upgradeEvidence = '',
    String upgradeFinalResult = '',
    bool upgradeCanApply = false,
    UpgradePlanSnapshot? upgradePlan,
    List<UpgradeHistoryEntry> upgradeHistory = const <UpgradeHistoryEntry>[],
  }) {
    _upgradeStage = _sanitizeDetail(upgradeStage);
    _upgradeProblem = _sanitizeDetail(upgradeProblem);
    _upgradeFiles = _sanitizeDetail(upgradeFiles);
    _upgradeReason = _sanitizeDetail(upgradeReason);
    _upgradeEvidence = _sanitizeDetail(upgradeEvidence);
    _upgradeFinalResult = _sanitizeDetail(upgradeFinalResult);
    _upgradeCanApply = upgradeCanApply;
    _upgradePlan = upgradePlan;
    _upgradeHistory = List<UpgradeHistoryEntry>.unmodifiable(upgradeHistory);
    _publish();
  }

  void _publish({int? totalTaskDurationMs}) {
    final duration = totalTaskDurationMs ??
        (_startedAt == null
            ? 0
            : DateTime.now().difference(_startedAt!).inMilliseconds);
    developerState.value = TaskDeveloperSnapshot(
      rootGoal: _rootGoal,
      executionStage: _executionStage,
      currentSubGoal: _currentSubGoal,
      actionCount: _actionCount,
      screenObservations: _screenObservations,
      aiCalls: _aiCalls,
      recoveryAttempts: _recoveryAttempts,
      verificationResult: _verificationResult,
      totalTaskDurationMs: duration,
      confidence: _confidence,
      events: List<TaskExecutionEvent>.unmodifiable(_events),
      workspaceCommands: List<WorkspaceCommandRecord>.unmodifiable(_workspaceCommands),
      actionTimings: Map<String, int>.unmodifiable(_actionTimings),
      isRunning: _isRunning,
      routeSelection: _routeSelection,
      duplicateActionBlocks: _duplicateActionBlocks,
      staleScreenBlocks: _staleScreenBlocks,
      observationsReused: _observationsReused,
      upgradeStage: _upgradeStage,
      upgradeProblem: _upgradeProblem,
      upgradeFiles: _upgradeFiles,
      upgradeReason: _upgradeReason,
      upgradeEvidence: _upgradeEvidence,
      upgradeFinalResult: _upgradeFinalResult,
      upgradeCanApply: _upgradeCanApply,
      upgradePlan: _upgradePlan,
      upgradeHistory: _upgradeHistory,
    );
  }

  static String _sanitizeDetail(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 240) return compact;
    return '${compact.substring(0, 240)}…';
  }

  static String _safeLabel(String value) {
    final normalized = _sanitizeDetail(value);
    if (normalized.isEmpty) return 'Not measured';
    return normalized;
  }
}

class TaskDeveloperSnapshot {
  final String rootGoal;
  final String executionStage;
  final String currentSubGoal;
  final int actionCount;
  final int screenObservations;
  final int aiCalls;
  final int recoveryAttempts;
  final String verificationResult;
  final int totalTaskDurationMs;
  final double? confidence;
  final List<TaskExecutionEvent> events;
  final List<WorkspaceCommandRecord> workspaceCommands;
  final Map<String, int> actionTimings;
  final bool isRunning;
  final String routeSelection;
  final int duplicateActionBlocks;
  final int staleScreenBlocks;
  final int observationsReused;

  // Controlled self-upgrade surface. The stock ControlledUpgradeService is a
  // no-op development stub, so these carry empty/neutral values; a real
  // service publishes richer state through TaskTelemetryService.
  final String upgradeStage;
  final String upgradeProblem;
  final String upgradeFiles;
  final String upgradeReason;
  final String upgradeEvidence;
  final String upgradeFinalResult;
  final bool upgradeCanApply;
  final UpgradePlanSnapshot? upgradePlan;
  final List<UpgradeHistoryEntry> upgradeHistory;

  const TaskDeveloperSnapshot({
    required this.rootGoal,
    required this.executionStage,
    required this.currentSubGoal,
    required this.actionCount,
    required this.screenObservations,
    required this.aiCalls,
    required this.recoveryAttempts,
    required this.verificationResult,
    required this.totalTaskDurationMs,
    required this.confidence,
    required this.events,
    required this.workspaceCommands,
    required this.actionTimings,
    required this.isRunning,
    this.routeSelection = 'none',
    this.duplicateActionBlocks = 0,
    this.staleScreenBlocks = 0,
    this.observationsReused = 0,
    this.upgradeStage = '',
    this.upgradeProblem = '',
    this.upgradeFiles = '',
    this.upgradeReason = '',
    this.upgradeEvidence = '',
    this.upgradeFinalResult = '',
    this.upgradeCanApply = false,
    this.upgradePlan,
    this.upgradeHistory = const <UpgradeHistoryEntry>[],
  });

  factory TaskDeveloperSnapshot.idle() => const TaskDeveloperSnapshot(
        rootGoal: '',
        executionStage: 'Idle',
        currentSubGoal: '',
        actionCount: 0,
        screenObservations: 0,
        aiCalls: 0,
        recoveryAttempts: 0,
        verificationResult: 'Not measured',
        totalTaskDurationMs: 0,
        confidence: null,
        events: <TaskExecutionEvent>[],
        workspaceCommands: <WorkspaceCommandRecord>[],
        actionTimings: <String, int>{},
        isRunning: false,
        routeSelection: 'none',
        duplicateActionBlocks: 0,
        staleScreenBlocks: 0,
        observationsReused: 0,
      );
}

class TaskExecutionEvent {
  final String stage;
  final String detail;
  final DateTime timestamp;

  const TaskExecutionEvent({
    required this.stage,
    required this.detail,
    required this.timestamp,
  });
}

class WorkspaceCommandRecord {
  final String command;
  final bool succeeded;
  final int exitCode;
  final int elapsedMs;
  final String workingDirectory;

  const WorkspaceCommandRecord({
    required this.command,
    required this.succeeded,
    required this.exitCode,
    required this.elapsedMs,
    required this.workingDirectory,
  });
}

class TaskTelemetrySnapshot {
  final int totalMs;
  final Map<String, int> stageMs;
  final int retries;
  final String status;
  final String routeSelection;
  final int duplicateActionBlocks;
  final int staleScreenBlocks;
  final int observationsReused;

  const TaskTelemetrySnapshot({
    required this.totalMs,
    required this.stageMs,
    required this.retries,
    required this.status,
    required this.routeSelection,
    required this.duplicateActionBlocks,
    required this.staleScreenBlocks,
    required this.observationsReused,
  });

  int get aiMs => stageMs['ai_request'] ?? 0;
  int get observationMs => stageMs['screen_observation'] ?? 0;
  int get verificationMs => stageMs['verification'] ?? 0;

  String toSafeLogString() =>
      'status=$status totalMs=$totalMs aiMs=$aiMs '
      'observationMs=$observationMs verificationMs=$verificationMs retries=$retries';
}

/// Immutable value snapshot of a controlled self-upgrade plan as rendered in
/// the Developer Mode panel. Owned by the telemetry layer to avoid a
/// service↔telemetry import cycle.
class UpgradeStageSnapshot {
  final String title;
  final String status;
  final List<String> files;
  final String error;

  const UpgradeStageSnapshot({
    required this.title,
    required this.status,
    this.files = const <String>[],
    this.error = '',
  });
}

class UpgradePlanSnapshot {
  final String request;
  final String status;
  final int currentStageIndex;
  final List<UpgradeStageSnapshot> stages;
  final List<String> selectedTests;
  final List<String> impactedFiles;
  final Map<String, List<String>> dependencies;

  const UpgradePlanSnapshot({
    required this.request,
    required this.status,
    required this.currentStageIndex,
    required this.stages,
    this.selectedTests = const <String>[],
    this.impactedFiles = const <String>[],
    this.dependencies = const <String, List<String>>{},
  });
}

class UpgradeHistoryEntry {
  final String id;
  final String status;
  final String changeSummary;
  final DateTime createdAt;
  final List<String> files;
  final String validationEvidence;
  final String finalResult;

  const UpgradeHistoryEntry({
    required this.id,
    required this.status,
    required this.changeSummary,
    required this.createdAt,
    this.files = const <String>[],
    this.validationEvidence = '',
    this.finalResult = '',
  });
}
