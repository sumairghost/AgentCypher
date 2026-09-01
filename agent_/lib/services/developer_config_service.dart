import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ui/orb_config.dart';

/// Pure seven-tap developer-mode activation logic (no I/O, fully testable).
///
/// Mirrors the familiar Android "tap build number 7 times" interaction:
/// - taps closer than [minTapGap] are debounced (one physical tap must never
///   count twice);
/// - a gap longer than [maxTapGap] resets the counter (no accidental
///   activation from sparse taps or normal scrolling — scrolling never
///   produces tap events anyway, but the timeout adds safety);
/// - the 7th valid tap activates;
/// - the caller surfaces progress feedback ("N steps away…") from the
///   returned [DeveloperTapProgress].
class DeveloperTapActivator {
  static const int requiredTaps = 7;
  static const Duration minTapGap = Duration(milliseconds: 80);
  static const Duration maxTapGap = Duration(milliseconds: 1800);

  int _count = 0;
  DateTime? _lastTapAt;

  /// Valid taps registered so far in the current sequence.
  int get count => _count;

  /// Remaining taps before activation (0 when already activated/reset).
  int get remaining =>
      _count >= requiredTaps ? 0 : requiredTaps - _count;

  /// Whether feedback should be shown for the current count (from the 3rd tap
  /// on, matching Android's "you are N steps away" behavior).
  bool get shouldGiveFeedback => _count >= 3 && _count < requiredTaps;

  void reset() {
    _count = 0;
    _lastTapAt = null;
  }

  /// Registers a tap at [now] and returns the resulting progress.
  DeveloperTapProgress registerTap(DateTime now) {
    final last = _lastTapAt;
    _lastTapAt = now;
    if (last != null) {
      final gap = now.difference(last);
      // Debounce: same physical tap registered twice (e.g. synthesis quirks).
      if (gap < minTapGap) {
        return DeveloperTapProgress(
          count: _count,
          activated: false,
          rejected: true,
          reset: false,
        );
      }
      // Inactivity timeout: a fresh sequence starts.
      if (gap > maxTapGap) {
        _count = 0;
      }
    }
    _count++;
    return DeveloperTapProgress(
      count: _count,
      activated: _count >= requiredTaps,
      rejected: false,
      reset: false,
    );
  }
}

/// Immutable result of one [DeveloperTapActivator.registerTap] call.
class DeveloperTapProgress {
  final int count;
  final bool activated;
  final bool rejected;

  /// True when the sequence was reset by the inactivity timeout before this
  /// tap was counted.
  final bool reset;

  const DeveloperTapProgress({
    required this.count,
    required this.activated,
    required this.rejected,
    required this.reset,
  });
}

/// Persistence for developer-only configuration.
///
/// Deliberately separate from user settings: nothing here affects the normal
/// application experience, and [resetDeveloperConfiguration] only clears
/// `dev_*` keys plus the developer-mode flag.
class CypherDeveloperConfig extends ChangeNotifier {
  CypherDeveloperConfig._();

  static final CypherDeveloperConfig instance = CypherDeveloperConfig._();

  static const _keyDevMode = 'developer_mode_enabled'; // legacy-compat key
  static const _keyOrbProfiles = 'dev_orb_profiles';
  static const _keyOrbLabConfig = 'dev_orb_lab_config';
  static const _keyCodeSessions = 'dev_code_agent_sessions';
  static const _keyExpensiveDiagnostics = 'dev_expensive_diagnostics';

  SharedPreferences? _prefs;
  Completer<void>? _initCompleter;

  bool _developerModeEnabled = false;
  List<CypherOrbProfile> _orbProfiles = const <CypherOrbProfile>[];
  CypherOrbConfig? _orbLabConfig;
  List<Map<String, dynamic>> _codeAgentSessions =
      const <Map<String, dynamic>>[];
  bool _expensiveDiagnosticsEnabled = false;

  // ─── State ────────────────────────────────────────────────────────────────

  bool get developerModeEnabled => _developerModeEnabled;
  List<CypherOrbProfile> get orbProfiles =>
      List<CypherOrbProfile>.unmodifiable(_orbProfiles);
  CypherOrbConfig? get orbLabConfig => _orbLabConfig;
  List<Map<String, dynamic>> get codeAgentSessions =>
      List<Map<String, dynamic>>.unmodifiable(_codeAgentSessions);
  bool get expensiveDiagnosticsEnabled => _expensiveDiagnosticsEnabled;

  /// Adopts the provided prefs synchronously and resets all state.
  /// Used by tests to isolate each test from the process-wide singleton.
  @visibleForTesting
  void resetForTesting(SharedPreferences prefs) {
    _initCompleter ??= Completer<void>();
    if (!(_initCompleter!.isCompleted)) {
      _initCompleter!.complete();
    }
    _prefs = prefs;
    _developerModeEnabled = prefs.getBool(_keyDevMode) ?? false;
    _expensiveDiagnosticsEnabled =
        prefs.getBool(_keyExpensiveDiagnostics) ?? false;
    _orbProfiles = _decodeOrbProfiles(prefs.getString(_keyOrbProfiles));
    final lab = prefs.getString(_keyOrbLabConfig);
    if (lab != null) {
      try {
        _orbLabConfig =
            CypherOrbConfig.fromJson(jsonDecode(lab) as Map<String, dynamic>);
      } catch (_) {
        _orbLabConfig = null;
      }
    } else {
      _orbLabConfig = null;
    }
    _codeAgentSessions = _decodeSessions(prefs.getString(_keyCodeSessions));
    notifyListeners();
  }
  /// Waits until persisted values are loaded.
  Future<void> ensureInitialized() {
    _initCompleter ??= _init();
    return _initCompleter!.future;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _developerModeEnabled = _prefs!.getBool(_keyDevMode) ?? false;
    _expensiveDiagnosticsEnabled =
        _prefs!.getBool(_keyExpensiveDiagnostics) ?? false;
    _orbProfiles = _decodeOrbProfiles(_prefs!.getString(_keyOrbProfiles));
    final lab = _prefs!.getString(_keyOrbLabConfig);
    if (lab != null) {
      try {
        _orbLabConfig = CypherOrbConfig.fromJson(
          jsonDecode(lab) as Map<String, dynamic>,
        );
      } catch (_) {
        _orbLabConfig = null; // corrupt dev data must never break the app
      }
    }
    _codeAgentSessions = _decodeSessions(_prefs!.getString(_keyCodeSessions));
    notifyListeners();
  }

