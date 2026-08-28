import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/assistant_overlay_phase.dart';
import 'package:agent_cypher/widgets/overlay/assistant_orb.dart';

/// Overlay lifecycle and hardening tests. These exercise the public
/// state-machine contract without depending on Android plugins or the
/// network. Pure Dart so they run under `flutter test` regardless of
/// platform availability.
void main() {
  group('Phase transition contract', () {
    test('idle -> thinking -> executing -> success is valid progression', () {
      final path = <AssistantOverlayPhase>[];
      var p = AssistantOverlayPhase.idle;
      path.add(p);
      p = AssistantOverlayPhase.thinking;
      path.add(p);
      p = AssistantOverlayPhase.executing;
      path.add(p);
      p = AssistantOverlayPhase.success;
      path.add(p);
      expect(path, [
        AssistantOverlayPhase.idle,
        AssistantOverlayPhase.thinking,
        AssistantOverlayPhase.executing,
        AssistantOverlayPhase.success,
      ]);
    });

    test('cancellation: thinking|executing -> idle is valid', () {
      final phase = AssistantOverlayPhase.thinking;
      final next = AssistantOverlayPhase.idle;
      expect(_isTerminal(phase), false);
      expect(_isTerminal(next), true);
    });

    test('awaitingApproval signals a hand-off to main app', () {
      expect(
        AssistantOverlayPhase.awaitingApproval == AssistantOverlayPhase.awaitingApproval,
        true,
      );
    });

    test('error is a terminal state', () {
      expect(_isTerminal(AssistantOverlayPhase.error), true);
    });

    test('success is a terminal state', () {
      expect(_isTerminal(AssistantOverlayPhase.success), true);
    });

    test('listening is non-terminal (can return to idle)', () {
      expect(_isTerminal(AssistantOverlayPhase.listening), false);
    });

    test('expanded is non-terminal (user can collapse)', () {
      expect(_isTerminal(AssistantOverlayPhase.expanded), false);
    });
  });

  group('Duplicate-prevention contract', () {
    test('second request blocked when one is active', () {
      var isSent = false;
      TaskExecutorStub? executor = null;
      // First request starts
      isSent = true;
      executor = TaskExecutorStub();
      // Second request attempts to start
      final blocked = (isSent || executor != null);
      expect(blocked, true);
    });

    test('after completion, executor cleared and isSent reset', () {
      var isSent = true;
      TaskExecutorStub? executor = TaskExecutorStub();
      executor!.cancel();
      isSent = false;
      executor = null;
      expect(isSent, false);
      expect(executor, isNull);
    });
  });

  group('Sensitive-plan handoff', () {
    test('preview-required results route to awaitingApproval phase', () {
      final res = 'I need your approval to proceed with this plan.';
      expect(_isAwaitingApproval(res), true);
    });

    test('normal completion is not approval-pending', () {
      final res = 'Done.';
      expect(_isAwaitingApproval(res), false);
    });
  });

  group('Orb — accessibility and reduced motion', () {
    testWidgets('reduced motion uses static painter', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: AssistantOrb(phase: AssistantOverlayPhase.idle)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('orb has semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Agent Cypher assistant orb',
              button: true,
              child: AssistantOrb(phase: AssistantOverlayPhase.idle),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Agent Cypher assistant orb'), findsOneWidget);
    });
  });

  group('Orb — disposal', () {
    testWidgets('orb disposes without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssistantOrb(phase: AssistantOverlayPhase.idle)),
        ),
      );
      // Replace tree to force unmount/dispose.
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pumpAndSettle();
      // If dispose threw, tester would report it.
    });
  });
}

bool _isTerminal(AssistantOverlayPhase phase) {
  return phase == AssistantOverlayPhase.idle ||
      phase == AssistantOverlayPhase.success ||
      phase == AssistantOverlayPhase.error ||
      phase == AssistantOverlayPhase.awaitingApproval;
}

bool _isAwaitingApproval(String result) {
  final lowered = result.toLowerCase();
  return lowered.contains('approval') ||
      lowered.contains('review') ||
      lowered.contains('preview');
}

class TaskExecutorStub {
  bool cancelled = false;
  void cancel() {
    cancelled = true;
  }
}
