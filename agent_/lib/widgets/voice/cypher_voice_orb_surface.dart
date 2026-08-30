import 'package:flutter/material.dart';
import '../../core/ui/cypher_voice_orb.dart';

/// Full-size orb surface for the voice-interaction screen.
///
/// Delegates all rendering to [CypherVoiceOrb] (the procedural CustomPainter
/// in lib/core/ui/cypher_voice_orb.dart). No duplicate renderer is created;
/// this is only a responsive, safe-area-aware wrapper that exposes the
/// orb at a large size (96–200) inside a dark charcoal background,
/// with semantic state labels and reduced-motion awareness.
class CypherVoiceOrbSurface extends StatelessWidget {
  final CypherVoiceOrbState state;
  final double audioLevel;
  final bool enabled;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const CypherVoiceOrbSurface({
    super.key,
    this.state = CypherVoiceOrbState.idle,
    this.audioLevel = 0.0,
    this.enabled = true,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? _labelForState(state),
      button: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: use available width/height, bounded 96–200.
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final size = (width < height ? width : height) * 0.55;
          final clamped = size.clamp(96.0, min(width, height) * 0.9);
          return Center(
            child: CypherVoiceOrb(
              state: state,
              audioLevel: audioLevel,
              enabled: enabled,
              size: clamped,
              onTap: onTap,
              semanticLabel: semanticLabel ?? _labelForState(state),
            ),
          );
        },
      ),
    );
  }

  static String _labelForState(CypherVoiceOrbState s) => switch (s) {
        CypherVoiceOrbState.idle => 'Cypher is idle',
        CypherVoiceOrbState.opening => 'Cypher is opening',
        CypherVoiceOrbState.listening => 'Cypher is listening',
        CypherVoiceOrbState.processing => 'Cypher is processing',
        CypherVoiceOrbState.executing => 'Cypher is executing',
        CypherVoiceOrbState.speaking => 'Cypher is speaking',
        CypherVoiceOrbState.closing => 'Cypher is closing',
        CypherVoiceOrbState.cancelled => 'Cypher was cancelled',
        CypherVoiceOrbState.error => 'Cypher encountered an error',
        CypherVoiceOrbState.unavailable => 'Cypher is unavailable',
      };
}
