/// Semantic color tokens for Agent Cypher design system
/// All UI colors must reference these tokens, never hardcoded values

import 'package:flutter/material.dart';

/// Base color palette - raw color values used to construct semantic tokens
class CypherColorPalette {
  // Warm off-white scale (text, surfaces)
  static const Color warmWhite50 = Color(0xFFFDFBF7);
  static const Color warmWhite100 = Color(0xFFF7F3EE);
  static const Color warmWhite200 = Color(0xFFEDE7DB);
  static const Color warmWhite300 = Color(0xFFE2DBCD);
  static const Color warmWhite400 = Color(0xFFD6CCBE);
  static const Color warmWhite500 = Color(0xFFC8BDAF);

  // Warm gray scale (secondary text, borders, disabled)
  static const Color warmGray50 = Color(0xFFFAF8F3);
  static const Color warmGray100 = Color(0xFFF0EBE3);
  static const Color warmGray200 = Color(0xFFE1DACE);
  static const Color warmGray300 = Color(0xFFD0C7BA);
  static const Color warmGray400 = Color(0xFFB8AFA0);
  static const Color warmGray500 = Color(0xFF9E9484);
  static const Color warmGray600 = Color(0xFF82796A);
  static const Color warmGray700 = Color(0xFF675F52);
  static const Color warmGray800 = Color(0xFF4D473C);
  static const Color warmGray900 = Color(0xFF342F26);

  // Charcoal/near-black scale (backgrounds, primary surfaces)
  static const Color charcoal50 = Color(0xFF2A2724);
  static const Color charcoal100 = Color(0xFF23201E);
  static const Color charcoal200 = Color(0xFF1C1A18);
  static const Color charcoal300 = Color(0xFF161413);
  static const Color charcoal400 = Color(0xFF100F0E);
  static const Color charcoal500 = Color(0xFF0B0A09);
  static const Color charcoal600 = Color(0xFF080707); // Primary background
  static const Color charcoal700 = Color(0xFF050404);
  static const Color charcoal800 = Color(0xFF030303);
  static const Color charcoal900 = Color(0xFF010101);

  // Crimson accent family (default theme)
  static const Color crimson50 = Color(0xFF3D0C10);
  static const Color crimson100 = Color(0xFF4A0F13);
  static const Color crimson200 = Color(0xFF5C151D);
  static const Color crimson300 = Color(0xFF6E1B27);
  static const Color crimson400 = Color(0xFF852132);
  static const Color crimson500 = Color(0xFF9F263D); // Primary accent
  static const Color crimson600 = Color(0xFFB82B4A);
  static const Color crimson700 = Color(0xFFD03057);
  static const Color crimson800 = Color(0xFFE83564);
  static const Color crimson900 = Color(0xFFFF3A71);

  // Secondary crimson (muted)
  static const Color crimsonMuted50 = Color(0xFF2D161A);
  static const Color crimsonMuted100 = Color(0xFF3D1E23);
  static const Color crimsonMuted200 = Color(0xFF4D262C);
  static const Color crimsonMuted300 = Color(0xFF663C52);
  static const Color crimsonMuted400 = Color(0xFF7A485E);
  static const Color crimsonMuted500 = Color(0xFF8F546A);

  // Burgundy accent family
  static const Color burgundy50 = Color(0xFF3D0C14);
  static const Color burgundy100 = Color(0xFF4A0F18);
  static const Color burgundy200 = Color(0xFF5C151D);
  static const Color burgundy300 = Color(0xFF721B2A);
  static const Color burgundy400 = Color(0xFF8A2036);
  static const Color burgundy500 = Color(0xFFA02542);
  static const Color burgundy600 = Color(0xFFB82A4E);
  static const Color burgundy700 = Color(0xFFD02F5A);
  static const Color burgundy800 = Color(0xFFE83466);
  static const Color burgundy900 = Color(0xFFFF3972);

  // Midnight (navy) accent family
  static const Color midnight50 = Color(0xFF0C1628);
  static const Color midnight100 = Color(0xFF101E38);
  static const Color midnight200 = Color(0xFF142648);
  static const Color midnight300 = Color(0xFF1A3460);
  static const Color midnight400 = Color(0xFF204278);
  static const Color midnight500 = Color(0xFF285090);
  static const Color midnight600 = Color(0xFF2E5EA8);
  static const Color midnight700 = Color(0xFF346CC0);
  static const Color midnight800 = Color(0xFF3A7AD8);
  static const Color midnight900 = Color(0xFF4088F0);

