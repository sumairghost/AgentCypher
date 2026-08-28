import 'package:flutter_test/flutter_test.dart';

import '../lib/services/task_telemetry_service.dart';

void main() {
  test('publishes sanitized live task state and timing fields', () async {
    final telemetry = TaskTelemetryService.shared;
    telemetry.start(rootGoal: 'Open Settings');
    telemetry.setTaskContext(subGoal: 'Open the Settings app', stage: 'Planning');
    telemetry.setConfidence(0.88);
    telemetry.recordObservation(source: 'accessibility');
    telemetry.recordAiCall(stage: 'task step');
    telemetry.recordAction(action: 'open_app');
    telemetry.recordVerification('Passed');

    final snapshot = telemetry.developerState.value;
    expect(snapshot.rootGoal, 'Open Settings');
    expect(snapshot.currentSubGoal, 'Open the Settings app');
    expect(snapshot.executionStage, 'Verifying');
    expect(snapshot.confidence, 0.88);
    expect(snapshot.screenObservations, 1);
    expect(snapshot.aiCalls, 1);
    expect(snapshot.actionCount, 1);
    expect(snapshot.verificationResult, 'Passed');
    expect(snapshot.events, isNotEmpty);

    final finished = telemetry.finish(status: 'success');
    expect(finished.status, 'success');
    expect(telemetry.developerState.value.isRunning, isFalse);
  });

  test('clamps invalid confidence values safely', () {
    final telemetry = TaskTelemetryService.shared;
    telemetry.start(rootGoal: 'Test');
    telemetry.setConfidence(3.0);
    expect(telemetry.developerState.value.confidence, 1.0);
    telemetry.setConfidence(-1.0);
    expect(telemetry.developerState.value.confidence, 0.0);
    telemetry.finish(status: 'failed');
  });
}