  List<CypherOrbProfile> _decodeOrbProfiles(String? raw) {
    if (raw == null || raw.isEmpty) return const <CypherOrbProfile>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CypherOrbProfile.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <CypherOrbProfile>[];
    }
  }

  List<Map<String, dynamic>> _decodeSessions(String? raw) {
    if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  SharedPreferences get _store {
    final p = _prefs;
    if (p == null) {
      throw StateError(
        'CypherDeveloperConfig not initialized; call ensureInitialized() first',
      );
    }
    return p;
  }

  // ─── Developer mode flag ──────────────────────────────────────────────────

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    if (_developerModeEnabled == enabled) return;
    _developerModeEnabled = enabled;
    await _store.setBool(_keyDevMode, enabled);
    if (!enabled) {
      // Disabling developer mode also resets any in-flight tap sequence data.
      await _store.remove('developer_taps');
    }
    notifyListeners();
  }

  // ─── Orb profiles (Phase 6) ───────────────────────────────────────────────

  Future<void> saveOrbProfile(CypherOrbProfile profile) async {
    final existing = _orbProfiles.indexWhere((p) => p.id == profile.id);
    final next = List<CypherOrbProfile>.from(_orbProfiles);
    if (existing >= 0) {
      next[existing] = profile;
    } else {
      next.add(profile);
    }
    _orbProfiles = List<CypherOrbProfile>.unmodifiable(next);
    await _store.setString(
      _keyOrbProfiles,
      jsonEncode(_orbProfiles.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> deleteOrbProfile(String id) async {
    final next = _orbProfiles.where((p) => p.id != id).toList();
    if (next.length == _orbProfiles.length) return;
    _orbProfiles = List<CypherOrbProfile>.unmodifiable(next);
    await _store.setString(
      _keyOrbProfiles,
      jsonEncode(_orbProfiles.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> setOrbLabConfig(CypherOrbConfig? config) async {
    _orbLabConfig = config;
    if (config == null) {
      await _store.remove(_keyOrbLabConfig);
    } else {
      await _store.setString(_keyOrbLabConfig, jsonEncode(config.toJson()));
    }
    notifyListeners();
  }

  // ─── Code Agent sessions (Phase 7) ────────────────────────────────────────

  Future<void> saveCodeAgentSession(Map<String, dynamic> session) async {
    final id = session['id'] as String?;
    final next = List<Map<String, dynamic>>.from(_codeAgentSessions);
    final index =
        id == null ? -1 : next.indexWhere((s) => s['id'] == id);
    if (index >= 0) {
      next[index] = session;
    } else {
      next.insert(0, session);
    }
    // Bounded history: keep the 20 most recent sessions.
    while (next.length > 20) {
      next.removeLast();
    }
    _codeAgentSessions = List<Map<String, dynamic>>.unmodifiable(next);
    await _store.setString(_keyCodeSessions, jsonEncode(next));
    notifyListeners();
  }

  Future<void> deleteCodeAgentSession(String id) async {
    final next = _codeAgentSessions.where((s) => s['id'] != id).toList();
    if (next.length == _codeAgentSessions.length) return;
    _codeAgentSessions = List<Map<String, dynamic>>.unmodifiable(next);
    await _store.setString(_keyCodeSessions, jsonEncode(next));
    notifyListeners();
  }

  // ─── Expensive diagnostics opt-in (Phase 19) ──────────────────────────────

  Future<void> setExpensiveDiagnosticsEnabled(bool enabled) async {
    if (_expensiveDiagnosticsEnabled == enabled) return;
    _expensiveDiagnosticsEnabled = enabled;
    await _store.setBool(_keyExpensiveDiagnostics, enabled);
    notifyListeners();
  }

  // ─── Reset (Phase 4 quick action / reset page) ────────────────────────────

  /// Clears ALL developer-only configuration. Never touches user data.
  Future<void> resetDeveloperConfiguration() async {
    await _store.remove(_keyOrbProfiles);
    await _store.remove(_keyOrbLabConfig);
    await _store.remove(_keyCodeSessions);
    await _store.remove(_keyExpensiveDiagnostics);
    await _store.remove(_keyDevMode);
    await _store.remove('developer_taps');
    _developerModeEnabled = false;
    _orbProfiles = const <CypherOrbProfile>[];
    _orbLabConfig = null;
    _codeAgentSessions = const <Map<String, dynamic>>[];
    _expensiveDiagnosticsEnabled = false;
    notifyListeners();
  }
}

/// Global accessor (the config is process-wide developer state).
CypherDeveloperConfig get developerConfig => CypherDeveloperConfig.instance;

