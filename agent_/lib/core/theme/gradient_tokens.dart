/// Gradient tokens for Agent Cypher design system
/// Background gradients, accent gradients, glass gradients

import 'dart:ui';
import 'package:flutter/material.dart';
import 'color_tokens.dart';

/// Gradient style variants for background
enum GradientStyle {
  /// Subtle ambient glow - distant colored light behind smoked glass
  ambient,

  /// Radial gradient from center
  radial,

  /// Linear gradient (top to bottom)
  linear,

  /// Dual glow - two radial glows at opposite corners
  dualGlow,

  /// Subtle mesh-like gradient
  subtleMesh,
}

/// Gradient intensity levels
enum GradientIntensity {
  subtle(0.15),
  low(0.25),
  medium(0.35),
  high(0.5),
  strong(0.7);

  const GradientIntensity(this.opacityMultiplier);
  final double opacityMultiplier;
}

/// Gradient configuration for theme
class CypherGradientConfig {
  final GradientStyle style;
  final GradientIntensity intensity;
  final double blur;
  final AlignmentGeometry position;
  final AccentFamily accentFamily;

  /// When non-null, gradients derive from this user-selected custom accent
  /// instead of the preset family ramp.
  final Color? customAccent;

  const CypherGradientConfig({
    this.style = GradientStyle.ambient,
    this.intensity = GradientIntensity.subtle,
    this.blur = 100.0,
    this.position = Alignment.center,
    this.accentFamily = AccentFamily.crimson,
    this.customAccent,
  });

  CypherGradientConfig copyWith({
    GradientStyle? style,
    GradientIntensity? intensity,
    double? blur,
    AlignmentGeometry? position,
    AccentFamily? accentFamily,
    Color? customAccent,
  }) {
    return CypherGradientConfig(
      style: style ?? this.style,
      intensity: intensity ?? this.intensity,
      blur: blur ?? this.blur,
      position: position ?? this.position,
      accentFamily: accentFamily ?? this.accentFamily,
      customAccent: customAccent ?? this.customAccent,
    );
  }
}

/// Gradient token generator
class CypherGradientTokens {
  final bool isDark;
  final CypherGradientConfig config;

  const CypherGradientTokens({
    required this.isDark,
    required this.config,
  });

  /// Accent ramp: custom user color wins when set, otherwise the preset family.
  Map<int, Color> get _accentMap => config.customAccent == null
      ? config.accentFamily.colors
      : CypherColorPalette.shadeRamp(config.customAccent!);

  /// Get the base accent color for gradients
  Color get _accentColor {
    final palette = _accentMap;
    return isDark ? palette[400]! : palette[600]!;
  }

  /// Public accent color for sibling token libraries (`glass_tokens.dart`
  /// cannot read the library-private `_accentColor`).
  Color get accentColor => _accentColor;

  Color get _accentColorLight {
    final palette = _accentMap;
    return isDark ? palette[300]! : palette[500]!;
  }

  Color get _accentColorMuted {
    final palette = _accentMap;
    return isDark ? palette[200]! : palette[400]!;
  }

  double get _intensity => config.intensity.opacityMultiplier;
  double get _blur => config.blur;

  /// Main background gradient
  Gradient get backgroundGradient {
    switch (config.style) {
      case GradientStyle.ambient:
        return _ambientGradient();
      case GradientStyle.radial:
        return _radialGradient();
      case GradientStyle.linear:
        return _linearGradient();
      case GradientStyle.dualGlow:
        return _dualGlowGradient();
      case GradientStyle.subtleMesh:
        return _subtleMeshGradient();
    }
  }

  /// Subtle ambient glow - like distant colored light diffused behind smoked glass
  LinearGradient _ambientGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        isDark
            ? CypherColorPalette.charcoal600
            : CypherColorPalette.warmWhite100,
        isDark
            ? CypherColorPalette.charcoal500.withOpacity(0.98)
            : CypherColorPalette.warmWhite200.withOpacity(0.98),
        isDark
            ? CypherColorPalette.charcoal400.withOpacity(0.95)
            : CypherColorPalette.warmWhite300.withOpacity(0.95),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// Radial gradient from center with accent glow
  RadialGradient _radialGradient() {
    final accent = _accentColor.withOpacity(0.08 * _intensity);
    final accentLight = _accentColorLight.withOpacity(0.05 * _intensity);

    return RadialGradient(
      center: config.position as Alignment,
      radius: 1.5,
      colors: [
        isDark ? CypherColorPalette.charcoal600 : CypherColorPalette.warmWhite100,
        isDark
            ? CypherColorPalette.charcoal500.withOpacity(0.98)
            : CypherColorPalette.warmWhite200.withOpacity(0.98),
        isDark
            ? CypherColorPalette.charcoal400.withOpacity(0.92)
            : CypherColorPalette.warmWhite300.withOpacity(0.92),
      ],
      stops: const [0.0, 0.4, 1.0],
      focal: config.position as Alignment,
      focalRadius: 0.3,
    );
  }

