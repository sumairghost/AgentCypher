import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Events emitted by the embedded 4AIs/OpenClaw agent core.
sealed class AgentCoreEvent {
  const AgentCoreEvent();
}

/// A streamed chunk of the agent turn (text, tool calls, lifecycle, usage).
class AgentCoreChunk extends AgentCoreEvent {
  final String kind; // text | toolStart | toolResult | lifecycle | error | usage | done
  final String text;
  final String callId;
  final String name;
  final String argsJson;
  final bool ok;
  final String phase; // lifecycle phase from the openclaw "agent" event
  final bool recoverable;
  final int inputTokens;
  final int outputTokens;

  const AgentCoreChunk({
    required this.kind,
    this.text = '',
    this.callId = '',
    this.name = '',
    this.argsJson = '',
    this.ok = false,
    this.phase = '',
    this.recoverable = false,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });
}

/// Gateway lifecycle (stopped/starting/running/failed).
class AgentCoreGateway extends AgentCoreEvent {
  final String state;
  final int port;
  final String error;
  const AgentCoreGateway({required this.state, this.port = 0, this.error = ''});
}

/// First-run bootstrap progress (Node runtime + gateway install on device).
class AgentCoreBootstrap extends AgentCoreEvent {
  final String state;
  final double progress;
  final String step;
  final String line;
  final String error;
  const AgentCoreBootstrap({
    required this.state,
    this.progress = 0,
    this.step = '',
    this.line = '',
    this.error = '',
  });
}

/// A risk-graded approval request from the agent (exec/plugin).
class AgentCoreApproval extends AgentCoreEvent {
  final String id;
  final String kind;
  final String summary;
  final String detail;
  final String riskLevel;
  final String riskCategory;
  const AgentCoreApproval({
    required this.id,
    required this.kind,
    required this.summary,
    required this.detail,
    required this.riskLevel,
    this.riskCategory = '',
  });
}

/// Terminal state of a submitted task turn.
class AgentCoreTaskState extends AgentCoreEvent {
  final String state; // done | cancelled | failed
  final String error;
  const AgentCoreTaskState({required this.state, this.error = ''});
}

/// One model provider from the native catalog (NVIDIA/OpenAI/Anthropic/Gemini).
class CoreProvider {
  final String id;
  final String displayName;
  final String keyLabel;
  final String keyHint;
  final String consoleUrl;
  final bool freeTier;
  final bool hasKey;
  final bool selected;
  final List<CoreModel> models;

  const CoreProvider({
    required this.id,
    required this.displayName,
    required this.keyLabel,
    required this.keyHint,
    required this.consoleUrl,
    required this.freeTier,
    required this.hasKey,
    required this.selected,
    required this.models,
  });
}

class CoreModel {
  final String id;
  final String displayName;
  final bool reasoning;
  const CoreModel({required this.id, required this.displayName, required this.reasoning});
}

/// Thin client for the embedded 4AIs/OpenClaw agent core.
///
/// The native side (com.crsk.openclaw.cypher.CypherAgentCore) is the source of
/// truth for execution; this class only forwards requests and streams events.
class NativeAgentCore {
  static const MethodChannel _method = MethodChannel(
    'com.cypherghost.agentcypher/agentcore',
  );
  static const EventChannel _events = EventChannel(
    'com.cypherghost.agentcypher/agentcore_events',
  );

  final StreamController<AgentCoreEvent> _controller =
      StreamController<AgentCoreEvent>.broadcast();
  StreamSubscription<dynamic>? _sub;
  bool _listening = false;

