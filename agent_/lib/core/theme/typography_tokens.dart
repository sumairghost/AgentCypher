/// Typography tokens for Agent Cypher design system
/// Type scale, font families, weights, line heights, letter spacing

import 'package:flutter/material.dart';
import 'color_tokens.dart';

/// Font family definitions
class CypherFontFamily {
  /// Primary UI font - Inter (clean, readable, excellent at small sizes)
  static const String primary = 'Inter';

  /// Monospace font - JetBrains Mono (code, technical content)
  static const String mono = 'JetBrainsMono';

  /// Display font - for headlines, branding (optional, falls back to primary)
  static const String display = 'Inter';

  /// Fallback fonts
  static const List<String> fallbacks = [
    'SF Pro Text',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static const List<String> monoFallbacks = [
    'SF Mono',
    'Fira Code',
    'Consolas',
    'Monospace',
  ];
}

/// Font weight scale
class CypherFontWeight {
  static const FontWeight thin = FontWeight.w100;
  static const FontWeight extraLight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;
}

/// Line height scale (as multiplier of font size)
class CypherLineHeight {
  static const double none = 1.0;
  static const double tight = 1.1;
  static const double snug = 1.25;
  static const double normal = 1.5;
  static const double relaxed = 1.625;
  static const double loose = 1.75;
  static const double loose2 = 2.0;
}

/// Letter spacing scale (in em units)
class CypherLetterSpacing {
  static const double tighter = -0.05;
  static const double tight = -0.025;
  static const double normal = 0;
  static const double wide = 0.025;
  static const double wider = 0.05;
  static const double widest = 0.1;
}

/// Complete type style specification
class CypherTextStyle {
  final double fontSize;
  final FontWeight fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final String fontFamily;
  final Color? color;
  final TextDecoration? decoration;
  final TextDecorationStyle? decorationStyle;
  final Color? decorationColor;

  const CypherTextStyle({
    required this.fontSize,
    required this.fontWeight,
    required this.lineHeight,
    required this.letterSpacing,
    this.fontFamily = CypherFontFamily.primary,
    this.color,
    this.decoration,
    this.decorationStyle,
    this.decorationColor,
  });

  TextStyle toTextStyle({Color? color, TextDecoration? decoration}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: lineHeight,
      letterSpacing: letterSpacing * fontSize,
      color: color ?? this.color,
      decoration: decoration ?? this.decoration,
      decorationStyle: decorationStyle,
      decorationColor: decorationColor,
    );
  }

  CypherTextStyle copyWith({
    double? fontSize,
    FontWeight? fontWeight,
    double? lineHeight,
    double? letterSpacing,
    String? fontFamily,
    Color? color,
    TextDecoration? decoration,
    TextDecorationStyle? decorationStyle,
    Color? decorationColor,
  }) {
    return CypherTextStyle(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      decoration: decoration ?? this.decoration,
      decorationStyle: decorationStyle ?? this.decorationStyle,
      decorationColor: decorationColor ?? this.decorationColor,
    );
  }
}

/// Type scale - semantic text styles
class CypherTypeScale {
  // Display styles (large headlines)
  static const CypherTextStyle displayLarge = CypherTextStyle(
    fontSize: 57,
    fontWeight: CypherFontWeight.bold,
    lineHeight: CypherLineHeight.tight,
    letterSpacing: CypherLetterSpacing.tighter,
  );

  static const CypherTextStyle displayMedium = CypherTextStyle(
    fontSize: 45,
    fontWeight: CypherFontWeight.bold,
    lineHeight: CypherLineHeight.tight,
    letterSpacing: CypherLetterSpacing.tight,
  );

  static const CypherTextStyle displaySmall = CypherTextStyle(
    fontSize: 36,
    fontWeight: CypherFontWeight.semiBold,
    lineHeight: CypherLineHeight.snug,
    letterSpacing: CypherLetterSpacing.tight,
  );

  // Headline styles
  static const CypherTextStyle headlineLarge = CypherTextStyle(
    fontSize: 32,
    fontWeight: CypherFontWeight.semiBold,
    lineHeight: CypherLineHeight.snug,
    letterSpacing: CypherLetterSpacing.normal,
  );

  static const CypherTextStyle headlineMedium = CypherTextStyle(
    fontSize: 28,
    fontWeight: CypherFontWeight.semiBold,
    lineHeight: CypherLineHeight.snug,
    letterSpacing: CypherLetterSpacing.normal,
  );