  /// Linear gradient top to bottom
  LinearGradient _linearGradient() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        isDark
            ? CypherColorPalette.charcoal600
            : CypherColorPalette.warmWhite100,
        isDark
            ? CypherColorPalette.charcoal500.withOpacity(0.97)
            : CypherColorPalette.warmWhite200.withOpacity(0.97),
        isDark
            ? CypherColorPalette.charcoal400.withOpacity(0.93)
            : CypherColorPalette.warmWhite300.withOpacity(0.93),
      ],
      stops: const [0.0, 0.4, 1.0],
    );
  }

  /// Dual glow - two radial glows at opposite corners
  LinearGradient _dualGlowGradient() {
    // This creates a dual-glow effect using a linear gradient with stops
    // that simulate two radial sources
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        isDark
            ? CypherColorPalette.charcoal600
            : CypherColorPalette.warmWhite100,
        isDark
            ? _accentColorMuted.withOpacity(0.06 * _intensity)
            : _accentColorMuted.withOpacity(0.04 * _intensity),
        isDark
            ? CypherColorPalette.charcoal500.withOpacity(0.98)
            : CypherColorPalette.warmWhite200.withOpacity(0.98),
        isDark
            ? _accentColorMuted.withOpacity(0.06 * _intensity)
            : _accentColorMuted.withOpacity(0.04 * _intensity),
        isDark
            ? CypherColorPalette.charcoal400.withOpacity(0.93)
            : CypherColorPalette.warmWhite300.withOpacity(0.93),
      ],
      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
    );
  }

  /// Subtle mesh-like gradient with multiple color stops
  LinearGradient _subtleMeshGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        isDark ? CypherColorPalette.charcoal600 : CypherColorPalette.warmWhite100,
        isDark
            ? _accentColor.withOpacity(0.03 * _intensity)
            : _accentColor.withOpacity(0.02 * _intensity),
        isDark
            ? CypherColorPalette.charcoal500.withOpacity(0.98)
            : CypherColorPalette.warmWhite200.withOpacity(0.98),
        isDark
            ? _accentColorLight.withOpacity(0.02 * _intensity)
            : _accentColorLight.withOpacity(0.015 * _intensity),
        isDark
            ? CypherColorPalette.charcoal400.withOpacity(0.95)
            : CypherColorPalette.warmWhite300.withOpacity(0.95),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
  }

  /// Accent gradient for buttons, highlights
  LinearGradient get accentGradient => LinearGradient(
    colors: [
      _accentColor,
      _accentColorLight,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Glass surface gradient (subtle inner glow)
  LinearGradient get glassGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      isDark
          ? Colors.white.withOpacity(0.12)
          : Colors.black.withOpacity(0.06),
      isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.02),
      Colors.transparent,
      isDark
          ? _accentColor.withOpacity(0.03 * _intensity)
          : _accentColor.withOpacity(0.02 * _intensity),
    ],
    stops: const [0.0, 0.3, 0.7, 1.0],
  );

  /// Pressed state gradient
  LinearGradient get pressedGradient => LinearGradient(
    colors: [
      _accentColor.withOpacity(0.9),
      _accentColorLight.withOpacity(0.8),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Focus ring gradient
  RadialGradient get focusGradient => RadialGradient(
    colors: [
      _accentColor.withOpacity(0.4),
      _accentColor.withOpacity(0.1),
      Colors.transparent,
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  /// Success gradient
  LinearGradient get successGradient => LinearGradient(
    colors: [
      CypherColorPalette.success500,
      CypherColorPalette.success400,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warning gradient
  LinearGradient get warningGradient => LinearGradient(
    colors: [
      CypherColorPalette.warning500,
      CypherColorPalette.warning400,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Error gradient
  LinearGradient get errorGradient => LinearGradient(
    colors: [
      CypherColorPalette.error500,
      CypherColorPalette.error400,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Create a backdrop filter for glass effects
  ImageFilter get glassBlur => ImageFilter.blur(
    sigmaX: _blur.clamp(0, 200),
    sigmaY: _blur.clamp(0, 200),
  );

  /// Light glass blur (for performance)
  ImageFilter get glassBlurLight => ImageFilter.blur(
    sigmaX: (_blur * 0.3).clamp(0, 50),
    sigmaY: (_blur * 0.3).clamp(0, 50),
  );
}