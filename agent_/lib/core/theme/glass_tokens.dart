/// Glass material tokens for Agent Cypher design system
/// Glass surface specifications, blur levels, borders, highlights

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'color_tokens.dart';
import 'gradient_tokens.dart';

/// Glass surface elevation levels
enum GlassElevation {
  level0, // Flat, no shadow
  level1, // Subtle surface
  level2, // Raised card
  level3, // Floating panel
  level4, // Modal/overlay
  level5, // Tooltip/popover
}

/// Glass opacity presets
enum GlassOpacity {
  transparent(0.0),
  whisper(0.04),
  subtle(0.08),
  light(0.12),
  medium(0.2),
  strong(0.32),
  opaque(0.5);

  const GlassOpacity(this.value);
  final double value;
}

/// Glass blur presets
enum GlassBlur {
  none(0),
  whisper(4),
  subtle(8),
  light(16),
  medium(24),
  strong(32),
  heavy(48),
  extreme(64);

  const GlassBlur(this.value);
  final double value;
}

/// Glass border strength
enum GlassBorder {
  none(0),
  hairline(0.5),
  thin(1),
  medium(1.5),
  thick(2);

  const GlassBorder(this.width);
  final double width;
}

/// Complete glass surface specification
class GlassSpec {
  final GlassElevation elevation;
  final GlassOpacity opacity;
  final GlassBlur blur;
  final GlassBorder border;
  final bool hasHighlight;
  final bool hasInnerGlow;
  final AccentFamily accentFamily;

  const GlassSpec({
    this.elevation = GlassElevation.level1,
    this.opacity = GlassOpacity.subtle,
    this.blur = GlassBlur.light,
    this.border = GlassBorder.thin,
    this.hasHighlight = true,
    this.hasInnerGlow = false,
    this.accentFamily = AccentFamily.crimson,
  });

  GlassSpec copyWith({
    GlassElevation? elevation,
    GlassOpacity? opacity,
    GlassBlur? blur,
    GlassBorder? border,
    bool? hasHighlight,
    bool? hasInnerGlow,
    AccentFamily? accentFamily,
  }) {
    return GlassSpec(
      elevation: elevation ?? this.elevation,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      border: border ?? this.border,
      hasHighlight: hasHighlight ?? this.hasHighlight,
      hasInnerGlow: hasInnerGlow ?? this.hasInnerGlow,
      accentFamily: accentFamily ?? this.accentFamily,
    );
  }

  /// Predefined glass styles for common use cases
  static GlassSpec background({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level0,
      opacity: GlassOpacity.transparent,
      blur: GlassBlur.none,
      border: GlassBorder.none,
      hasHighlight: false,
      hasInnerGlow: false,
      accentFamily: accentFamily,
    );
  }

  static GlassSpec surface({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level1,
      opacity: GlassOpacity.subtle,
      blur: GlassBlur.light,
      border: GlassBorder.hairline,
      hasHighlight: true,
      hasInnerGlow: false,
      accentFamily: accentFamily,
    );
  }

  static GlassSpec card({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level2,
      opacity: GlassOpacity.light,
      blur: GlassBlur.medium,
      border: GlassBorder.thin,
      hasHighlight: true,
      hasInnerGlow: true,
      accentFamily: accentFamily,
    );
  }

  static GlassSpec panel({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level3,
      opacity: GlassOpacity.medium,
      blur: GlassBlur.strong,
      border: GlassBorder.medium,
      hasHighlight: true,
      hasInnerGlow: true,
      accentFamily: accentFamily,
    );
  }

  static GlassSpec modal({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level4,
      opacity: GlassOpacity.strong,
      blur: GlassBlur.heavy,
      border: GlassBorder.medium,
      hasHighlight: true,
      hasInnerGlow: true,
      accentFamily: accentFamily,
    );
  }

  static GlassSpec tooltip({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level5,
      opacity: GlassOpacity.strong,
      blur: GlassBlur.strong,
      border: GlassBorder.thin,
      hasHighlight: true,
      hasInnerGlow: false,
      accentFamily: accentFamily,
    );
  }

  static GlassSpec input({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level1,
      opacity: GlassOpacity.subtle,
      blur: GlassBlur.light,
      border: GlassBorder.thin,
      hasHighlight: true,
      hasInnerGlow: false,
      accentFamily: accentFamily,
    );
  }

  static GlassSpec button({AccentFamily accentFamily = AccentFamily.crimson}) {
    return GlassSpec(
      elevation: GlassElevation.level2,
      opacity: GlassOpacity.light,
      blur: GlassBlur.medium,
      border: GlassBorder.thin,
      hasHighlight: true,
      hasInnerGlow: true,
      accentFamily: accentFamily,
    );
  }
}