  // Ember (copper/amber) accent family
  static const Color ember50 = Color(0xFF3D1E0C);
  static const Color ember100 = Color(0xFF4A260F);
  static const Color ember200 = Color(0xFF5C2E13);
  static const Color ember300 = Color(0xFF723A18);
  static const Color ember400 = Color(0xFF8A461D);
  static const Color ember500 = Color(0xFFA05222);
  static const Color ember600 = Color(0xFFB85E27);
  static const Color ember700 = Color(0xFFD06A2C);
  static const Color ember800 = Color(0xFFE87631);
  static const Color ember900 = Color(0xFFFF8236);

  // Platinum (silver/graphite) accent family
  static const Color platinum50 = Color(0xFF2A2A2C);
  static const Color platinum100 = Color(0xFF38383A);
  static const Color platinum200 = Color(0xFF464648);
  static const Color platinum300 = Color(0xFF5A5A5C);
  static const Color platinum400 = Color(0xFF6E6E70);
  static const Color platinum500 = Color(0xFF828284);
  static const Color platinum600 = Color(0xFF969698);
  static const Color platinum700 = Color(0xFFAAAAAC);
  static const Color platinum800 = Color(0xFFBEBEC0);
  static const Color platinum900 = Color(0xFFD2D2D4);

  // Obsidian (graphite) accent family
  static const Color obsidian50 = Color(0xFF1A1A1C);
  static const Color obsidian100 = Color(0xFF242426);
  static const Color obsidian200 = Color(0xFF2E2E30);
  static const Color obsidian300 = Color(0xFF38383A);
  static const Color obsidian400 = Color(0xFF424246);
  static const Color obsidian500 = Color(0xFF4C4C50);
  static const Color obsidian600 = Color(0xFF56565A);
  static const Color obsidian700 = Color(0xFF606064);
  static const Color obsidian800 = Color(0xFF6A6A6E);
  static const Color obsidian900 = Color(0xFF747478);

  // Semantic state colors (consistent across themes)
  static const Color success50 = Color(0xFF0C2D1A);
  static const Color success100 = Color(0xFF104023);
  static const Color success200 = Color(0xFF15532C);
  static const Color success300 = Color(0xFF1A6635);
  static const Color success400 = Color(0xFF1F793E);
  static const Color success500 = Color(0xFF228C47); // Success primary
  static const Color success600 = Color(0xFF279F50);
  static const Color success700 = Color(0xFF2CB259);
  static const Color success800 = Color(0xFF31C562);
  static const Color success900 = Color(0xFF36D86B);

  static const Color warning50 = Color(0xFF3D2C0C);
  static const Color warning100 = Color(0xFF4A380F);
  static const Color warning200 = Color(0xFF5C4413);
  static const Color warning300 = Color(0xFF725618);
  static const Color warning400 = Color(0xFF8A681D);
  static const Color warning500 = Color(0xFFA07A22);
  static const Color warning600 = Color(0xFFB88C27);
  static const Color warning700 = Color(0xFFD09E2C);
  static const Color warning800 = Color(0xFFE8B031);
  static const Color warning900 = Color(0xFFFFC236);

  static const Color error50 = Color(0xFF3D0C0C);
  static const Color error100 = Color(0xFF4A0F0F);
  static const Color error200 = Color(0xFF5C1313);
  static const Color error300 = Color(0xFF721818);
  static const Color error400 = Color(0xFF8A1D1D);
  static const Color error500 = Color(0xFFA02222); // Error primary
  static const Color error600 = Color(0xFFB82727);
  static const Color error700 = Color(0xFFD02C2C);
  static const Color error800 = Color(0xFFE83131);
  static const Color error900 = Color(0xFFFF3636);

  static const Color info50 = Color(0xFF0C1A2D);
  static const Color info100 = Color(0xFF0F2440);
  static const Color info200 = Color(0xFF132E53);
  static const Color info300 = Color(0xFF183E6C);
  static const Color info400 = Color(0xFF1C4E85);
  static const Color info500 = Color(0xFF205E9E);
  static const Color info600 = Color(0xFF256EB7);
  static const Color info700 = Color(0xFF2A7ED0);
  static const Color info800 = Color(0xFF2F8EE9);
  static const Color info900 = Color(0xFF349EF2);

