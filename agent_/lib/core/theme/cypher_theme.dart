/// CypherTheme - integrates all design tokens into a coherent theme system
/// Provides CypherThemeData with color, gradient, glass, spacing, typography tokens

import 'package:flutter/material.dart';
import 'color_tokens.dart';
import 'gradient_tokens.dart';
import 'glass_tokens.dart';
import 'spacing_tokens.dart';
import 'typography_tokens.dart';

/// Theme mode preference
enum CypherThemeMode {
  dark, // Always dark
  light, // Always light
  system, // Follow system
}

/// Full theme preset combining mode + accent + gradient style
class CypherThemePreset {
  final String id;
  final String name;
  final String description;
  final CypherThemeMode defaultMode;
  final AccentFamily accentFamily;
  final GradientStyle gradientStyle;
  final GradientIntensity gradientIntensity;
  final double gradientBlur;

  const CypherThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultMode,
    required this.accentFamily,
    this.gradientStyle = GradientStyle.ambient,
    this.gradientIntensity = GradientIntensity.subtle,
    this.gradientBlur = 100.0,
  });

  static const CypherThemePreset crimsonNight = CypherThemePreset(
    id: 'crimson_night',
    name: 'Crimson Night',
    description: 'Deep crimson on dark charcoal — bold & warm',
    defaultMode: CypherThemeMode.dark,
    accentFamily: AccentFamily.crimson,
    gradientStyle: GradientStyle.ambient,
    gradientIntensity: GradientIntensity.subtle,
  );

  static const CypherThemePreset obsidian = CypherThemePreset(
    id: 'obsidian',
    name: 'Obsidian',
    description: 'Graphite accents on near-black — technical & minimal',
    defaultMode: CypherThemeMode.dark,
    accentFamily: AccentFamily.obsidian,
    gradientStyle: GradientStyle.linear,
    gradientIntensity: GradientIntensity.subtle,
  );

  static const CypherThemePreset burgundy = CypherThemePreset(
    id: 'burgundy',
    name: 'Burgundy',
    description: 'Rich wine on dark — sophisticated & warm',
    defaultMode: CypherThemeMode.dark,
    accentFamily: AccentFamily.burgundy,
    gradientStyle: GradientStyle.radial,
    gradientIntensity: GradientIntensity.low,
  );

  static const CypherThemePreset midnight = CypherThemePreset(
    id: 'midnight',
    name: 'Midnight',
    description: 'Restrained navy — calm & professional',
    defaultMode: CypherThemeMode.dark,
    accentFamily: AccentFamily.midnight,
    gradientStyle: GradientStyle.dualGlow,
    gradientIntensity: GradientIntensity.low,
  );

  static const CypherThemePreset ember = CypherThemePreset(
    id: 'ember',
    name: 'Ember',
    description: 'Muted copper glow — warm & ambient',
    defaultMode: CypherThemeMode.dark,
    accentFamily: AccentFamily.ember,
    gradientStyle: GradientStyle.subtleMesh,
    gradientIntensity: GradientIntensity.medium,
  );

  static const CypherThemePreset platinum = CypherThemePreset(
    id: 'platinum',
    name: 'Platinum',
    description: 'Silver graphite — clean & bright',
    defaultMode: CypherThemeMode.light,
    accentFamily: AccentFamily.platinum,
    gradientStyle: GradientStyle.ambient,
    gradientIntensity: GradientIntensity.subtle,
  );

  static const List<CypherThemePreset> all = [
    crimsonNight,
    obsidian,
    burgundy,
    midnight,
    ember,
    platinum,
  ];

  static CypherThemePreset byId(String id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => crimsonNight,
    );
  }
}

/// Complete theme data — all tokens resolved for a specific mode + accent
class CypherThemeData {
  final bool isDark;
  final AccentFamily accentFamily;
  final CypherThemePreset preset;

  late final CypherColorTokens colors;
  late final CypherGradientTokens gradients;
  late final CypherTypographyTokens typography;
  late final GlassSpec defaultGlassSpec;
  late final CypherSpacing spacing;

