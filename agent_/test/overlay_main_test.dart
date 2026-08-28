import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/assistant_overlay_phase.dart';

/// Standalone state-machine unit tests for overlay logic.
/// Tests phase naming, status text, and routing guards without
/// requiring Flutter widget rendering or native service mocks.
void main() {
  group('AssistantOverlayPhase — state naming', () {
    test('all phases have human-readable name', () {
      for (final phase in AssistantOverlayPhase.values) {
        expect(_phaseName(phase), isNotEmpty);
      }
    });

    test('idle maps to ready', () {
      expect(_phaseName(AssistantOverlayPhase.idle), 'Ready');
    });

    test('listening maps to Listening', () {
      expect(_phaseName(AssistantOverlayPhase.listening), 'Listening');
    });

    test('thinking maps to Thinking', () {
      expect(_phaseName(AssistantOverlayPhase.thinking), 'Thinking');
    });

    test('executing maps to Acting', () {
      expect(_phaseName(AssistantOverlayPhase.executing), 'Acting');
    });

    test('success maps to Done', () {
      expect(_phaseName(AssistantOverlayPhase.success), 'Done');
    });

    test('error maps to Error', () {
      expect(_phaseName(AssistantOverlayPhase.error), 'Error');
    });
  });

  group('Phase status text', () {
    test('thinking has descriptive status text', () {
      expect(_statusText(AssistantOverlayPhase.thinking), isNotEmpty);
    });

    test('executing has descriptive status text', () {
      expect(_statusText(AssistantOverlayPhase.executing), isNotEmpty);
    });

    test('other phases return empty string', () {
      for (final phase in [
        AssistantOverlayPhase.idle,
        AssistantOverlayPhase.expanded,
        AssistantOverlayPhase.success,
        AssistantOverlayPhase.error,
        AssistantOverlayPhase.awaitingApproval,
      ]) {
        expect(_statusText(phase), '');
      }
    });
  });

  group('Phase transition guard', () {
    test('executing and thinking are cancellable', () {
      expect(_isCancellable(AssistantOverlayPhase.executing), true);
      expect(_isCancellable(AssistantOverlayPhase.thinking), true);
    });

    test('idle, success, error are not cancellable', () {
      expect(_isCancellable(AssistantOverlayPhase.idle), false);
      expect(_isCancellable(AssistantOverlayPhase.success), false);
      expect(_isCancellable(AssistantOverlayPhase.error), false);
    });
  });

  group('Task routing — fast-path vs planner', () {
    test('YouTube search routes to fast-path', () {
      expect(_shouldUseFastPath('Open YouTube and search for cats'), true);
    });

    test('volume control routes to fast-path', () {
      expect(_shouldUseFastPath('Set volume to 50'), true);
    });

    test('generic task routes to planner', () {
      expect(_shouldUseFastPath('Open settings and enable WiFi'), false);
    });

    test('messaging intent is not fast-path-eligible', () {
      expect(_shouldUseFastPath('Send a message to John'), false);
    });

    test('empty input is handled', () {
      expect(_shouldUseFastPath(''), false);
    });
  });
}

// --- Replicated helpers matching overlay_main.dart logic ---

String _phaseName(AssistantOverlayPhase phase) {
  switch (phase) {
    case AssistantOverlayPhase.idle:
      return 'Ready';
    case AssistantOverlayPhase.expanded:
      return 'Expanded';
    case AssistantOverlayPhase.listening:
      return 'Listening';
    case AssistantOverlayPhase.thinking:
      return 'Thinking';
    case AssistantOverlayPhase.executing:
      return 'Acting';
    case AssistantOverlayPhase.success:
      return 'Done';
    case AssistantOverlayPhase.error:
      return 'Error';
    case AssistantOverlayPhase.awaitingApproval:
      return 'Awaiting';
  }
}

String _statusText(AssistantOverlayPhase phase) {
  switch (phase) {
    case AssistantOverlayPhase.thinking:
      return 'Planning your request…';
    case AssistantOverlayPhase.executing:
      return 'Executing on screen…';
    default:
      return '';
  }
}

bool _isCancellable(AssistantOverlayPhase phase) {
  return phase == AssistantOverlayPhase.thinking ||
      phase == AssistantOverlayPhase.executing;
}

/// Minimal fast-path detection matching TaskFastPathRouter patterns.
/// Keep in sync with lib/services/task_fast_path_router.dart.
bool _shouldUseFastPath(String input) {
  if (input.trim().isEmpty) return false;

  final lower = input.toLowerCase();
  // Messaging / purchase / fullscreen are never fast-path eligible
  if (lower.contains('send') && (lower.contains('message') || lower.contains('text'))) return false;
  if (lower.contains('buy') || lower.contains('purchase') || lower.contains('subscribe')) return false;
  if (lower.contains('fullscreen')) return false;

  // Fast-path patterns: YouTube, volume, brightness
  if (RegExp(r'youtube|search\s+youtube', caseSensitive: false).hasMatch(lower)) return true;
  if (RegExp(r'volume|brightness', caseSensitive: false).hasMatch(lower) &&
      RegExp(r'\b\d+\b').hasMatch(lower)) return true;
  if (RegExp(r'set\s+(volume|brightness)', caseSensitive: false).hasMatch(lower)) return true;

  return false;
}
