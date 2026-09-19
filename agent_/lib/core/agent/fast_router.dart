import 'dart:async';

import 'tool.dart';
import '../../services/app_launcher_service.dart';

/// Outcome of local fast routing for a user request.
sealed class FastRouteResult {
  /// Wall-clock cost of routing itself (regex + validation + app lookup).
  final Duration routeLatency;

  const FastRouteResult(this.routeLatency);
}

/// A deterministic local action bound to a registered tool.
class FastAction extends FastRouteResult {
  final String toolId;
  final Map<String, dynamic> arguments;

  /// Short human-readable intent for progress display (e.g. 'Volume 40%').
  final String displayIntent;

  const FastAction(
    super.routeLatency, {
    required this.toolId,
    required this.arguments,
    required this.displayIntent,
  });
}

/// No safe deterministic resolution — the caller must use the agent path.
class AgentRequired extends FastRouteResult {
  final String reason;

  const AgentRequired(super.routeLatency, {required this.reason});
}

/// Lightweight local router for simple deterministic commands.
///
/// - Pure Dart: no LLM, no network, no executor/agent initialization.
/// - Anchored patterns only; near-misses and ambiguity escalate.
/// - Arguments are extracted and validated here (level 0-100 is rejected,
///   not clamped); execution and verification stay in the existing
///   [ToolRegistry]/`ActionHandler` layers — including read-back
///   verification for volume/brightness — so the fast path and the agent
///   path cannot diverge in behavior.
class FastRouter {
  final ToolRegistry _registry;
  final AppLauncherService _appLauncher;

  FastRouter(this._registry, this._appLauncher);

  static final _brightness = RegExp(
    r'^(?:set\s+)?brightness\s+(?:to\s+)?(\d{1,3})\s*(?:%|percent)?[.!]?$',
    caseSensitive: false,
  );
  static final _volume = RegExp(
    r'^(?:set\s+)?volume\s+(?:to\s+)?(\d{1,3})\s*(?:%|percent)?[.!]?$',
    caseSensitive: false,
  );
  static final _back = RegExp(r'^(?:go\s+)?back[.!]?$', caseSensitive: false);
  static final _home = RegExp(
    r'^(?:go\s+)?(?:to\s+)?(?:the\s+)?home(?:\s+screen)?[.!]?$',
    caseSensitive: false,
  );
  static final _screenshot = RegExp(
    r'^(?:(?:take|grab)\s+(?:a\s+))?screenshot[.!]?$',
    caseSensitive: false,
  );
  static final _openApp = RegExp(
    r'^open\s+(?:up\s+)?(?:the\s+)?(?:app\s+)?(.+?)\s*[.!]?$',
    caseSensitive: false,
  );

  /// Routes [input] to a fast action or an escalation. Never throws.
  Future<FastRouteResult> route(String input) async {
    final watch = Stopwatch()..start();
    try {
      final text = input.trim();
      if (text.isEmpty) {
        return AgentRequired(_lap(watch), reason: 'empty input');
      }

      final brightness = _level(_brightness.firstMatch(text));
      if (brightness != null) {
        return _levelRoute(
          watch,
          'set_brightness',
          brightness,
          'Brightness to $brightness%',
        );
      }
      final volume = _level(_volume.firstMatch(text));
      if (volume != null) {
        return _levelRoute(watch, 'set_volume', volume, 'Volume to $volume%');
      }
      if (_back.hasMatch(text)) {
        return _toolRoute(watch, 'press_back', const {}, 'Go back');
      }
      if (_home.hasMatch(text)) {
        return _toolRoute(watch, 'press_home', const {}, 'Go home');
      }
      if (_screenshot.hasMatch(text)) {
        return _toolRoute(watch, 'take_screenshot', const {}, 'Screenshot');
      }

      final openMatch = _openApp.firstMatch(text);
      if (openMatch != null) {
        final appName = (openMatch.group(1) ?? '').trim();
        if (appName.isNotEmpty && await _isKnownApp(appName)) {
          return _toolRoute(
            watch,
            'open_app',
            {'app_name': appName},
            'Open $appName',
          );
        }
        return AgentRequired(
          _lap(watch),
          reason: '"$appName" does not match an installed app; '
              'escalating to the agent.',
        );
      }

      return AgentRequired(_lap(watch), reason: 'no deterministic match');
    } catch (error) {
      // Routing must never take the app down; escalate on any surprise.
      return AgentRequired(_lap(watch), reason: 'router error: $error');
    }
  }

  Duration _lap(Stopwatch watch) {
    watch.stop();
    return watch.elapsed;
  }

  FastRouteResult _toolRoute(
    Stopwatch watch,
    String toolId,
    Map<String, dynamic> args,
    String displayIntent,
  ) {
    if (!_registry.contains(toolId)) {
      return AgentRequired(
        _lap(watch),
        reason: 'tool "$toolId" is not registered',
      );
    }
    return FastAction(
      _lap(watch),
      toolId: toolId,
      arguments: args,
      displayIntent: displayIntent,
    );
  }

  FastRouteResult _levelRoute(
    Stopwatch watch,
    String toolId,
    int level,
    String displayIntent,
  ) {
    if (level < 0 || level > 100) {
      return AgentRequired(
        _lap(watch),
        reason: 'level $level is outside the documented 0-100 range',
      );
    }
    return _toolRoute(watch, toolId, {'level': level}, displayIntent);
  }

  static int? _level(RegExpMatch? match) {
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  /// 'Open known application' rule: the target must exist among installed
  /// apps before the request is treated as deterministic. An exact name
  /// match or a single partial match counts as known; everything else
  /// escalates instead of guessing.
  Future<bool> _isKnownApp(String appName) async {
    final matches = await _appLauncher.searchApps(appName);
    if (matches.isEmpty) return false;
    for (final app in matches) {
      if (app.name.toLowerCase() == appName.toLowerCase()) return true;
    }
    return matches.length == 1;
  }
}
