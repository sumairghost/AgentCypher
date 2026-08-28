import 'package:flutter/material.dart';

import '../../core/ui/cypher_voice_orb.dart';
import '../../models/assistant_overlay_phase.dart';

/// Backward-compatible launcher orb for the floating assistant.
///
/// Renders the premium procedural [CypherVoiceOrb] using the overlay's
/// [AssistantOverlayPhase] state model, so the compact floating bubble gets
/// the same liquid-light material, state color mapping, touch physics, and
/// audio coupling as the full orb — without duplicating any rendering.
class AssistantOrb extends StatelessWidget {
  final AssistantOverlayPhase phase;
  final double size;
  final double audioLevel;
  final VoidCallback? onTap;

  const AssistantOrb({
    super.key,
    required this.phase,
    this.size = 56,
    this.audioLevel = 0.0,
    this.onTap,
  });

  static CypherVoiceOrbState _map(AssistantOverlayPhase phase) {
    switch (phase) {
      case AssistantOverlayPhase.listening:
        return CypherVoiceOrbState.listening;
      case AssistantOverlayPhase.thinking:
        return CypherVoiceOrbState.processing;
      case AssistantOverlayPhase.executing:
        return CypherVoiceOrbState.executing;
      case AssistantOverlayPhase.error:
        return CypherVoiceOrbState.error;
      case AssistantOverlayPhase.idle:
      case AssistantOverlayPhase.expanded:
      case AssistantOverlayPhase.success:
      case AssistantOverlayPhase.awaitingApproval:
        return CypherVoiceOrbState.idle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CypherVoiceOrb(
      state: _map(phase),
      audioLevel: audioLevel,
      size: size,
      enabled: true,
      onTap: onTap,
      semanticLabel: switch (phase) {
        AssistantOverlayPhase.listening => 'Cypher is listening',
        AssistantOverlayPhase.thinking => 'Cypher is processing your request',
        AssistantOverlayPhase.executing => 'Cypher is executing a task',
        AssistantOverlayPhase.error => 'Cypher encountered an error',
        AssistantOverlayPhase.idle || AssistantOverlayPhase.expanded => 'Cypher assistant launcher',
        AssistantOverlayPhase.success || AssistantOverlayPhase.awaitingApproval => 'Cypher assistant launcher',
      },
    );
  }
}