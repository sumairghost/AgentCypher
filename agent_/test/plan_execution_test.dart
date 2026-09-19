import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/task_plan.dart';
import 'package:agent_cypher/services/ai_service.dart';
import 'package:agent_cypher/services/app_launcher_service.dart';
import 'package:agent_cypher/services/plan_executor.dart';
import 'package:agent_cypher/services/screen_automation_service.dart';
import 'package:agent_cypher/services/shizuku_service.dart';
import 'package:agent_cypher/services/system_control_service.dart';
import 'package:agent_cypher/services/verification_service.dart';

/// Fakes built with `implements` + targeted overrides so no plugin channel
/// is ever touched. Unused interface members fall through to [noSuchMethod].

class _Noop {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

class FakeAiService extends _Noop implements AiService {}

class FakeShizukuService extends _Noop implements ShizukuService {}

class FakeAppLauncher implements AppLauncherService {
  String openResult = 'Opened app';
  final List<String> openCalls = [];

  @override
  Future<String> openApp(String appName) async {
    openCalls.add(appName);
    return openResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

class FakeScreenService implements ScreenAutomationService {
  /// Result returned by each interaction method, consumed in order
  /// (last value repeats).
  final List<bool> interactionResults;
  final List<ScreenSnapshot> observedSnapshots;
  int dumpCount = 0;
  int clickTextCalls = 0;

  FakeScreenService({
    this.interactionResults = const [true],
    this.observedSnapshots = const [],
  });

  bool _nextResult() =>
      interactionResults.length <= 1
          ? interactionResults.first
          : interactionResults.removeAt(0);

  ScreenSnapshot _nextSnapshot(int index) => observedSnapshots.isEmpty
      ? ScreenSnapshot(
          packageName: 'com.example.app',
          summary: 'SCREEN: element',
          fingerprint: 'fp-$index',
          readable: true,
        )
      : observedSnapshots[index >= observedSnapshots.length
          ? observedSnapshots.length - 1
          : index];

  @override
  Future<List<Map<String, dynamic>>> dumpScreen() async {
    dumpCount++;
    return [];
  }

  @override
  Future<Map<String, dynamic>> getCompactScreenState({String? task}) async {
    final snapshot = _nextSnapshot(dumpCount++);
    return {
      'package': snapshot.packageName,
      'summary': snapshot.summary,
      'elements': snapshot.elements,
      'element_count': snapshot.elements.length,
      'screen_width': 1080,
      'screen_height': 2400,
    };
  }

  @override
  Future<String?> getCurrentPackage() async => _nextSnapshot(0).packageName;

  @override
  Future<bool> clickByText(String text) async {
    clickTextCalls++;
    return _nextResult();
  }

  @override
  Future<bool> clickAt(double x, double y) async => _nextResult();

  @override
  Future<bool> typeText(String text, {String? fieldHint}) async =>
      _nextResult();

  @override
  Future<bool> pressEnter() async => _nextResult();

  @override
  Future<bool> scroll(String direction, {String? target}) async =>
      _nextResult();

  @override
  Future<bool> swipe(double x, double y, double ex, double ey) async =>
      _nextResult();

  @override
  Future<bool> pressBack() async => _nextResult();

  @override
  Future<bool> pressHome() async => _nextResult();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

class FakeSystemControl implements SystemControlService {
  int volume = 40;
  int brightness = 50;

  @override
  Future<int> getVolume() async => volume;

  @override
  Future<int> getBrightness() async => brightness;

  @override
  Future<String> setVolume(int level) async {
    volume = level;
    return 'Volume set to $level%';
  }

  @override
  Future<String> setBrightness(int level) async {
    brightness = level;
    return 'Brightness set to $level%';
  }
}

class FakeVerification implements VerificationService {
  final List<ScreenSnapshot> snapshots;
  bool stepResult = true;
  int pollIndex = 0;

  FakeVerification({this.snapshots = const []});

  ScreenSnapshot nextSnapshot() {
    if (snapshots.isEmpty) {
      return const ScreenSnapshot(
        packageName: 'com.example.app',
        summary: 'SCREEN: element',
        fingerprint: 'fp',
        readable: true,
      );
    }
    final snapshot = snapshots[
        pollIndex >= snapshots.length ? snapshots.length - 1 : pollIndex];
    pollIndex++;
    return snapshot;
  }

  @override
  Future<ScreenSnapshot> captureSnapshot() async => nextSnapshot();

  @override
  Future<(bool, ScreenSnapshot)> waitForCondition(
    bool Function(ScreenSnapshot snapshot) condition, {
    Duration timeout = const Duration(seconds: 4),
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    var snapshot = await captureSnapshot();
    if (condition(snapshot)) return (true, snapshot);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      snapshot = await captureSnapshot();
      if (condition(snapshot)) return (true, snapshot);
    }
    return (false, snapshot);
  }

  @override
  Future<bool> verifyStepResult({
    required String action,
    required String verificationMethod,
    String? expectedContent,
    num? expectedValue,
    num tolerance = 5,
    String? requiredApp,
    Map<String, dynamic>? params,
    ScreenSnapshot? before,
  }) async =>
      stepResult;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

PlanExecutor buildExecutor({
  required FakeScreenService screen,
  required FakeVerification verification,
  FakeAppLauncher? launcher,
  FakeSystemControl? systemControl,
  Future<bool> Function(PlanStep step)? onBeforeStep,
  void Function(String)? onProgress,
}) {
  return PlanExecutor(
    aiService: FakeAiService(),
    screenService: screen,
    appLauncher: launcher ?? FakeAppLauncher(),
    shizukuService: FakeShizukuService(),
    verification: verification,
    systemControl: systemControl ?? FakeSystemControl(),
    onBeforeStep: onBeforeStep,
    onProgress: onProgress,
  );
}

TaskPlan planOf(List<PlanStep> steps) =>
    TaskPlan(rootGoal: 'test goal', steps: steps);

void main() {
  group('dependency gating', () {
    test('a step whose dependency fails is skipped, not executed', () async {
      final screen = FakeScreenService(interactionResults: [false]);
      final verification = FakeVerification()..stepResult = false;
      final executor = buildExecutor(screen: screen, verification: verification);
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'tap search', action: 'click_text',
            params: {'text': 'Search'}),
        const PlanStep(id: 's2', intent: 'type query', action: 'type_text',
            params: {'text': 'cats'}, dependsOn: ['s1']),
        const PlanStep(id: 's3', intent: 'submit', action: 'press_enter',
            dependsOn: ['s2']),
      ]));

      expect(result.stepResults[0].status, StepStatus.failed);
      expect(result.stepResults[1].status, StepStatus.skipped);
      expect(result.stepResults[2].status, StepStatus.skipped);
      expect(result.anyVerified, isFalse);
      // Honest partial-completion reporting: nothing claimed as done.
      expect(result.summarize(), contains('0 of 3 steps completed'));
      expect(screen.clickTextCalls, lessThanOrEqualTo(4));
    });
  });

