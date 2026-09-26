import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for the Agent Cypher workspace bridge — the real code-editing
/// backend for Developer Mode.
///
/// ARCHITECTURE (honest boundaries):
/// An installed APK cannot and must not rewrite its own source. Developer
/// Mode therefore talks to a small bridge process running on the developer's
/// machine inside the source checkout (default `http://127.0.0.1:8791`,
/// reachable on device via `adb reverse tcp:8791 tcp:8791`). The bridge owns
/// the actual repository: it inspects the workspace, plans, edits files, and
/// runs validation. This service is a thin protocol client — no agent logic
/// lives here and nothing is faked when the bridge is absent.
///
/// Protocol:
///   GET  /health          -> {available, root, project}
///   POST /plan  {request} -> {id, summary, files:[{path, change}], risk}
///   POST /apply {id}      -> {ok, report, changedFiles, validation:{analyzer, tests, format}, error?}
///   POST /cancel {id}     -> {ok}
class WorkspaceAgentService {
  WorkspaceAgentService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Default bridge endpoint. 127.0.0.1 works with `adb reverse`.
  static const String defaultBaseUrl = 'http://127.0.0.1:8791';

  String baseUrl = defaultBaseUrl;

  static const Duration _probeTimeout = Duration(seconds: 3);
  static const Duration _planTimeout = Duration(seconds: 60);
  static const Duration _applyTimeout = Duration(minutes: 10);

  /// The developer workspace, when the bridge reports it.
  String? workspaceRoot;

  /// Connection check. Returns null when the bridge is reachable, otherwise a
  /// short human-readable reason why it is not.
  Future<String?> probeUnavailableReason() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_probeTimeout);
      if (res.statusCode != 200) {
        return 'Bridge responded with HTTP ${res.statusCode}.';
      }
      final body = jsonDecode(res.body);
      if (body is Map && body['available'] == true) {
        workspaceRoot = body['root']?.toString();
        return null;
      }
      return 'Bridge reported its workspace is not available.';
    } on TimeoutException {
      return 'Workspace bridge did not respond in ${_probeTimeout.inSeconds}s.';
    } catch (_) {
      return 'No workspace bridge at $baseUrl. Start it in your source '
          'checkout and run: adb reverse tcp:8791 tcp:8791';
    }
  }

  /// Asks the bridge to inspect the workspace and plan the requested change.
  /// Path discovery, file selection, and step planning happen on the bridge —
  /// the user is never asked for paths.
  Future<WorkspacePlan> plan(String request) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/plan'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'request': request}),
        )
        .timeout(_planTimeout);
    return _decodePlan(res);
  }

  /// Applies the previously planned change and runs local validation
  /// (format / analyzer / tests as available). Only call after an explicit
  /// user confirmation.
  Future<WorkspaceRunReport> apply(String planId) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/apply'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'id': planId}),
        )
        .timeout(_applyTimeout);
    return _decodeReport(res);
  }

  /// Best-effort cancel of an in-flight bridge operation.
  Future<void> cancel(String planId) async {
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/cancel'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id': planId}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Cancellation is advisory; the report path still surfaces the outcome.
    }
  }

  WorkspacePlan _decodePlan(http.Response res) {
    final body = _decodeBody(res);
    final id = body['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const WorkspaceAgentException(
          'Bridge returned a plan without an id.');
    }
    final files = (body['files'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((f) => PlannedFile(
              path: f['path']?.toString() ?? '',
              change: f['change']?.toString() ?? '',
            ))
        .where((f) => f.path.isNotEmpty)
        .toList();
    return WorkspacePlan(
      id: id,
      summary: body['summary']?.toString() ?? '',
      files: files,
      risk: body['risk']?.toString() ?? '',
    );
  }

  WorkspaceRunReport _decodeReport(http.Response res) {
    final body = _decodeBody(res);
    final validationRaw = body['validation'];
    final validation = validationRaw is Map
        ? WorkspaceValidation(
            analyzer: validationRaw['analyzer']?.toString() ?? 'not run',
            tests: validationRaw['tests']?.toString() ?? 'not run',
            format: validationRaw['format']?.toString() ?? 'not run',
          )
        : const WorkspaceValidation(
            analyzer: 'not run', tests: 'not run', format: 'not run');
    return WorkspaceRunReport(
      ok: body['ok'] == true,
      report: body['report']?.toString() ?? '',
      changedFiles: (body['changedFiles'] as List<dynamic>? ?? const [])
          .map((f) => f.toString())
          .toList(),
      validation: validation,
      error: body['error']?.toString(),
    );
  }

  Map<String, dynamic> _decodeBody(http.Response res) {
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw const WorkspaceAgentException(
          'Bridge returned an unexpected payload.');
    }
    if (res.statusCode >= 400) {
      throw WorkspaceAgentException(
        decoded['error']?.toString() ??
            'Bridge request failed (HTTP ${res.statusCode}).',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }
}

class WorkspaceAgentException implements Exception {
  const WorkspaceAgentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A planned change: what the bridge intends to do, before anything is edited.
class WorkspacePlan {
  const WorkspacePlan({
    required this.id,
    required this.summary,
    required this.files,
    required this.risk,
  });

  final String id;
  final String summary;
  final List<PlannedFile> files;
  final String risk;
}

class PlannedFile {
  const PlannedFile({required this.path, required this.change});
  final String path;
  final String change;
}

/// Validation results as actually measured on the workspace machine.
class WorkspaceValidation {
  const WorkspaceValidation({
    required this.analyzer,
    required this.tests,
    required this.format,
  });

  final String analyzer;
  final String tests;
  final String format;

  bool get allPassed =>
      analyzer == 'pass' && tests == 'pass' && format == 'pass';
}

/// Outcome of a full plan → apply → validate run.
class WorkspaceRunReport {
  const WorkspaceRunReport({
    required this.ok,
    required this.report,
    required this.changedFiles,
    required this.validation,
    this.error,
  });

  final bool ok;
  final String report;
  final List<String> changedFiles;
  final WorkspaceValidation validation;
  final String? error;
}