  static const CypherTextStyle headlineSmall = CypherTextStyle(
    fontSize: 24,
    fontWeight: CypherFontWeight.semiBold,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.normal,
  );

  // Title styles
  static const CypherTextStyle titleLarge = CypherTextStyle(
    fontSize: 22,
    fontWeight: CypherFontWeight.medium,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.normal,
  );

  static const CypherTextStyle titleMedium = CypherTextStyle(
    fontSize: 18,
    fontWeight: CypherFontWeight.medium,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.wide,
  );

  static const CypherTextStyle titleSmall = CypherTextStyle(
    fontSize: 16,
    fontWeight: CypherFontWeight.medium,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.wide,
  );

  // Body styles
  static const CypherTextStyle bodyLarge = CypherTextStyle(
    fontSize: 16,
    fontWeight: CypherFontWeight.regular,
    lineHeight: CypherLineHeight.relaxed,
    letterSpacing: CypherLetterSpacing.normal,
  );

  static const CypherTextStyle bodyMedium = CypherTextStyle(
    fontSize: 14,
    fontWeight: CypherFontWeight.regular,
    lineHeight: CypherLineHeight.relaxed,
    letterSpacing: CypherLetterSpacing.normal,
  );

  static const CypherTextStyle bodySmall = CypherTextStyle(
    fontSize: 12,
    fontWeight: CypherFontWeight.regular,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.wide,
  );

  // Label styles
  static const CypherTextStyle labelLarge = CypherTextStyle(
    fontSize: 14,
    fontWeight: CypherFontWeight.semiBold,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.wide,
  );

  static const CypherTextStyle labelMedium = CypherTextStyle(
    fontSize: 12,
    fontWeight: CypherFontWeight.medium,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.wider,
  );

  static const CypherTextStyle labelSmall = CypherTextStyle(
    fontSize: 11,
    fontWeight: CypherFontWeight.medium,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.widest,
  );

  // Monospace styles (code, technical)
  static const CypherTextStyle monoLarge = CypherTextStyle(
    fontSize: 16,
    fontWeight: CypherFontWeight.regular,
    lineHeight: CypherLineHeight.relaxed,
    letterSpacing: CypherLetterSpacing.normal,
    fontFamily: CypherFontFamily.mono,
  );

  static const CypherTextStyle monoMedium = CypherTextStyle(
    fontSize: 14,
    fontWeight: CypherFontWeight.regular,
    lineHeight: CypherLineHeight.relaxed,
    letterSpacing: CypherLetterSpacing.normal,
    fontFamily: CypherFontFamily.mono,
  );

  static const CypherTextStyle monoSmall = CypherTextStyle(
    fontSize: 12,
    fontWeight: CypherFontWeight.regular,
    lineHeight: CypherLineHeight.normal,
    letterSpacing: CypherLetterSpacing.wide,
    fontFamily: CypherFontFamily.mono,
  );

  // Semantic aliases for common use cases
  static const CypherTextStyle pageTitle = headlineLarge;
  static const CypherTextStyle sectionTitle = headlineMedium;
  static const CypherTextStyle cardTitle = titleMedium;
  static const CypherTextStyle buttonText = labelLarge;
  static const CypherTextStyle inputText = bodyLarge;
  static const CypherTextStyle inputLabel = labelMedium;
  static const CypherTextStyle helperText = bodySmall;
  static const CypherTextStyle errorText = bodySmall;
  static const CypherTextStyle captionText = labelSmall;
  static const CypherTextStyle overlineText = labelSmall;

  // Chat specific
  static const CypherTextStyle chatMessage = bodyLarge;
  static const CypherTextStyle chatMeta = bodySmall;
  static const CypherTextStyle chatCodeInline = monoMedium;
  static const CypherTextStyle chatCodeBlock = monoSmall;

  // Settings specific
  static const CypherTextStyle settingsSectionTitle = titleMedium;
  static const CypherTextStyle settingsItemTitle = bodyLarge;
  static const CypherTextStyle settingsItemSubtitle = bodySmall;
  static const CypherTextStyle settingsGroupTitle = labelLarge;

  // Navigation
  static const CypherTextStyle navLabel = labelMedium;
  static const CypherTextStyle navBadge = labelSmall;

  // Overlay
  static const CypherTextStyle orbLabel = labelMedium;
  static const CypherTextStyle orbMenuItem = bodyMedium;

  /// Get TextStyle with color applied
  static TextStyle applyColor(CypherTextStyle style, Color color) {
    return style.toTextStyle(color: color);
  }

