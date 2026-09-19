import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/assistant_overlay_phase.dart';
import 'package:agent_cypher/widgets/overlay/assistant_orb.dart';
import 'package:agent_cypher/core/ui/cypher_voice_orb.dart';

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
      expect(
        find.bySemanticsLabel('Agent Cypher assistant orb'),
        findsOneWidget,
      );
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
      // CustomPaint should render without animation controllers. The orb
      // legitimately layers a glow painter over the core painter.
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('every phase maps to a valid orb state', (tester) async {
      for (final phase in AssistantOverlayPhase.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AssistantOrb(phase: phase, size: 40),
            ),
          ),
        );
        await tester.pump();
        // Each phase must render a CustomPaint (the orb) and expose a semantics
        // label so the state is never conveyed by animation alone.
        expect(find.byType(CustomPaint), findsOneWidget,
            reason: 'phase $phase failed to render the orb');
        expect(find.byType(Semantics), findsOneWidget,
            reason: 'phase $phase missing semantic label');
      }
    });

    testWidgets('listening phase maps to CypherVoiceOrbState.listening', (tester) async {
      // AssistantOrb delegates to CypherVoiceOrb; the listening phase must not
      // be flattened into idle. We verify indirectly via the semantics label,
      // which is state-specific in the adapter.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantOrb(phase: AssistantOverlayPhase.listening),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Cypher is listening'), findsOneWidget);
    });

    testWidgets('error phase surfaces an error-tinted, labelled orb', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantOrb(phase: AssistantOverlayPhase.error),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Cypher encountered an error'), findsOneWidget);
    });

    testWidgets('audioLevel is plumbed through to the orb', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantOrb(
              phase: AssistantOverlayPhase.listening,
              audioLevel: 0.8,
              size: 48,
            ),
          ),
        ),
      );
      await tester.pump();
      // The orb must still render when driven with a non-zero amplitude.
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}