  CypherThemeData({
    required this.isDark,
    required this.accentFamily,
    required this.preset,
  }) {
    colors = CypherColorTokens(
      isDark: isDark,
      accentFamily: accentFamily,
    );
    gradients = CypherGradientTokens(
      isDark: isDark,
      config: CypherGradientConfig(
        style: preset.gradientStyle,
        intensity: preset.gradientIntensity,
        blur: preset.gradientBlur,
        accentFamily: accentFamily,
      ),
    );
    typography = CypherTypographyTokens(
      isDark: isDark,
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      textTertiary: colors.textTertiary,
      textInverse: colors.textInverse,
      accentColor: colors.accent,
    );
    defaultGlassSpec = GlassSpec.card(accentFamily: accentFamily);
    spacing = const CypherSpacing();
  }

  /// Build Material ThemeData from this theme
  ThemeData toMaterialTheme() {
    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: colors.accent,
      onPrimary: colors.textOnAccent,
      primaryContainer: colors.accentContainer,
      onPrimaryContainer: colors.accentOnContainer,
      secondary: colors.accentLight,
      onSecondary: colors.textOnAccent,
      secondaryContainer: colors.accentMuted,
      onSecondaryContainer: colors.textOnAccent,
      tertiary: colors.accentDark,
      onTertiary: colors.textOnAccent,
      tertiaryContainer: colors.accentContainer,
      onTertiaryContainer: colors.accentOnContainer,
      error: colors.error,
      onError: colors.textOnAccent,
      errorContainer: colors.errorContainer,
      onErrorContainer: colors.errorOnContainer,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surfaceContainer,
      surfaceContainerHigh: colors.surfaceContainerHigh,
      surfaceContainerHighest: colors.surfaceElevated,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.borderLight,
      shadow: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
      scrim: colors.scrim,
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.background,
      inversePrimary: colors.accentLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent, // Let gradient show through
      canvasColor: colors.background,
      textTheme: typography.toTextTheme(),
      primaryTextTheme: typography.toTextTheme(),
      fontFamily: CypherFontFamily.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.titleLarge,
        iconTheme: IconThemeData(color: colors.textPrimary, size: CypherSpacing.iconLg),
        actionsIconTheme: IconThemeData(color: colors.textSecondary, size: CypherSpacing.iconLg),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusCard),
          side: BorderSide(color: colors.borderLight, width: CypherSpacing.borderHairline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.borderLight,
        thickness: CypherSpacing.borderHairline,
        space: CypherSpacing.space8,
      ),
      iconTheme: IconThemeData(
        color: colors.textSecondary,
        size: CypherSpacing.iconLg,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: typography.bodyMedium.copyWith(color: colors.textPrimary),
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusSm),
          side: BorderSide(color: colors.borderLight, width: CypherSpacing.borderHairline),
        ),
        margin: const EdgeInsets.fromLTRB(
          CypherSpacing.space16, CypherSpacing.space16, CypherSpacing.space16, CypherSpacing.space16,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: typography.labelSmall.copyWith(color: colors.textInverse),
        decoration: BoxDecoration(
          color: colors.textPrimary.withOpacity(0.9),
          borderRadius: BorderRadius.circular(CypherSpacing.radiusTooltip),
        ),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusModal),
          side: BorderSide(color: colors.borderLight, width: CypherSpacing.borderThin),
        ),
        titleTextStyle: typography.titleLarge,
        contentTextStyle: typography.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CypherSpacing.space12,
          vertical: CypherSpacing.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusInput),
          borderSide: BorderSide(color: colors.border, width: CypherSpacing.borderThin),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusInput),
          borderSide: BorderSide(color: colors.borderLight, width: CypherSpacing.borderThin),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusInput),
          borderSide: BorderSide(color: colors.accent.withOpacity(0.6), width: CypherSpacing.borderMedium),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusInput),
          borderSide: BorderSide(color: colors.error.withOpacity(0.5), width: CypherSpacing.borderThin),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusInput),
          borderSide: BorderSide(color: colors.error, width: CypherSpacing.borderMedium),
        ),
        labelStyle: typography.inputLabel,
        hintStyle: typography.helperText,
        helperStyle: typography.helperText,
        errorStyle: typography.errorText,
        iconColor: colors.textTertiary,
        prefixIconColor: colors.textTertiary,
        suffixIconColor: colors.textTertiary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: colors.selection,
        cursorColor: colors.accent,
        selectionHandleColor: colors.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return colors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent.withOpacity(0.4);
          return colors.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return colors.borderLight;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colors.textOnAccent),
        side: BorderSide(color: colors.borderStrong, width: CypherSpacing.borderThin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return colors.textTertiary;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accent,
        inactiveTrackColor: colors.border,
        thumbColor: colors.accent,
        overlayColor: colors.accent.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.border,
        circularTrackColor: colors.border,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.textOnAccent,
        elevation: 2,
        focusElevation: 4,
        hoverElevation: 3,
        disabledElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.accentContainer,
        labelStyle: typography.labelMedium,
        secondaryLabelStyle: typography.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: CypherSpacing.space4,
          vertical: CypherSpacing.space2,
        ),
        side: BorderSide(color: colors.borderLight, width: CypherSpacing.borderHairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusChip),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CypherSpacing.space16,
          vertical: CypherSpacing.space2,
        ),
        horizontalTitleGap: CypherSpacing.space12,
        minVerticalPadding: CypherSpacing.space12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusSm),
        ),
        titleTextStyle: typography.settingsItemTitle,
        subtitleTextStyle: typography.settingsItemSubtitle,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.accent,
        unselectedLabelColor: colors.textTertiary,
        labelStyle: typography.labelMedium,
        unselectedLabelStyle: typography.labelMedium,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colors.accent, width: 2),
          borderRadius: BorderRadius.circular(CypherSpacing.radiusXs),
        ),
        dividerColor: colors.borderLight,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CypherSpacing.radiusXxl),
          ),
        ),
        modalBarrierColor: colors.scrim,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface.withOpacity(0.9),
        elevation: 0,
        height: CypherSpacing.navBarHeightMobile,
        indicatorColor: colors.accent.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(typography.navLabel),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.accent, size: CypherSpacing.iconLg);
          }
          return IconThemeData(color: colors.textTertiary, size: CypherSpacing.iconLg);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface.withOpacity(0.8),
        elevation: 0,
        selectedIconTheme: IconThemeData(color: colors.accent, size: CypherSpacing.iconXl),
        unselectedIconTheme: IconThemeData(color: colors.textTertiary, size: CypherSpacing.iconLg),
        selectedLabelTextStyle: typography.navLabel.copyWith(color: colors.accent),
        unselectedLabelTextStyle: typography.navLabel,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) return colors.accent.withOpacity(0.6);
          if (states.contains(WidgetState.hovered)) return colors.textTertiary.withOpacity(0.5);
          return colors.textTertiary.withOpacity(0.3);
        }),
        trackColor: WidgetStateProperty.all(colors.border.withOpacity(0.1)),
        radius: const Radius.circular(CypherSpacing.radiusFull),
        thickness: WidgetStateProperty.all(6),
        crossAxisMargin: 2,
      ),
    );
  }
}

/// Inherited widget for accessing the theme anywhere in the widget tree
class CypherTheme extends InheritedWidget {
  final CypherThemeData data;

  const CypherTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static CypherThemeData of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<CypherTheme>();
    if (widget != null) return widget.data;
    // Fallback: build from default preset
    return CypherThemeData(
      isDark: true,
      accentFamily: AccentFamily.crimson,
      preset: CypherThemePreset.crimsonNight,
    );
  }

  static CypherThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CypherTheme>()?.data;
  }

  @override
  bool updateShouldNotify(CypherTheme oldWidget) => data != oldWidget.data;
}

/// Convenience extension on BuildContext for token access
extension CypherThemeContext on BuildContext {
  CypherThemeData get cypher => CypherTheme.of(this);
  CypherColorTokens get cypherColors => cypher.colors;
  CypherGradientTokens get cypherGradients => cypher.gradients;
  CypherTypographyTokens get cypherTypography => cypher.typography;
  CypherSpacing get cypherSpacing => cypher.spacing;
  GlassSpec get cypherGlassSpec => cypher.defaultGlassSpec;
}
