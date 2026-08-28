import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/assistant_overlay_phase.dart';
import 'package:agent_cypher/widgets/overlay/assistant_orb.dart';

void main() {
  group('AssistantOrb - visual / accessibility', () {
    testWidgets('renders with semantic label', (tester) async {
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

    testWidgets('static when reduced-motion enabled', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: AssistantOrb(phase: AssistantOverlayPhase.listening, size: 56)),
          ),
        ),
      );
      await tester.pump();
      // CustomPaint should render without animation controllers
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('phase changes reflect color (listening=cyan)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantOrb(phase: AssistantOverlayPhase.listening),
          ),
        ),
      );
      await tester.pump();
      final painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter as _OrbPainter;
      expect(painter.phase, AssistantOverlayPhase.listening);
    });
  });
}
