import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Dart bridge to the native AccessibilityService.
/// Provides screen reading, UI element interaction, and gesture control.
class ScreenAutomationService {
  static const _channel = MethodChannel(
    'com.cypherghost.agentcypher/accessibility',
  );
  static const _channelTimeout = Duration(seconds: 3);

  static Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) {
    return _channel
        .invokeMethod<T>(method, arguments)
        .timeout(
          _channelTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Accessibility channel did not reply to $method within '
              '${_channelTimeout.inSeconds}s',
            );
          },
        );
  }

  /// Verifies that this Flutter engine owns a responsive native channel.
  Future<bool> waitUntilReady() async {
    try {
      return await _invoke<bool>('ping') ?? false;
    } catch (e) {
      developer.log(
        'Accessibility channel readiness check failed: $e',
        name: 'Agent Cypher Screen Control',
      );
      return false;
    }
  }

  /// Log a message to Android's native Log system
  static Future<void> logToNative(String message) async {
    try {
      await _invoke<bool>('logToNative', {'message': message});
    } catch (_) {}
  }

  /// Check if the accessibility service is running
  Future<bool> isServiceRunning() async {
    await logToNative("[ScreenAutomationService] isServiceRunning() CALLED");
    try {
      await logToNative(
        "[ScreenAutomationService] invoking method isServiceRunning...",
      );
      final result = await _invoke<bool>('isServiceRunning') ?? false;
      await logToNative(
        "[ScreenAutomationService] isServiceRunning result = $result",
      );
      return result;
    } catch (e) {
      await logToNative(
        "[ScreenAutomationService] isServiceRunning ERROR = $e",
      );
      return false;
    }
  }

  /// Open Android accessibility settings so user can enable the service
  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  /// Dump the current screen — returns a list of UI elements
  /// Each element has: text, contentDescription, className, isClickable,
  /// isEditable, isScrollable, bounds, index, depth
  Future<List<Map<String, dynamic>>> dumpScreen() async {
    try {
      final result = await _invoke<List>('dumpScreen');
      if (result == null) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Take a screenshot and return it as a Base64 encoded string.
  /// Note: Requires Android 11 (API 30) or higher.
  Future<String?> takeScreenshot() async {
    try {
      return await _invoke<String>('takeScreenshot');
    } catch (_) {
      return null;
    }
  }

  /// Returns the screenshot plus the current screen dimensions when the
  /// native bridge supports visual capture. The caller must still apply its
  /// provider capability and privacy policy before sending it anywhere.
  Future<Map<String, dynamic>?> getVisualObservation() async {
    final imageBase64 = await takeScreenshot();
    if (imageBase64 == null || imageBase64.trim().isEmpty) return null;
    final state = await getCompactScreenState();
    if (state['is_sensitive'] == true) return null;
    return {
      'image_base64': imageBase64,
      'package': state['package'] ?? 'unknown',
      'screen_width': state['screen_width'] ?? 0,
      'screen_height': state['screen_height'] ?? 0,
      'observation_type': 'screenshot',
    };
  }

  static String formatCompactScreenState({
    required List<Map<String, dynamic>> nodes,
    String? packageName,
    String? task,
  }) {
    if (nodes.isEmpty) {
      return 'SCREEN:\npackage=${packageName ?? 'unknown'}\nELEMENTS: []';
    }

    final buffer = StringBuffer();
    buffer.writeln('SCREEN:');
    if (packageName != null && packageName.isNotEmpty) {
      buffer.writeln('package=$packageName');
    }
    buffer.writeln('ELEMENTS:');

    final stopWords = {
      'to',
      'and',
      'the',
      'a',
      'in',
      'of',
      'for',
      'on',
      'with',
      'at',
      'by',
      'from',
      'go',
      'turn',
      'open',
      'latest',
      'search',
      'about',
      'what',
    };
    final keywords = task == null
        ? <String>[]
        : task
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty && !stopWords.contains(w))
              .toList();

    for (final node in nodes.take(40)) {
      final index = node['index'] ?? 0;
      final text = (node['text'] ?? '').toString();
      final desc = (node['contentDescription'] ?? '').toString();
      final className = (node['className'] ?? '').toString();
      final isClickable = node['isClickable'] == true;
      final isEditable = node['isEditable'] == true;
      final isScrollable = node['isScrollable'] == true;
      final isChecked = node['isChecked'] == true;
      final isEnabled = node['isEnabled'] ?? true;

      String label = text.isNotEmpty ? text : desc;
      if (label.length > 80) {
        label = '${label.substring(0, 80)}...';
      }
      if (label.isEmpty && !(isClickable || isEditable || isScrollable)) {
        continue;
      }

      final type = className.isEmpty ? 'View' : className.split('.').last;
      final tags = <String>[];
      if (isClickable) tags.add('clickable');
      if (isEditable) tags.add('editable');
      if (isScrollable) tags.add('scrollable');
      if (isChecked) tags.add('checked');
      if (!isEnabled) tags.add('disabled');

      final matchText = label.toLowerCase();
      final relevant = keywords.any((kw) => matchText.contains(kw));
      final highlight = relevant ? ' *' : '';

      final bounds = node['bounds'];
      String boundsText = '';
      if (bounds is Map) {
        final left = bounds['left'];
        final top = bounds['top'];
        final right = bounds['right'];
        final bottom = bounds['bottom'];
        boundsText = ' bounds=[$left,$top,$right,$bottom]';
      }

      final labelText = label.isEmpty
          ? '(no text)'
          : 'text="${label.replaceAll(RegExp(r'\s+'), ' ').trim()}"';
      final tagText = tags.isEmpty ? '' : ' tags=${tags.join(',')}';
      buffer.writeln(
        '[$index]$highlight $labelText type=$type$tagText$boundsText',
      );
    }

    return buffer.toString();
  }

  /// Get a compact, structured screen state description suitable for agent reasoning.
  Future<Map<String, dynamic>> getCompactScreenState({String? task}) async {
    final nodes = await dumpScreen();
    final packageName = await getCurrentPackage();
    int screenWidth = 0;
    int screenHeight = 0;
    for (final node in nodes) {
      final bounds = node['bounds'];
      if (bounds is Map) {
        final right = (bounds['right'] as num?)?.toInt() ?? 0;
        final bottom = (bounds['bottom'] as num?)?.toInt() ?? 0;
        if (right > screenWidth) screenWidth = right;
        if (bottom > screenHeight) screenHeight = bottom;
      }
    }
    return {
      'package': packageName ?? 'unknown',
      'screen_width': screenWidth,
      'screen_height': screenHeight,
      'orientation': screenWidth > screenHeight ? 'landscape' : 'portrait',
      'element_count': nodes.length,
      'elements': nodes
          .take(40)
          .map(
            (node) => {
              'index': node['index'] ?? 0,
              'text': (node['text'] ?? '').toString(),
              'contentDescription': (node['contentDescription'] ?? '')
                  .toString(),
              'type': (node['className'] ?? '').toString().split('.').last,
              'clickable': node['isClickable'] == true,
              'editable': node['isEditable'] == true,
              'scrollable': node['isScrollable'] == true,
              'checked': node['isChecked'] == true,
              'enabled': node['isEnabled'] ?? true,
              'bounds': node['bounds'],
            },
          )
          .toList(),
      'summary': formatCompactScreenState(
        nodes: nodes,
        packageName: packageName,
        task: task,
      ),
    };
  }

  /// Get a simplified text description of the current screen for the LLM
  Future<String> getScreenDescription() async {
    final nodes = await dumpScreen();
    if (nodes.isEmpty) {
      return 'Could not read screen. Make sure accessibility service is enabled.';
    }
    final packageName = await getCurrentPackage();
    return formatCompactScreenState(nodes: nodes, packageName: packageName);
  }

  /// Get a highly compressed text description of the screen for the LLM
  Future<String> getCompressedScreenDescription(String task) async {
    final nodes = await dumpScreen();
    if (nodes.isEmpty) {
      return 'Could not read screen. Make sure accessibility service is enabled.';
    }
    final packageName = await getCurrentPackage();
    return formatCompactScreenState(
      nodes: nodes,
      packageName: packageName,
      task: task,
    );
  }

  /// Click an element by its visible text
  Future<bool> clickByText(String text) async {
    try {
      return await _invoke<bool>('clickByText', {'text': text}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Click at specific screen coordinates
  Future<bool> clickAt(double x, double y) async {
    try {
      return await _invoke<bool>('clickAt', {'x': x, 'y': y}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Type text into an editable field
  Future<bool> typeText(String text, {String? fieldHint}) async {
    try {
      return await _invoke<bool>('typeText', {
            'text': text,
            'fieldHint': fieldHint,
          }) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Press the Enter/Search key on the keyboard
  Future<bool> pressEnter() async {
    try {
      return await _invoke<bool>('pressEnter') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Scroll in a direction ("down", "up")
  Future<bool> scroll(String direction, {String? target}) async {
    try {
      return await _invoke<bool>('scroll', {
            'direction': direction,
            'target': target,
          }) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Swipe from one point to another
  Future<bool> swipe(
    double startX,
    double startY,
    double endX,
    double endY,
  ) async {
    try {
      return await _invoke<bool>('swipe', {
            'startX': startX,
            'startY': startY,
            'endX': endX,
            'endY': endY,
          }) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Press the back button
  Future<bool> pressBack() async {
    try {
      return await _invoke<bool>('pressBack') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Press the home button
  Future<bool> pressHome() async {
    try {
      return await _invoke<bool>('pressHome') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Show a native Android Toast message
  Future<void> showToast(String message) async {
    try {
      await _channel.invokeMethod('showToast', {'message': message});
    } catch (e) {
      // ignore
    }
  }

  /// Open notifications panel
  Future<bool> openNotifications() async {
    try {
      return await _channel.invokeMethod<bool>('openNotifications') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get sanitized diagnostics from the native accessibility service.
  Future<Map<String, dynamic>> getAccessibilityDiagnostics() async {
    try {
      final result = await _invoke<Map>('getAccessibilityDiagnostics');
      if (result == null) {
        return const {
          'service_installed': true,
          'service_enabled': false,
          'service_responding': false,
          'current_package': '',
          'node_count': 0,
          'last_observation_at': '',
        };
      }
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return const {
        'service_installed': true,
        'service_enabled': false,
        'service_responding': false,
        'current_package': '',
        'node_count': 0,
        'last_observation_at': '',
      };
    }
  }

  /// Get current foreground app package name
  Future<String?> getCurrentPackage() async {
    try {
      return await _invoke<String>('getCurrentPackage');
    } catch (e) {
      return null;
    }
  }
}