  /// Get TextStyle with color and weight override
  static TextStyle apply(CypherTextStyle style, {
    Color? color,
    FontWeight? weight,
    double? size,
  }) {
    return style.copyWith(
      color: color,
      fontWeight: weight,
      fontSize: size,
    ).toTextStyle();
  }
}

/// Typography token generator for theme
class CypherTypographyTokens {
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;
  final Color accentColor;

  const CypherTypographyTokens({
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.accentColor,
  });

  // Display
  TextStyle get displayLarge => CypherTypeScale.displayLarge.toTextStyle(color: textPrimary);
  TextStyle get displayMedium => CypherTypeScale.displayMedium.toTextStyle(color: textPrimary);
  TextStyle get displaySmall => CypherTypeScale.displaySmall.toTextStyle(color: textPrimary);

  // Headline
  TextStyle get headlineLarge => CypherTypeScale.headlineLarge.toTextStyle(color: textPrimary);
  TextStyle get headlineMedium => CypherTypeScale.headlineMedium.toTextStyle(color: textPrimary);
  TextStyle get headlineSmall => CypherTypeScale.headlineSmall.toTextStyle(color: textPrimary);

  // Title
  TextStyle get titleLarge => CypherTypeScale.titleLarge.toTextStyle(color: textPrimary);
  TextStyle get titleMedium => CypherTypeScale.titleMedium.toTextStyle(color: textPrimary);
  TextStyle get titleSmall => CypherTypeScale.titleSmall.toTextStyle(color: textPrimary);

  // Body
  TextStyle get bodyLarge => CypherTypeScale.bodyLarge.toTextStyle(color: textPrimary);
  TextStyle get bodyMedium => CypherTypeScale.bodyMedium.toTextStyle(color: textSecondary);
  TextStyle get bodySmall => CypherTypeScale.bodySmall.toTextStyle(color: textTertiary);

  // Label
  TextStyle get labelLarge => CypherTypeScale.labelLarge.toTextStyle(color: textPrimary);
  TextStyle get labelMedium => CypherTypeScale.labelMedium.toTextStyle(color: textSecondary);
  TextStyle get labelSmall => CypherTypeScale.labelSmall.toTextStyle(color: textTertiary);

  // Monospace
  TextStyle get monoLarge => CypherTypeScale.monoLarge.toTextStyle(color: textPrimary);
  TextStyle get monoMedium => CypherTypeScale.monoMedium.toTextStyle(color: textSecondary);
  TextStyle get monoSmall => CypherTypeScale.monoSmall.toTextStyle(color: textTertiary);

  // Semantic aliases
  TextStyle get pageTitle => displayLarge;
  TextStyle get sectionTitle => headlineMedium;
  TextStyle get cardTitle => titleMedium;
  TextStyle get buttonText => labelLarge.copyWith(color: Colors.white);
  TextStyle get inputText => bodyLarge.copyWith(color: textPrimary);
  TextStyle get inputLabel => labelMedium.copyWith(color: textSecondary);
  TextStyle get helperText => bodySmall.copyWith(color: textTertiary);
  TextStyle get errorText => bodySmall.copyWith(color: CypherColorPalette.error500);
  TextStyle get captionText => labelSmall.copyWith(color: textTertiary);
  TextStyle get overlineText => labelSmall.copyWith(color: textTertiary);

  // Chat
  TextStyle get chatMessage => bodyLarge.copyWith(color: textPrimary);
  TextStyle get chatMeta => bodySmall.copyWith(color: textTertiary);
  TextStyle get chatCodeInline => monoMedium.copyWith(color: accentColor);
  TextStyle get chatCodeBlock => monoSmall.copyWith(color: textSecondary);

  // Settings
  TextStyle get settingsSectionTitle => titleMedium.copyWith(color: textPrimary);
  TextStyle get settingsItemTitle => bodyLarge.copyWith(color: textPrimary);
  TextStyle get settingsItemSubtitle => bodySmall.copyWith(color: textTertiary);
  TextStyle get settingsGroupTitle => labelLarge.copyWith(color: textSecondary);

  // Navigation
  TextStyle get navLabel => labelMedium.copyWith(color: textSecondary);
  TextStyle get navBadge => labelSmall.copyWith(color: textInverse);

  // Overlay
  TextStyle get orbLabel => labelMedium.copyWith(color: textPrimary);
  TextStyle get orbMenuItem => bodyMedium.copyWith(color: textPrimary);

  /// Create a TextTheme for Material ThemeData
  TextTheme toTextTheme() {
    return TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      displaySmall: displaySmall,
      headlineLarge: headlineLarge,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }
}