  /// Derives a professional 9-shade accent ramp from a user-chosen color.
  ///
  /// Indices follow the palette convention (50 = darkest, 500 = primary,
  /// 900 = brightest): lower indices darken toward black, higher indices
  /// brighten toward white. `500` is the primary color itself. Used by the
  /// custom-accent theme feature so gradients, borders, surfaces, and the
  /// voice orb all derive from one user color.
  static Map<int, Color> shadeRamp(Color primary) {
    Color blend(Color target, double t) => Color.lerp(primary, target, t)!;
    return <int, Color>{
      50: blend(Colors.white, 0.82),
      100: blend(Colors.white, 0.66),
      200: blend(Colors.white, 0.5),
      300: blend(Colors.white, 0.34),
      400: blend(Colors.white, 0.18),
      500: primary,
      600: blend(Colors.black, 0.18),
      700: blend(Colors.black, 0.34),
      800: blend(Colors.black, 0.5),
      900: blend(Colors.black, 0.66),
    };
  }
}

/// Semantic color tokens - these are what widgets should use
class CypherColorTokens {
  final bool isDark;
  final AccentFamily accentFamily;

  /// When non-null, overrides the accent-family ramp with a user-selected
  /// custom accent (see [CypherColorPalette.shadeRamp]).
  final Color? customAccent;

  const CypherColorTokens({
    required this.isDark,
    required this.accentFamily,
    this.customAccent,
  });

  // Get accent colors for current family (or the custom ramp when set).
  Map<int, Color> get _accent => customAccent == null
      ? accentFamily.colors
      : CypherColorPalette.shadeRamp(customAccent!);

  // Background tokens
  Color get background => isDark ? CypherColorPalette.charcoal600 : CypherColorPalette.warmWhite100;
  Color get backgroundSecondary => isDark ? CypherColorPalette.charcoal500 : CypherColorPalette.warmWhite200;
  Color get backgroundTertiary => isDark ? CypherColorPalette.charcoal400 : CypherColorPalette.warmWhite300;

  // Surface tokens
  Color get surface => isDark ? CypherColorPalette.charcoal200 : CypherColorPalette.warmWhite50;
  Color get surfaceElevated => isDark ? CypherColorPalette.charcoal100 : Colors.white;
  Color get surfaceContainer => isDark ? CypherColorPalette.charcoal300 : CypherColorPalette.warmGray100;
  Color get surfaceContainerHigh => isDark ? CypherColorPalette.charcoal50 : CypherColorPalette.warmGray200;

  // Glass tokens
  Color get glass => isDark
      ? CypherColorPalette.charcoal200.withOpacity(0.8)
      : Colors.white.withOpacity(0.85);
  Color get glassBorder => isDark
      ? CypherColorPalette.warmGray800.withOpacity(0.3)
      : CypherColorPalette.warmGray300.withOpacity(0.4);
  Color get glassHighlight => isDark
      ? Colors.white.withOpacity(0.08)
      : Colors.black.withOpacity(0.04);

  // Text tokens
  Color get textPrimary => isDark ? CypherColorPalette.warmWhite100 : CypherColorPalette.charcoal900;
  Color get textSecondary => isDark ? CypherColorPalette.warmGray400 : CypherColorPalette.warmGray700;
  Color get textTertiary => isDark ? CypherColorPalette.warmGray500 : CypherColorPalette.warmGray600;
  Color get textInverse => isDark ? CypherColorPalette.charcoal900 : CypherColorPalette.warmWhite100;
  Color get textOnAccent => Colors.white;

  // Border tokens
  Color get border => isDark ? CypherColorPalette.warmGray800 : CypherColorPalette.warmGray300;
  Color get borderLight => isDark ? CypherColorPalette.warmGray700 : CypherColorPalette.warmGray200;
  Color get borderStrong => isDark ? CypherColorPalette.warmGray600 : CypherColorPalette.warmGray400;

  // Accent tokens (derive from family)
  Color get accent => _accent[500]!;
  Color get accentLight => _accent[300]!;
  Color get accentDark => _accent[700]!;
  Color get accentMuted => _accent[200]!.withOpacity(0.6);
  Color get accentContainer => _accent[100]!.withOpacity(0.8);
  Color get accentOnContainer => _accent[900]!;

  // State tokens
  Color get success => CypherColorPalette.success500;
  Color get successContainer => CypherColorPalette.success100;
  Color get successOnContainer => CypherColorPalette.success900;

  Color get warning => CypherColorPalette.warning500;
  Color get warningContainer => CypherColorPalette.warning100;
  Color get warningOnContainer => CypherColorPalette.warning900;