  test('successful chain verifies every step', () async {
    final executor = buildExecutor(
      screen: FakeScreenService(),
      verification: FakeVerification(),
    );
    final result = await executor.execute(planOf([
      const PlanStep(id: 's1', intent: 'open', action: 'open_app',
          params: {'app_name': 'YouTube'}),
      const PlanStep(id: 's2', intent: 'tap search', action: 'click_text',
          params: {'text': 'Search'}, dependsOn: ['s1']),
    ]));

    expect(result.allVerified, isTrue);
    expect(result.summarize(), contains('All 2 steps completed'));
  });

  group('failure handling', () {
    test('unsupported capability is refused honestly without retrying',
        () async {
      final screen = FakeScreenService();
      final executor = buildExecutor(screen: screen, verification: FakeVerification());
      // Constructed directly to bypass validation, as a defensive check of
      // the executor's own refusal path.
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'seek video', action: 'seek_video'),
      ]));

      expect(result.stepResults.single.status, StepStatus.failed);
      expect(result.stepResults.single.detail,
          contains('not supported'));
      expect(screen.dumpCount, lessThan(6)); // no pointless retry churn
    });

    test('transient target failure succeeds on retry (bounded)', () async {
      final screen = FakeScreenService(interactionResults: [false, true]);
      final executor = buildExecutor(screen: screen, verification: FakeVerification());
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'tap search', action: 'click_text',
            params: {'text': 'Search'},
            retryPolicy: RetryPolicy(maxAttempts: 3)),
      ]));

      expect(result.stepResults.single.status, StepStatus.verified);
      expect(screen.clickTextCalls, 2);
    });

    test('wrong-app context reopens the required app before acting',
        () async {
      final launcher = FakeAppLauncher();
      final screen = FakeScreenService();
      final verification = FakeVerification(snapshots: [
        const ScreenSnapshot(
            packageName: 'com.android.chrome',
            summary: 'browser',
            fingerprint: 'chrome',
            readable: true),
        const ScreenSnapshot(
            packageName: 'com.google.android.youtube',
            summary: 'youtube home',
            fingerprint: 'yt',
            readable: true),
      ]);
      final executor = buildExecutor(
        screen: screen,
        verification: verification,
        launcher: launcher,
      );
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'search in youtube',
            action: 'click_text', params: {'text': 'Search'},
            requiredApp: 'youtube'),
      ]));

      expect(launcher.openCalls, ['youtube']);
      expect(result.stepResults.single.status, StepStatus.verified);
    });
  });

  group('reversible settings', () {
    test('set_volume verifies by read-back and records the previous value',
        () async {
      final systemControl = FakeSystemControl();
      final executor = buildExecutor(
        screen: FakeScreenService(),
        verification: FakeVerification(),
        systemControl: systemControl,
      );
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'volume to 60', action: 'set_volume',
            expectedValue: 60, reversible: true),
      ]));

      expect(result.stepResults.single.status, StepStatus.verified);
      expect(systemControl.volume, 60);
      expect(result.restoreHints(), contains('Previous volume was 40%.'));
    });

    test('set_brightness verifies by read-back', () async {
      final systemControl = FakeSystemControl();
      final executor = buildExecutor(
        screen: FakeScreenService(),
        verification: FakeVerification(),
        systemControl: systemControl,
      );
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'brightness 70',
            action: 'set_brightness', expectedValue: 70),
      ]));

      expect(result.stepResults.single.status, StepStatus.verified);
      expect(systemControl.brightness, 70);
    });
  });

  group('cancellation and approval', () {
    test('declining a sensitive step cancels that step but keeps the rest',
        () async {
      final approvals = <String>[];
      final executor = buildExecutor(
        screen: FakeScreenService(),
        verification: FakeVerification(),
        onBeforeStep: (step) async {
          approvals.add(step.id);
          return false;
        },
      );
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'open', action: 'open_app',
            params: {'app_name': 'Messages'}),
        const PlanStep(id: 's2', intent: 'send message',
            action: 'click_text', params: {'text': 'Send button'},
            requiresConfirmation: true, dependsOn: ['s1']),
        const PlanStep(id: 's3', intent: 'go home', action: 'press_home',
            dependsOn: ['s2']),
      ]));

      expect(approvals, ['s2']);
      expect(result.stepResults[0].status, StepStatus.verified);
      expect(result.stepResults[1].status, StepStatus.cancelled);
      // s3 depended on the declined step, so dependency gating skips it.
      expect(result.stepResults[2].status, StepStatus.skipped);
      expect(result.allVerified, isFalse);
    });

    test('cancel() stops between steps', () async {
      late final PlanExecutor executor;
      executor = buildExecutor(
        screen: FakeScreenService(),
        verification: FakeVerification(),
        onBeforeStep: (step) async {
          executor.cancel();
          return true;
        },
      );
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'open', action: 'open_app',
            params: {'app_name': 'YouTube'}, requiresConfirmation: true),
        const PlanStep(id: 's2', intent: 'later step', action: 'wait'),
      ]));

      expect(result.cancelledByUser, isTrue);
      expect(result.stepResults[0].status, StepStatus.verified);
      expect(result.stepResults[1].status, StepStatus.cancelled);
    });
  });

  group('performance', () {
    test('mocked multi-step task completes well under a wall-clock budget '
        'with a bounded number of dumps', () async {
      final screen = FakeScreenService();
      final executor = buildExecutor(screen: screen, verification: FakeVerification());
      final watch = Stopwatch()..start();
      final result = await executor.execute(planOf([
        const PlanStep(id: 's1', intent: 'open', action: 'open_app',
            params: {'app_name': 'YouTube'}),
        const PlanStep(id: 's2', intent: 'tap search', action: 'click_text',
            params: {'text': 'Search'}, dependsOn: ['s1']),
        const PlanStep(id: 's3', intent: 'type query', action: 'type_text',
            params: {'text': 'mrbeast latest video'}, dependsOn: ['s2']),
        const PlanStep(id: 's4', intent: 'submit', action: 'press_enter',
            dependsOn: ['s3']),
      ]));
      watch.stop();

      expect(result.allVerified, isTrue);
      // With mocked instant services the whole plan should take seconds,
      // not the ~30s+ the old fixed-sleep loop would have spent.
      expect(watch.elapsedMilliseconds, lessThan(5000));
      // Observation reuse keeps dumps low: a few per step at most.
      expect(screen.dumpCount, lessThanOrEqualTo(16));
      // Per-step latency data is available for benchmarks.
      expect(
        result.stepResults.every((r) => r.durationMs >= 0),
        isTrue,
      );
    });
  });
}