/// Glass token generator
class CypherGlassTokens {
  final bool isDark;
  final GlassSpec spec;
  final CypherGradientTokens? gradientTokens;

  const CypherGlassTokens({
    required this.isDark,
    required this.spec,
    this.gradientTokens,
  });

  /// Surface color with opacity
  Color get surfaceColor {
    final baseColor = isDark
        ? CypherColorPalette.charcoal200
        : Colors.white;
    return baseColor.withOpacity(spec.opacity.value);
  }

  /// Border color
  Color get borderColor {
    final baseColor = isDark
        ? CypherColorPalette.warmGray800
        : CypherColorPalette.warmGray300;
    return baseColor.withOpacity(0.3 + (spec.border.width * 0.15));
  }

  /// Highlight color (top edge)
  Color get highlightColor {
    if (!spec.hasHighlight) return Colors.transparent;
    return isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.04);
  }

  /// Inner glow color (accent tint)
  Color get innerGlowColor {
    if (!spec.hasInnerGlow) return Colors.transparent;
    final palette = spec.accentFamily.colors;
    final accentColor = isDark ? palette[400]! : palette[600]!;
    return accentColor.withOpacity(0.03);
  }

  /// Blur value
  double get blurSigma => spec.blur.value;

  /// Border width
  double get borderWidth => spec.border.width;

  /// Shadow for elevation
  List<BoxShadow> get shadows {
    switch (spec.elevation) {
      case GlassElevation.level0:
        return [];
      case GlassElevation.level1:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case GlassElevation.level2:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case GlassElevation.level3:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case GlassElevation.level4:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case GlassElevation.level5:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
    }
  }

  /// Backdrop filter for blur
  ImageFilter get backdropFilter => ImageFilter.blur(
    sigmaX: blurSigma,
    sigmaY: blurSigma,
  );

  /// Light backdrop filter (for performance on large areas)
  ImageFilter get backdropFilterLight => ImageFilter.blur(
    sigmaX: (blurSigma * 0.4).clamp(0, 20),
    sigmaY: (blurSigma * 0.4).clamp(0, 20),
  );

  /// Decoration for container
  BoxDecoration get decoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(_defaultRadius),
    border: spec.border.width > 0
        ? Border.all(
            color: borderColor,
            width: borderWidth,
          )
        : null,
    boxShadow: shadows,
    gradient: gradientTokens != null ? gradientTokens!.glassGradient : null,
  );

  /// Input decoration (with focus state support)
  BoxDecoration inputDecoration({bool isFocused = false, bool hasError = false}) {
    Color effectiveBorderColor = borderColor;
    if (isFocused) {
      final palette = spec.accentFamily.colors;
      effectiveBorderColor = (isDark ? palette[400]! : palette[600]!).withOpacity(0.6);
    } else if (hasError) {
      effectiveBorderColor = CypherColorPalette.error500.withOpacity(0.6);
    }

    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(_defaultRadius),
      border: Border.all(
        color: effectiveBorderColor,
        width: isFocused ? 2 : borderWidth,
      ),
      boxShadow: isFocused
          ? [
              BoxShadow(
                color: effectiveBorderColor.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
          : shadows,
      gradient: gradientTokens != null ? gradientTokens!.glassGradient : null,
    );
  }

  /// Button decoration
  BoxDecoration buttonDecoration({
    bool isPressed = false,
    bool isDisabled = false,
    bool isPrimary = true,
  }) {
    if (isDisabled) {
      return BoxDecoration(
        color: isDark
            ? CypherColorPalette.charcoal300.withOpacity(0.5)
            : CypherColorPalette.warmGray200.withOpacity(0.5),
        borderRadius: BorderRadius.circular(_defaultRadius),
        border: Border.all(
          color: isDark
              ? CypherColorPalette.warmGray700.withOpacity(0.3)
              : CypherColorPalette.warmGray300.withOpacity(0.3),
        ),
      );
    }

    if (isPrimary && isPressed) {
      return BoxDecoration(
        gradient: gradientTokens?.pressedGradient,
        borderRadius: BorderRadius.circular(_defaultRadius),
        boxShadow: [
          BoxShadow(
            color: (gradientTokens?.accentColor ?? CypherColorPalette.crimson500)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(_defaultRadius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: shadows,
      gradient: isPrimary && gradientTokens != null ? gradientTokens!.accentGradient : null,
    );
  }

  static const double _defaultRadius = 16.0;
}