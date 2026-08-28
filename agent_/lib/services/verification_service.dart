import 'screen_automation_service.dart';
import 'system_control_service.dart';

/// A compact, comparable observation of the Android accessibility screen.
///
/// A native method returning without throwing is not treated as success. The
/// caller must observe a readable post-action state and compare it with the
/// pre-action state or an explicit expected value.
class ScreenSnapshot {
  final String packageName;
  final String summary;
  final String fingerprint;
  final bool readable;
  final List<Map<String, dynamic>> elements;

  const ScreenSnapshot({
    required this.packageName,
    required this.summary,
    required this.fingerprint,
    required this.readable,
    this.elements = const [],
  });

  static const unreadable = ScreenSnapshot(
    packageName: '',
    summary: '',
    fingerprint: '',
    readable: false,
  );
}

class VerificationService {
  static const _verificationStopWords = <String>{
    'the',
    'and',
    'with',
    'that',
    'this',
    'after',
    'into',
    'from',
    'current',
    'screen',
  };

  final ScreenAutomationService _screen = ScreenAutomationService();
  final SystemControlService _systemControl = SystemControlService();

  /// Builds a snapshot from an already-fetched compact screen state so the
  /// executor can reuse its per-step observation instead of re-dumping.
  static ScreenSnapshot fromScreenState(Map<String, dynamic> state) {
    try {
      final packageName = (state['package'] ?? '').toString();
      final summary = (state['summary'] ?? '').toString();
      final rawElements = state['elements'];
      final elements = rawElements is List
          ? rawElements
                .whereType<Map>()
                .map((element) => Map<String, dynamic>.from(element))
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
      final readable =
          packageName.isNotEmpty &&
          packageName != 'unknown' &&
          summary.isNotEmpty &&
          !summary.contains('Could not read screen');
      return ScreenSnapshot(
        packageName: packageName,
        summary: summary,
        fingerprint: _fingerprint(packageName, elements, summary),
        readable: readable,
        elements: elements,
      );
    } catch (_) {
      return ScreenSnapshot.unreadable;
    }
  }

