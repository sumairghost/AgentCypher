import 'dart:async';

import '../../services/screen_automation_service.dart';

/// One actionable element from the accessibility tree (Phase 10, level 1).
///
/// Pure data: no Android types leak upward, so callers (agent, UI, verifier)
/// never have to parse raw channel payloads.
class ScreenElement {
  final int index;
  final String text;
  final String contentDescription;
  final String type;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final bool checked;
  final bool enabled;
  final bool focused;
  final int left;
  final int top;
  final int right;
  final int bottom;

  const ScreenElement({
    required this.index,
    required this.text,
    required this.contentDescription,
    required this.type,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.checked,
    required this.enabled,
    required this.focused,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Best available human label; empty when the node exposes neither.
  String get label => text.isNotEmpty ? text : contentDescription;

  /// True when the node can actually be interacted with.
  bool get actionable => enabled && (clickable || editable);

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  factory ScreenElement.fromNode(Map<String, dynamic> node) {
    final bounds = node['bounds'];
    int readBound(String key) =>
        bounds is Map ? ((bounds[key] as num?)?.toInt() ?? 0) : 0;
    return ScreenElement(
      index: (node['index'] as num?)?.toInt() ?? 0,
      text: (node['text'] ?? '').toString(),
      contentDescription: (node['contentDescription'] ?? '').toString(),
      type: (node['className'] ?? '').toString().split('.').last,
      clickable: node['isClickable'] == true,
      editable: node['isEditable'] == true,
      scrollable: node['isScrollable'] == true,
      checked: node['isChecked'] == true,
      enabled: node['isEnabled'] != false,
      focused: node['isFocused'] == true,
      left: readBound('left'),
      top: readBound('top'),
      right: readBound('right'),
      bottom: readBound('bottom'),
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'content_description': contentDescription,
    'type': type,
    'clickable': clickable,
    'editable': editable,
    'scrollable': scrollable,
    'checked': checked,
    'enabled': enabled,
    'focused': focused,
    'bounds': {'left': left, 'top': top, 'right': right, 'bottom': bottom},
  };
}

/// Structured observation of the current screen.
///
/// Captured cheapest-first, so callers receive structure instead of being
/// forced to process pixels:
///
/// * level 1 — accessibility tree (text, roles, flags, bounds)
/// * level 2 — native Android state (foreground package, dimensions)
/// * level 3 — screenshot, ONLY when the caller explicitly allows it AND the
///   accessibility tree was insufficient
/// * level 4 — vision/LLM analysis is deliberately NOT performed here; that
///   stays an explicit caller/provider decision
class ScreenObservation {
  final String packageName;
  final List<ScreenElement> elements;
  final int elementCount;
  final int screenWidth;
  final int screenHeight;
  final String orientation;
  final ScreenElement? focusedElement;
  final String summary;

  /// Non-null only when level-3 capture actually ran and succeeded.
  final String? screenshotBase64;

  final DateTime timestamp;
  final int durationMs;

  const ScreenObservation({
    required this.packageName,
    required this.elements,
    required this.elementCount,
    required this.screenWidth,
    required this.screenHeight,
    required this.orientation,
    required this.focusedElement,
    required this.summary,
    required this.screenshotBase64,
    required this.timestamp,
    required this.durationMs,
  });

  /// True when level 1 alone described the screen, so no screenshot was
  /// needed. Callers must use this instead of capturing unconditionally.
  bool get treeSufficient => elements.isNotEmpty;

  bool get hasScreenshot => screenshotBase64 != null;

  /// Elements that can actually be acted upon.
  List<ScreenElement> get actionableElements =>
      elements.where((element) => element.actionable).toList();

  /// Visible text, de-duplicated, for matching and verification.
  List<String> get visibleText {
    final seen = <String>{};
    for (final element in elements) {
      if (element.text.isNotEmpty) seen.add(element.text);
    }
    return seen.toList();
  }

  ScreenElement? findByLabel(String needle) {
    final lower = needle.toLowerCase();
    for (final element in elements) {
      if (element.label.toLowerCase().contains(lower)) return element;
    }
    return null;
  }
}

/// Bounded, lazy screen-observation entry point (Phase 10).
///
/// Nothing here polls: each [observe] call performs one bounded round of
/// level-1/2 reads and captures a screenshot only when explicitly allowed and
/// the tree could not describe the screen.
class ScreenObserver {
  final ScreenAutomationService screenAutomation;

  ScreenObserver(this.screenAutomation);

  /// Whole-observation budget. Two accessibility channel calls are capped at
  /// 3s each by the bridge, plus a screenshot on the optional path.
  static const Duration observeBudget = Duration(seconds: 8);

  /// Maximum elements carried upward. Matches the existing compact-state
  /// limit so observation cannot inflate context size unexpectedly.
  static const int maxElements = 40;

  /// Returns a structured observation, or null when screen state could not be
  /// read (service disabled/unavailable, or the budget expired). A null
  /// return is an honest failure — callers must not treat it as "no elements".
  Future<ScreenObservation?> observe({
    bool allowScreenshot = false,
    String? task,
  }) async {
    final watch = Stopwatch()..start();
    try {
      final nodes = await screenAutomation.dumpScreen().timeout(observeBudget);
      final packageName =
          await screenAutomation.getCurrentPackage().timeout(observeBudget) ??
          'unknown';

      final elements = nodes.take(maxElements).map(ScreenElement.fromNode).toList();

      var screenWidth = 0;
      var screenHeight = 0;
      for (final node in nodes) {
        final bounds = node['bounds'];
        if (bounds is Map) {
          final right = (bounds['right'] as num?)?.toInt() ?? 0;
          final bottom = (bounds['bottom'] as num?)?.toInt() ?? 0;
          if (right > screenWidth) screenWidth = right;
          if (bottom > screenHeight) screenHeight = bottom;
        }
      }

      ScreenElement? focused;
      for (final element in elements) {
        if (element.focused) {
          focused = element;
          break;
        }
      }

      // Level 3: only when permitted AND level 1 could not describe the
      // screen. Never captured just because it is possible.
      String? screenshot;
      if (allowScreenshot && elements.isEmpty) {
        screenshot = await screenAutomation
            .takeScreenshot()
            .timeout(observeBudget);
      }

      watch.stop();
      return ScreenObservation(
        packageName: packageName,
        elements: elements,
        elementCount: nodes.length,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        orientation: screenWidth > screenHeight ? 'landscape' : 'portrait',
        focusedElement: focused,
        summary: ScreenAutomationService.formatCompactScreenState(
          nodes: nodes,
          packageName: packageName,
          task: task,
        ),
        screenshotBase64: screenshot,
        timestamp: DateTime.now(),
        durationMs: watch.elapsedMilliseconds,
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}