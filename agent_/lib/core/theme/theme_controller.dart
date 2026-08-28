/// ThemeController - manages runtime theme mode, preset selection, and persistence
/// Uses SharedPreferences for persistence, exposes ValueNotifier for reactive updates

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cypher_theme.dart';
import 'color_tokens.dart';

/// Controller that manages theme state and persists user preferences
class ThemeController extends ChangeNotifier {
  static const _prefsKeyMode = 'cypher_theme_mode';
  static const _prefsKeyPreset = 'cypher_theme_preset';
  static const _prefsKeyGradientStyle = 'cypher_gradient_style';
  static const _prefsKeyGradientIntensity = 'cypher_gradient_intensity';
  static const _prefsKeyGradientBlur = 'cypher_gradient_blur';
  static const _prefsKeyCustomAccent = 'cypher_custom_accent';

  late SharedPreferences _prefs;
  bool _initialized = false;

  CypherThemeMode _mode = CypherThemeMode.dark;
  String _presetId = CypherThemePreset.crimsonNight.id;
  GradientStyle _gradientStyle = GradientStyle.ambient;
  GradientIntensity _gradientIntensity = GradientIntensity.subtle;
  double _gradientBlur = 100.0;
  Color? _customAccent;

  /// Current effective theme data, resolving system mode to actual brightness
  CypherThemeData? _cachedTheme;
  Brightness? _systemBrightness;

  ThemeController() {
    // Load is async; listeners will rebuild when init completes
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    // Legacy migration: installs upgrading from the pre-token theme system
    // still carry the old `themeMode` preference key.
    final storedMode = _prefs.getString(_prefsKeyMode);
    final legacyMode = _prefs.getString('themeMode');
    _mode = _parseMode(storedMode ?? legacyMode);
    _presetId = _prefs.getString(_prefsKeyPreset) ?? CypherThemePreset.crimsonNight.id;
    _gradientStyle = _parseGradientStyle(_prefs.getString(_prefsKeyGradientStyle));
    _gradientIntensity = _parseGradientIntensity(_prefs.getString(_prefsKeyGradientIntensity));
    _gradientBlur = _prefs.getDouble(_prefsKeyGradientBlur) ?? 100.0;
    final custom = _prefs.getInt(_prefsKeyCustomAccent);
    _customAccent = custom == null ? null : Color(custom);
    _initialized = true;
    _rebuildTheme();
    notifyListeners();
  }