  /// Waits until [condition] holds or [timeout] expires. Polls with a fresh
  /// observation each interval; returns the last observation so callers do
  /// not need to re-capture after a successful wait.
  Future<(bool, ScreenSnapshot)> waitForCondition(
    bool Function(ScreenSnapshot snapshot) condition, {
    Duration timeout = const Duration(seconds: 4),
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var snapshot = await captureSnapshot();
    while (!condition(snapshot)) {
      if (DateTime.now().isAfter(deadline)) return (false, snapshot);
      await Future<void>.delayed(pollInterval);
      snapshot = await captureSnapshot();
    }
    return (true, snapshot);
  }

  Future<ScreenSnapshot> captureSnapshot() async {
    try {
      final state = await _screen.getCompactScreenState();
      return fromScreenState(state);
    } catch (_) {
      return ScreenSnapshot.unreadable;
    }
  }

  /// Returns true only when both observations are readable and materially differ.
  static bool hasChanged(ScreenSnapshot before, ScreenSnapshot after) {
    if (!before.readable || !after.readable) return false;
    return before.fingerprint != after.fingerprint ||
        before.packageName != after.packageName;
  }

  /// Verify that an app became foreground after a real launch request.
  /// Evaluates condition immediately before any bounded wait.
  Future<bool> verifyAppOpened(String? packageName, String? appName) async {
    if (packageName == null && appName == null) return false;
    try {
      // Immediate evaluation first; only poll if needed
      final immediate = await _checkAppForeground(packageName, appName);
      if (immediate) return true;

      final (ready, _) = await waitForCondition(
        (s) => s.readable && (packageName == null
            ? (appName != null && s.summary.toLowerCase().contains(appName.toLowerCase()))
            : (s.packageName.toLowerCase().contains(packageName!.toLowerCase()))),
        timeout: const Duration(seconds: 4),
        pollInterval: const Duration(milliseconds: 200),
      );
      return ready;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkAppForeground(String? packageName, String? appName) async {
    try {
      final currentPackage = (await _screen.getCurrentPackage() ?? '').toLowerCase();
      if (currentPackage.isEmpty) return false;
      if (packageName != null) {
        final normalized = packageName.toLowerCase();
        return currentPackage == normalized || currentPackage.contains(normalized);
      }
      final normalized = appName!.toLowerCase();
      return currentPackage.contains(normalized);
    } catch (_) {
      return false;
    }
  }

  /// Verify the final screen is consistent with the requested root goal.
  /// This is deliberately conservative: an unreadable screen never counts as
  /// completion, and known app goals require the expected app context.
  Future<bool> verifyTaskGoal(String goal) async {
    final snapshot = await captureSnapshot();
    if (!snapshot.readable) return false;
    final normalizedGoal = goal.toLowerCase();
    final normalizedScreen = snapshot.summary.toLowerCase();
    final package = snapshot.packageName.toLowerCase();
    const appHints = <String, List<String>>{
      'whatsapp': ['whatsapp'],
      'youtube': ['youtube'],
      'telegram': ['telegram'],
      'instagram': ['instagram'],
      'facebook': ['facebook'],
      'spotify': ['spotify'],
      'chrome': ['chrome'],
      'google': ['google'],
      'settings': ['settings'],
      'play store': ['play store', 'vending'],
    };
    for (final entry in appHints.entries) {
      if (normalizedGoal.contains(entry.key) &&
          !entry.value.any((hint) => package.contains(hint) || normalizedScreen.contains(hint))) {
        return false;
      }
    }

    final requiresVisibleOutcome = RegExp(
      r'\b(send|sent|message|text|subscribe|subscribed|play|playing|download|downloaded|install|installed|turn on|enable)\b',
    ).hasMatch(normalizedGoal);
    if (!requiresVisibleOutcome) return true;

    final goalWords = normalizedGoal
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 4)
        .take(6);
    return goalWords.any((word) => normalizedScreen.contains(word));
  }

  /// Verify an action by comparing an observed pre-state and post-state.
  Future<bool> verifyScreenAction(
    String action,
    String? expectedChange, {
    ScreenSnapshot? before,
  }) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final after = await captureSnapshot();
      if (!after.readable) return false;
      if (expectedChange != null && expectedChange.trim().isNotEmpty) {
        final expectedWords = expectedChange
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.length >= 3)
            .where((word) => !_verificationStopWords.contains(word))
            .toList();
        final matchingWords = expectedWords
            .where(after.summary.toLowerCase().contains)
            .length;
        return matchingWords > 0 &&
            (before == null || hasChanged(before, after));
      }
      if (before == null) return false;
      return hasChanged(before, after);
    } catch (_) {
      return false;
    }
  }

  /// Verify that the intended field contains the newly typed text.
  Future<bool> verifyTextTyped(
    String text, {
    String? fieldHint,
    ScreenSnapshot? before,
  }) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final after = await captureSnapshot();
      if (!after.readable || text.trim().isEmpty) return false;
      final summary = after.summary.toLowerCase();
      final textPresent = summary.contains(text.trim().toLowerCase());
      if (textPresent) return true;
      if (fieldHint != null && fieldHint.trim().isNotEmpty) {
        final hintPresent = summary.contains(fieldHint.trim().toLowerCase());
        return hintPresent && before != null && hasChanged(before, after);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify that a click produced a readable and observable UI transition.
  Future<bool> verifyElementClicked(
    String elementText, {
    ScreenSnapshot? before,
  }) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final after = await captureSnapshot();
      if (!after.readable) return false;
      if (before == null) return elementText.trim().isNotEmpty;
      return hasChanged(before, after);
    } catch (_) {
      return false;
    }
  }

  /// Read-back verification for device settings. Returns true only when the
  /// platform reports a value within [tolerance] of [expectedValue].
  /// Returns false when the value cannot be read — never pretends success.
  Future<bool> verifyDeviceState(
    String actionType,
    Map<String, dynamic> params,
  ) async {
    final expected = (params['level'] ?? params['expected_value']) as num?;
    if (expected == null) return false;
    final tolerance = ((params['tolerance'] as num?) ?? 5).toDouble();
    try {
      switch (actionType) {
        case 'set_volume':
          final current = await _systemControl.getVolume();
          if (current < 0) return false;
          return (current - expected).abs() <= tolerance + 1;
        case 'set_brightness':
          final current = await _systemControl.getBrightness();
          if (current < 0) return false;
          return (current - expected).abs() <= tolerance + 1;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Typed expected-result check driven by the plan's [verificationMethod].
  ///
  /// [before] may be null for steps whose pre-state was unreadable; such
  /// steps then rely on their explicit expected content instead of a
  /// fingerprint diff.
  Future<bool> verifyStepResult({
    required String action,
    required String verificationMethod,
    String? expectedContent,
    num? expectedValue,
    num tolerance = 5,
    String? requiredApp,
    Map<String, dynamic>? params,
    ScreenSnapshot? before,
  }) async {
    switch (verificationMethod) {
      case 'none':
        // "none" is only valid for observation-only actions; anything
        // mutating must not claim verified through this path.
        return action == 'wait' || action == 'done';

      case 'app_foreground':
        if (requiredApp == null || requiredApp.isEmpty) return false;
        return waitForCondition(
          (snapshot) => _packageMatches(snapshot, requiredApp),
          timeout: const Duration(seconds: 4),
        ).then((result) => result.$1);

      case 'device_state':
        return verifyDeviceState(action, {
          ...?params,
          'expected_value': expectedValue,
          'tolerance': tolerance,
        });

      case 'text_typed':
      case 'content_visible':
        final content = (expectedContent ?? '').trim();
        if (content.isEmpty) return false;
        final words = _contentWords(content);
        if (words.isEmpty) return false;
        final (_, after) = await waitForCondition(
          (snapshot) =>
              snapshot.readable &&
              _matchesWords(snapshot.summary.toLowerCase(), words) >= 0,
          timeout: const Duration(seconds: 4),
        );
        if (!after.readable) return false;
        if (_matchesWords(after.summary.toLowerCase(), words) > 0) {
          // Content present. For mutating screen steps also require that the
          // screen actually changed, unless there is no readable before
          // state to compare against.
          if (before == null || !before.readable) return true;
          return hasChanged(before, after) ||
              _matchesWords(after.summary.toLowerCase(), words) >
                  _matchesWords(before.summary.toLowerCase(), words);
        }
        return false;

      case 'screen_changed':
      default:
        final (_, after) = await waitForCondition(
          (snapshot) =>
              snapshot.readable &&
              (before == null ? true : hasChanged(before, snapshot)),
          timeout: const Duration(seconds: 3),
        );
        if (!after.readable) return false;
        if (before == null || !before.readable) {
          // Without a readable pre-state, require explicit expected content.
          final words = _contentWords(expectedContent ?? '');
          return words.isEmpty
              ? false
              : _matchesWords(after.summary.toLowerCase(), words) > 0;
        }
        return hasChanged(before, after);
    }
  }

  static int _matchesWords(String haystack, List<String> words) =>
      words.where(haystack.contains).length;

  static bool _packageMatches(ScreenSnapshot snapshot, String requiredApp) {
    final normalized = requiredApp.trim().toLowerCase();
    if (normalized.isEmpty || !snapshot.readable) return false;
    final package = snapshot.packageName.toLowerCase();
    return package.contains(normalized) ||
        normalized.contains(_lastPackageSegment(package)) ||
        package.endsWith(normalized.replaceAll(' ', ''));
  }

  static String _lastPackageSegment(String package) {
    final parts = package.split('.');
    return parts.isEmpty ? package : parts.last;
  }

  static List<String> _contentWords(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.length >= 3)
      .where((word) => !_verificationStopWords.contains(word))
      .toList();

  static String _fingerprint(
    String packageName,
    List<Map<String, dynamic>> elements,
    String summary,
  ) {
    final parts = <String>[packageName];
    for (final element in elements) {
      parts.add(
        [
          element['index'],
          element['text'],
          element['contentDescription'],
          element['type'],
          element['clickable'],
          element['editable'],
          element['scrollable'],
          element['checked'],
          element['enabled'],
          element['bounds'],
        ].map((value) => value.toString().trim().toLowerCase()).join('|'),
      );
    }
    if (parts.length == 1) parts.add(summary.trim().toLowerCase());
    return parts.join('\n');
  }
}
