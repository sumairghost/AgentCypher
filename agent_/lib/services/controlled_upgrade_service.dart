import 'task_telemetry_service.dart';

/// Minimal, honest placeholder for the controlled self-upgrade workflow
/// (IDENTIFY → PROPOSE → APPLY → VALIDATE → ROLLBACK).
///
/// The Developer Mode panel is compiled against this surface, but no upgrade
/// machinery ships in the current build: every mutation is a no-op that
/// publishes an explicit "unavailable" state through [TaskTelemetryService]
/// instead of pretending to modify project files. A real implementation must
/// replace these methods with bounded, validated, checkpointed operations.
class ControlledUpgradeService {
  static final ControlledUpgradeService shared = ControlledUpgradeService._();

  ControlledUpgradeService._();

  final TaskTelemetryService _telemetry = TaskTelemetryService.shared;

  final List<UpgradeHistoryEntry> _history = <UpgradeHistoryEntry>[];
  String _problem = '';
  String _files = '';
  String _reason = '';
  String _stage = '';
  String _evidence = '';
  String _finalResult = '';

  Future<void> loadHistory(String repoPath) async {
    // Checkpoints live inside the (unimplemented) upgrade workflow; until it
    // exists there is nothing to load from the repository.
    _publish();
  }

  Future<void> identifyAndPropose({
    required String repoPath,
    required String problem,
    required String task,
    required List<String> allowedFiles,
  }) async {
    _problem = problem.trim();
    _reason = task.trim();
    _files = allowedFiles.join(', ');
    _stage = 'Unavailable in this build';
    _evidence = 'Controlled self-upgrade is not enabled in this build.';
    _finalResult = '';
    _publish();
  }

  Future<void> applyValidateAndKeepOrRollback() async {
    _stage = 'Unavailable in this build';
    _publish();
  }

  Future<void> prepareNextStage() async {
    _publish();
  }

  Future<void> rollbackLastChange() async {
    _publish();
  }

  Future<void> undoChanges(int count) async {
    _publish();
  }

  Future<void> rollbackTo(String id) async {
    _publish();
  }

  Future<void> restoreLastKnownWorking() async {
    _publish();
  }

  void _publish() {
    _telemetry.publishUpgradeState(
      upgradeStage: _stage,
      upgradeProblem: _problem,
      upgradeFiles: _files,
      upgradeReason: _reason,
      upgradeEvidence: _evidence,
      upgradeFinalResult: _finalResult,
      upgradeCanApply: false,
      upgradePlan: null,
      upgradeHistory: List<UpgradeHistoryEntry>.unmodifiable(_history),
    );
  }
}