  Color get error => CypherColorPalette.error500;
  Color get errorContainer => CypherColorPalette.error100;
  Color get errorOnContainer => CypherColorPalette.error900;

  Color get info => CypherColorPalette.info500;
  Color get infoContainer => CypherColorPalette.info100;
  Color get infoOnContainer => CypherColorPalette.info900;

  // Focus/selection tokens
  Color get focusRing => accent.withOpacity(0.4);
  Color get selection => accent.withOpacity(0.2);

  // Overlay/scrim tokens
  Color get scrim => isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.4);
  Color get overlayBackground => isDark ? CypherColorPalette.charcoal600 : CypherColorPalette.warmWhite100;
}

/// Accent color families for theme presets
enum AccentFamily {
  crimson(CypherColorPalette.crimson50, CypherColorPalette.crimson100, CypherColorPalette.crimson200,
      CypherColorPalette.crimson300, CypherColorPalette.crimson400, CypherColorPalette.crimson500,
      CypherColorPalette.crimson600, CypherColorPalette.crimson700, CypherColorPalette.crimson800,
      CypherColorPalette.crimson900),
  burgundy(CypherColorPalette.burgundy50, CypherColorPalette.burgundy100, CypherColorPalette.burgundy200,
      CypherColorPalette.burgundy300, CypherColorPalette.burgundy400, CypherColorPalette.burgundy500,
      CypherColorPalette.burgundy600, CypherColorPalette.burgundy700, CypherColorPalette.burgundy800,
      CypherColorPalette.burgundy900),
  midnight(CypherColorPalette.midnight50, CypherColorPalette.midnight100, CypherColorPalette.midnight200,
      CypherColorPalette.midnight300, CypherColorPalette.midnight400, CypherColorPalette.midnight500,
      CypherColorPalette.midnight600, CypherColorPalette.midnight700, CypherColorPalette.midnight800,
      CypherColorPalette.midnight900),
  ember(CypherColorPalette.ember50, CypherColorPalette.ember100, CypherColorPalette.ember200,
      CypherColorPalette.ember300, CypherColorPalette.ember400, CypherColorPalette.ember500,
      CypherColorPalette.ember600, CypherColorPalette.ember700, CypherColorPalette.ember800,
      CypherColorPalette.ember900),
  platinum(CypherColorPalette.platinum50, CypherColorPalette.platinum100, CypherColorPalette.platinum200,
      CypherColorPalette.platinum300, CypherColorPalette.platinum400, CypherColorPalette.platinum500,
      CypherColorPalette.platinum600, CypherColorPalette.platinum700, CypherColorPalette.platinum800,
      CypherColorPalette.platinum900),
  obsidian(CypherColorPalette.obsidian50, CypherColorPalette.obsidian100, CypherColorPalette.obsidian200,
      CypherColorPalette.obsidian300, CypherColorPalette.obsidian400, CypherColorPalette.obsidian500,
      CypherColorPalette.obsidian600, CypherColorPalette.obsidian700, CypherColorPalette.obsidian800,
      CypherColorPalette.obsidian900);

  const AccentFamily(
    this.c50, this.c100, this.c200, this.c300, this.c400,
    this.c500, this.c600, this.c700, this.c800, this.c900,
  );

  final Color c50, c100, c200, c300, c400, c500, c600, c700, c800, c900;

  Map<int, Color> get colors => {
    50: c50, 100: c100, 200: c200, 300: c300, 400: c400,
    500: c500, 600: c600, 700: c700, 800: c800, 900: c900,
  };

  String get displayName {
    switch (this) {
      case AccentFamily.crimson: return 'Crimson';
      case AccentFamily.burgundy: return 'Burgundy';
      case AccentFamily.midnight: return 'Midnight';
      case AccentFamily.ember: return 'Ember';
      case AccentFamily.platinum: return 'Platinum';
      case AccentFamily.obsidian: return 'Obsidian';
    }
  }

  String get description {
    switch (this) {
      case AccentFamily.crimson: return 'Deep crimson red - warm & bold';
      case AccentFamily.burgundy: return 'Rich wine burgundy - sophisticated';
      case AccentFamily.midnight: return 'Restrained navy - calm & professional';
      case AccentFamily.ember: return 'Muted copper amber - warm glow';
      case AccentFamily.platinum: return 'Silver graphite - clean & minimal';
      case AccentFamily.obsidian: return 'Dark graphite - subtle & technical';
    }
  }
}