import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/cypher_theme.dart';
import '../core/theme/color_tokens.dart';
import '../core/theme/theme_controller.dart';

/// Agent Cypher Premium Design System - compatibility layer.
/// Delegates to the token-based theme system (lib/core/theme) while preserving
/// the legacy `AgentCypherTheme` surface and the app-level `themeNotifier`.
class AgentCypherTheme {
  // Backwards-compatible static color constants (legacy palette)
  // Light Mode Colors
  static const Color lightBg = Color(0xFFF7F3EE);
  static const Color lightSurface = Color(0xFFF0EBE3);
  static const Color lightSurfaceAlt = Color(0xFFE8E1D6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1C1917);
  static const Color lightTextSecondary = Color(0xFF57534E);
  static const Color lightBorder = Color(0xFFB8B0A6);
  static const Color lightAccent = Color(0xFF3D3833);
  static const Color lightGlass = Color(0xFFD6CFC4);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF1C1917);
  static const Color darkSurface = Color(0xFF252220);
  static const Color darkSurfaceAlt = Color(0xFF2E2A27);
  static const Color darkCard = Color(0xFF3D3833);
  static const Color darkText = Color(0xFFF0EBE3);
  static const Color darkTextSecondary = Color(0xFFB8B0A6);
  static const Color darkBorder = Color(0xFF57534E);
  static const Color darkAccent = Color(0xFF8C857D);
  static const Color darkGlass = Color(0xFFD6CFC4);

  /// Build the token-backed theme, draining to the active preset.
  static ThemeData buildTheme() => themeController.materialTheme;

  static ThemeData lightTheme() {
    return themeController.materialTheme;
  }

  static ThemeData darkTheme() {
    return themeController.materialTheme;
  }

  /// The effective theme data from the controller (token-based).
  static CypherThemeData cypher() => themeController.theme;

  /// Convenience: current active preset id.
  static String get presetId => themeController.presetId;
}

/// App-level theme mode notifier - kept for backward compatibility with
/// screens that listen to `themeNotifier`, and kept in sync with the
/// ThemeController.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

/// Bridge ThemeController (token system) with the legacy `themeNotifier`.
/// Call once at startup after ThemeController initialization.
Future<void> syncThemeNotifier() async {
  final controller = themeController;
  await controller.ensureInitialized();

  // Copy mode from controller into the legacy notifier.
  switch (controller.mode) {
    case CypherThemeMode.dark:
      themeNotifier.value = ThemeMode.dark;
    case CypherThemeMode.light:
      themeNotifier.value = ThemeMode.light;
    case CypherThemeMode.system:
      themeNotifier.value = ThemeMode.system;
  }

  // Keep them in sync both ways.
  themeController.addListener(_pushToLegacy);
  themeNotifier.addListener(_pullFromLegacy);
}

void _pushToLegacy() {
  switch (themeController.mode) {
    case CypherThemeMode.dark:
      themeNotifier.value = ThemeMode.dark;
    case CypherThemeMode.light:
      themeNotifier.value = ThemeMode.light;
    case CypherThemeMode.system:
      themeNotifier.value = ThemeMode.system;
  }
}

void _pullFromLegacy() {
  switch (themeNotifier.value) {
    case ThemeMode.dark:
      themeController.setMode(CypherThemeMode.dark);
    case ThemeMode.light:
      themeController.setMode(CypherThemeMode.light);
    case ThemeMode.system:
      themeController.setMode(CypherThemeMode.system);
  }
}

/// Persist the chosen ThemeMode the way the legacy settings screen did,
/// then apply it through the controller.
Future<void> applyThemeMode(ThemeMode mode) async {
  themeController.setMode(_toCypherMode(mode));
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('themeMode', _toPrefs(mode));
}

CypherThemeMode _toCypherMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return CypherThemeMode.dark;
    case ThemeMode.light:
      return CypherThemeMode.light;
    case ThemeMode.system:
      return CypherThemeMode.system;
  }
}

String _toPrefs(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.system:
      return 'system';
  }
}