  /// Broadcast stream of everything the core emits while the UI is alive.
  Stream<AgentCoreEvent> get events => _controller.stream;

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _sub = _events.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is! Map) return;
        _controller.add(_parseEvent(data.cast<String, dynamic>()));
      },
      onError: (Object error) {
        debugPrint('AgentCore event stream error: $error');
      },
      cancelOnError: false,
    );
  }

  AgentCoreEvent _parseEvent(Map<String, dynamic> data) {
    switch (data['type'] as String? ?? '') {
      case 'gateway':
        return AgentCoreGateway(
          state: data['state'] as String? ?? 'unknown',
          port: (data['port'] as num?)?.toInt() ?? 0,
          error: data['error'] as String? ?? '',
        );
      case 'bootstrap':
        return AgentCoreBootstrap(
          state: data['state'] as String? ?? '',
          progress: (data['progress'] as num?)?.toDouble() ?? 0,
          step: data['step'] as String? ?? '',
          line: data['line'] as String? ?? '',
          error: data['error'] as String? ?? '',
        );
      case 'approval':
        return AgentCoreApproval(
          id: data['id'] as String? ?? '',
          kind: data['kind'] as String? ?? 'Exec',
          summary: data['summary'] as String? ?? '',
          detail: data['detail'] as String? ?? '',
          riskLevel: data['riskLevel'] as String? ?? 'Low',
          riskCategory: data['riskCategory'] as String? ?? '',
        );
      case 'task':
        return AgentCoreTaskState(
          state: data['state'] as String? ?? '',
          error: data['error'] as String? ?? '',
        );
      default:
        return AgentCoreChunk(
          kind: data['kind'] as String? ?? '',
          text: data['text'] as String? ?? '',
          callId: data['callId'] as String? ?? '',
          name: data['name'] as String? ?? '',
          argsJson: data['argsJson'] as String? ?? '',
          ok: data['ok'] as bool? ?? false,
          phase: data['phase'] as String? ?? '',
          recoverable: data['recoverable'] as bool? ?? false,
          inputTokens: (data['inputTokens'] as num?)?.toInt() ?? 0,
          outputTokens: (data['outputTokens'] as num?)?.toInt() ?? 0,
        );
    }
  }

  /// True when the on-device Node runtime + gateway have been provisioned.
  Future<bool> isBootstrapped() async {
    try {
      return await _method.invokeMethod<bool>('isBootstrapped') ?? false;
    } on Exception {
      return false;
    }
  }

  /// True when the 4AIs accessibility service ("hands") is enabled.
  Future<bool> isAccessibilityEnabled() async {
    try {
      return await _method.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } on Exception {
      return false;
    }
  }

  Future<Map<String, dynamic>> gatewayStatus() async {
    try {
      final raw = await _method.invokeMethod<Map<dynamic, dynamic>>('gatewayStatus');
      return raw?.cast<String, dynamic>() ?? <String, dynamic>{'state': 'unknown'};
    } on Exception {
      return <String, dynamic>{'state': 'unavailable'};
    }
  }

  /// Starts the foreground gateway service and waits for a terminal state.
  Future<Map<String, dynamic>?> startGateway() async {
    try {
      _ensureListening();
      final raw = await _method
          .invokeMethod<Map<dynamic, dynamic>>('startGateway')
          .timeout(const Duration(seconds: 180));
      return raw?.cast<String, dynamic>();
    } on Exception catch (error) {
      debugPrint('startGateway failed: $error');
      return null;
    }
  }

  /// Kicks off the on-device bootstrap (Node install + gateway provisioning).
  Future<bool> bootstrap() async {
    try {
      _ensureListening();
      await _method.invokeMethod<dynamic>('bootstrap');
      return true;
    } on Exception catch (error) {
      debugPrint('bootstrap failed: $error');
      return false;
    }
  }

  /// Submits a task message to the agent core (4AIs agent turn).
  Future<bool> submitTask(String message) async {
    try {
      _ensureListening();
      await _method.invokeMethod<dynamic>(
        'submitTask',
        <String, dynamic>{'message': message},
      );
      return true;
    } on Exception catch (error) {
      debugPrint('submitTask failed: $error');
      return false;
    }
  }

  /// Client-side cancellation of the current agent turn (mirrors the 4AIs
  /// Compose UI stop path: detach + overlay stop notification).
  Future<void> cancelTask() async {
    try {
      await _method.invokeMethod<dynamic>('cancelTask');
    } on Exception catch (error) {
      debugPrint('cancelTask failed: $error');
    }
  }

  Future<List<CoreProvider>> listProviders() async {
    try {
      final raw = await _method.invokeMethod<List<dynamic>>('listProviders');
      return (raw ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map(_parseProvider)
          .toList();
    } on Exception catch (error) {
      debugPrint('listProviders failed: $error');
      return const [];
    }
  }

  CoreProvider _parseProvider(Map<dynamic, dynamic> m) {
    final map = m.cast<String, dynamic>();
    return CoreProvider(
      id: map['id'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      keyLabel: map['keyLabel'] as String? ?? '',
      keyHint: map['keyHint'] as String? ?? '',
      consoleUrl: map['consoleUrl'] as String? ?? '',
      freeTier: map['freeTier'] as bool? ?? false,
      hasKey: map['hasKey'] as bool? ?? false,
      selected: map['selected'] as bool? ?? false,
      models: ((map['models'] as List<dynamic>?) ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map((mm) => mm.cast<String, dynamic>())
          .map(
            (mm) => CoreModel(
              id: mm['id'] as String? ?? '',
              displayName: mm['displayName'] as String? ?? '',
              reasoning: mm['reasoning'] as bool? ?? false,
            ),
          )
          .toList(),
    );
  }

  /// Stores a provider API key in the native encrypted keystore.
  Future<bool> setProviderKey(String providerId, String key) async {
    try {
      await _method.invokeMethod<dynamic>(
        'setProviderKey',
        <String, dynamic>{'providerId': providerId, 'key': key},
      );
      return true;
    } on Exception catch (error) {
      debugPrint('setProviderKey failed: $error');
      return false;
    }
  }

  /// Resolves a pending approval (allow=true → the action may run).
  Future<bool> resolveApproval(String id, {bool allow = false}) async {
    try {
      await _method.invokeMethod<dynamic>(
        'resolveApproval',
        <String, dynamic>{'id': id, 'kind': 'Exec', 'allow': allow},
      );
      return true;
    } on Exception {
      return false;
    }
  }

  /// Opens the 4AIs Compose setup/console (bootstrap wizard, gateway status).
  Future<void> openCoreSetup() async {
    try {
      await _method.invokeMethod<dynamic>('openCoreSetup');
    } on Exception catch (error) {
      debugPrint('openCoreSetup failed: $error');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
    unawaited(_controller.close());
  }
}