  /// Wait for initialization to complete (call from main before runApp)
  Future<void> ensureInitialized() async {
    while (!_initialized) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  CypherThemeMode get mode => _mode;
  String get presetId => _presetId;
  GradientStyle get gradientStyle => _gradientStyle;
  GradientIntensity get gradientIntensity => _gradientIntensity;
  double get gradientBlur => _gradientBlur;

  CypherThemePreset get preset => CypherThemePreset.byId(_presetId);
  AccentFamily get accentFamily => preset.accentFamily;

  /// User-selected custom accent, if any. When non-null it overrides the
  /// preset family across colors, gradients, components, and the voice orb.
  Color? get customAccent => _customAccent;

  /// True while a custom accent (rather than a preset family) is active.
  bool get isCustomAccent => _customAccent != null;

  /// Whether the effective theme is dark (resolves system mode)
  bool get isDark {
    switch (_mode) {
      case CypherThemeMode.dark:
        return true;
      case CypherThemeMode.light:
        return false;
      case CypherThemeMode.system:
        return _systemBrightness == null || _systemBrightness == Brightness.dark;
    }
  }

  /// Current resolved theme data
  CypherThemeData get theme => _cachedTheme ?? CypherThemeData(
    isDark: true,
    accentFamily: AccentFamily.crimson,
    preset: CypherThemePreset.crimsonNight,
  );

  /// Current Material ThemeData
  ThemeData get materialTheme => theme.toMaterialTheme();

  /// Material theme resolved for a specific brightness.
  ///
  /// Used for MaterialApp's `theme`/`darkTheme` pair so `ThemeMode.system`
  /// switches correctly with platform brightness while staying derived from
  /// the active preset's tokens.
  ThemeData materialThemeFor(Brightness brightness) {
    final effective = CypherThemeData(
      isDark: brightness == Brightness.dark,
      accentFamily: accentFamily,
      preset: _buildEffectivePreset(),
      customAccent: _customAccent,
    );
    return effective.toMaterialTheme();
  }

  // ─── System brightness ─────────────────────────────────────────────────────

  void setSystemBrightness(Brightness brightness) {
    if (_systemBrightness == brightness) return;
    _systemBrightness = brightness;
    if (_mode == CypherThemeMode.system) {
      _rebuildTheme();
      notifyListeners();
    }
  }

  // ─── Setters with persistence ──────────────────────────────────────────────

  Future<void> setMode(CypherThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _prefs.setString(_prefsKeyMode, _modeToString(mode));
    _rebuildTheme();
    notifyListeners();
  }

  Future<void> setPreset(String presetId) async {
    final preset = CypherThemePreset.byId(presetId);
    _presetId = preset.id;
    // Selecting a preset deliberately replaces any custom accent.
    _customAccent = null;
    // Apply preset's gradient defaults
    _gradientStyle = preset.gradientStyle;
    _gradientIntensity = preset.gradientIntensity;
    _gradientBlur = preset.gradientBlur;
    await _prefs.setString(_prefsKeyPreset, _presetId);
    await _prefs.remove(_prefsKeyCustomAccent);
    await _prefs.setString(_prefsKeyGradientStyle, _gradientStyleToString(_gradientStyle));
    await _prefs.setString(_prefsKeyGradientIntensity, _gradientIntensityToString(_gradientIntensity));
    await _prefs.setDouble(_prefsKeyGradientBlur, _gradientBlur);
    _rebuildTheme();
    notifyListeners();
  }

  /// Applies a user-selected custom accent. Preserves the current preset's
  /// gradient style and mode — this never silently switches the preset or
  /// converts the selection into an unrelated family.
  Future<void> setCustomAccent(Color color) async {
    if (_customAccent == color) return;
    _customAccent = color;
    await _prefs.setInt(_prefsKeyCustomAccent, color.value);
    _rebuildTheme();
    notifyListeners();
  }

  /// Returns to the preset's own accent family.
  Future<void> clearCustomAccent() async {
    if (_customAccent == null) return;
    _customAccent = null;
    await _prefs.remove(_prefsKeyCustomAccent);
    _rebuildTheme();
    notifyListeners();
  }

  Future<void> setAccentFamily(AccentFamily family) async {
    // Map accent family to preset id
    final idMap = {
      AccentFamily.crimson: 'crimson_night',
      AccentFamily.burgundy: 'burgundy',
      AccentFamily.midnight: 'midnight',
      AccentFamily.ember: 'ember',
      AccentFamily.platinum: 'platinum',
      AccentFamily.obsidian: 'obsidian',
    };
    await setPreset(idMap[family] ?? 'crimson_night');
  }

  Future<void> setGradientStyle(GradientStyle style) async {
    if (_gradientStyle == style) return;
    _gradientStyle = style;
    await _prefs.setString(_prefsKeyGradientStyle, _gradientStyleToString(style));
    _rebuildTheme();
    notifyListeners();
  }

  Future<void> setGradientIntensity(GradientIntensity intensity) async {
    if (_gradientIntensity == intensity) return;
    _gradientIntensity = intensity;
    await _prefs.setString(_prefsKeyGradientIntensity, _gradientIntensityToString(intensity));
    _rebuildTheme();
    notifyListeners();
  }

  Future<void> setGradientBlur(double blur) async {
    if (_gradientBlur == blur) return;
    _gradientBlur = blur.clamp(0, 200);
    await _prefs.setDouble(_prefsKeyGradientBlur, _gradientBlur);
    _rebuildTheme();
    notifyListeners();
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  void _rebuildTheme() {
    _cachedTheme = CypherThemeData(
      isDark: isDark,
      accentFamily: accentFamily,
      preset: _buildEffectivePreset(),
      customAccent: _customAccent,
    );
  }

  CypherThemePreset _buildEffectivePreset() {
    return CypherThemePreset(
      id: preset.id,
      name: preset.name,
      description: preset.description,
      defaultMode: _mode,
      accentFamily: accentFamily,
      gradientStyle: _gradientStyle,
      gradientIntensity: _gradientIntensity,
      gradientBlur: _gradientBlur,
    );
  }

  // ─── Parsing helpers ──────────────────────────────────────────────────────

  CypherThemeMode _parseMode(String? value) {
    switch (value) {
      case 'dark':
        return CypherThemeMode.dark;
      case 'light':
        return CypherThemeMode.light;
      case 'system':
        return CypherThemeMode.system;
      default:
        return CypherThemeMode.dark;
    }
  }

  String _modeToString(CypherThemeMode mode) {
    switch (mode) {
      case CypherThemeMode.dark:
        return 'dark';
      case CypherThemeMode.light:
        return 'light';
      case CypherThemeMode.system:
        return 'system';
    }
  }

  GradientStyle _parseGradientStyle(String? value) {
    switch (value) {
      case 'ambient':
        return GradientStyle.ambient;
      case 'radial':
        return GradientStyle.radial;
      case 'linear':
        return GradientStyle.linear;
      case 'dualGlow':
        return GradientStyle.dualGlow;
      case 'subtleMesh':
        return GradientStyle.subtleMesh;
      default:
        return GradientStyle.ambient;
    }
  }

  String _gradientStyleToString(GradientStyle style) {
    switch (style) {
      case GradientStyle.ambient:
        return 'ambient';
      case GradientStyle.radial:
        return 'radial';
      case GradientStyle.linear:
        return 'linear';
      case GradientStyle.dualGlow:
        return 'dualGlow';
      case GradientStyle.subtleMesh:
        return 'subtleMesh';
    }
  }

  GradientIntensity _parseGradientIntensity(String? value) {
    switch (value) {
      case 'subtle':
        return GradientIntensity.subtle;
      case 'low':
        return GradientIntensity.low;
      case 'medium':
        return GradientIntensity.medium;
      case 'high':
        return GradientIntensity.high;
      case 'strong':
        return GradientIntensity.strong;
      default:
        return GradientIntensity.subtle;
    }
  }

  String _gradientIntensityToString(GradientIntensity intensity) {
    switch (intensity) {
      case GradientIntensity.subtle:
        return 'subtle';
      case GradientIntensity.low:
        return 'low';
      case GradientIntensity.medium:
        return 'medium';
      case GradientIntensity.high:
        return 'high';
      case GradientIntensity.strong:
        return 'strong';
    }
  }
}

/// Singleton instance for app-wide access
ThemeController? _themeControllerInstance;
ThemeController get themeController {
  _themeControllerInstance ??= ThemeController();
  return _themeControllerInstance!;
}
