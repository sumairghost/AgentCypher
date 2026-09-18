/// Spacing tokens for Agent Cypher design system
/// Consistent spacing scale, component dimensions, layout metrics

import 'package:flutter/material.dart';

/// Base spacing unit (4px)
const double _baseUnit = 4.0;

/// Spacing scale - all values are multiples of base unit
class CypherSpacing {
  // Core spacing values
  static const double space0 = 0;
  static const double space1 = _baseUnit * 0.5; // 2px
  static const double space2 = _baseUnit * 1; // 4px
  static const double space3 = _baseUnit * 1.5; // 6px
  static const double space4 = _baseUnit * 2; // 8px
  static const double space5 = _baseUnit * 2.5; // 10px
  static const double space6 = _baseUnit * 3; // 12px
  static const double space7 = _baseUnit * 3.5; // 14px
  static const double space8 = _baseUnit * 4; // 16px
  static const double space9 = _baseUnit * 4.5; // 18px
  static const double space10 = _baseUnit * 5; // 20px
  static const double space11 = _baseUnit * 5.5; // 22px
  static const double space12 = _baseUnit * 6; // 24px
  static const double space14 = _baseUnit * 7; // 28px
  static const double space16 = _baseUnit * 8; // 32px
  static const double space18 = _baseUnit * 9; // 36px
  static const double space20 = _baseUnit * 10; // 40px
  static const double space24 = _baseUnit * 12; // 48px
  static const double space28 = _baseUnit * 14; // 56px
  static const double space32 = _baseUnit * 16; // 64px
  static const double space36 = _baseUnit * 18; // 72px
  static const double space40 = _baseUnit * 20; // 80px
  static const double space48 = _baseUnit * 24; // 96px
  static const double space56 = _baseUnit * 28; // 112px
  static const double space64 = _baseUnit * 32; // 128px

  /// Semantic spacing aliases
  static const double none = space0;
  static const double xs = space1; // 2px
  static const double sm = space2; // 4px
  static const double md = space4; // 8px
  static const double lg = space6; // 12px
  static const double xl = space8; // 16px
  static const double xxl = space12; // 24px
  static const double xxxl = space16; // 32px

  /// Component-specific spacing
  static const double inline = space2; // 4px - between inline elements
  static const double tight = space3; // 6px - tight grouping
  static const double cozy = space4; // 8px - comfortable grouping
  static const double comfortable = space6; // 12px - standard grouping
  static const double relaxed = space8; // 16px - generous grouping
  static const double spacious = space12; // 24px - section separation
  static const double expansive = space16; // 32px - major section separation

  /// Layout spacing
  static const double pagePadding = space16; // 32px - screen edges
  static const double pagePaddingMobile = space12; // 24px - mobile screen edges
  static const double sectionGap = space20; // 40px - between major sections
  static const double componentGap = space12; // 24px - between components
  static const double groupGap = space8; // 16px - between related groups
  static const double itemGap = space4; // 8px - between list items
  static const double chipGap = space2; // 4px - between chips/tags

  /// Inset/padding presets
  static const EdgeInsets insetXs = EdgeInsets.all(space2); // 4px
  static const EdgeInsets insetSm = EdgeInsets.all(space3); // 6px
  static const EdgeInsets insetMd = EdgeInsets.all(space4); // 8px
  static const EdgeInsets insetLg = EdgeInsets.all(space6); // 12px
  static const EdgeInsets insetXl = EdgeInsets.all(space8); // 16px
  static const EdgeInsets insetXxl = EdgeInsets.all(space12); // 24px

  static const EdgeInsets insetHorizontalSm = EdgeInsets.symmetric(horizontal: space4); // 8px
  static const EdgeInsets insetHorizontalMd = EdgeInsets.symmetric(horizontal: space6); // 12px
  static const EdgeInsets insetHorizontalLg = EdgeInsets.symmetric(horizontal: space8); // 16px
  static const EdgeInsets insetHorizontalXl = EdgeInsets.symmetric(horizontal: space12); // 24px

  static const EdgeInsets insetVerticalSm = EdgeInsets.symmetric(vertical: space3); // 6px
  static const EdgeInsets insetVerticalMd = EdgeInsets.symmetric(vertical: space4); // 8px
  static const EdgeInsets insetVerticalLg = EdgeInsets.symmetric(vertical: space6); // 12px
  static const EdgeInsets insetVerticalXl = EdgeInsets.symmetric(vertical: space8); // 16px

  static const EdgeInsets insetPage = EdgeInsets.all(space16); // 32px
  static const EdgeInsets insetPageMobile = EdgeInsets.all(space12); // 24px

  /// Border radius scale
  static const double radiusNone = 0;
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 24;
  static const double radiusXxxl = 28;
  static const double radiusFull = 9999;

  /// Semantic radius aliases
  static const double radiusChip = radiusSm; // 8px
  static const double radiusButton = radiusMd; // 12px
  static const double radiusInput = radiusMd; // 12px
  static const double radiusCard = radiusLg; // 16px
  static const double radiusPanel = radiusXl; // 20px
  static const double radiusModal = radiusXxl; // 24px
  static const double radiusTooltip = radiusSm; // 8px

  /// Border width scale
  static const double borderHairline = 0.5;
  static const double borderThin = 1;
  static const double borderMedium = 1.5;
  static const double borderThick = 2;
  static const double borderHeavy = 3;

  /// Icon sizes
  static const double iconXs = 12;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 28;
  static const double iconXxl = 32;
  static const double iconXxxl = 40;

  /// Avatar sizes
  static const double avatarXs = 24;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 48;
  static const double avatarXl = 56;
  static const double avatarXxl = 72;

  /// Touch target minimums (accessibility)
  static const double touchTargetMin = 44; // iOS HIG / Material minimum
  static const double touchTargetComfortable = 48;
  static const double touchTargetGenerous = 56;

  /// Height presets
  static const double heightXs = 24;
  static const double heightSm = 32;
  static const double heightMd = 40;
  static const double heightLg = 48;
  static const double heightXl = 56;
  static const double heightXxl = 64;
  static const double heightInput = heightMd; // 40px
  static const double heightButton = heightLg; // 48px
  static const double heightButtonLarge = heightXl; // 56px

  /// Width constraints
  static const double widthInputMin = 120;
  static const double widthInputMax = 400;
  static const double widthButtonMin = 88;
  static const double widthCardMax = 480;
  static const double widthContentMax = 720;
  static const double widthContentWide = 960;

  /// Animation durations
  static const Duration durationInstant = Duration(milliseconds: 0);
  static const Duration durationFast = Duration(milliseconds: 100);
  static const Duration durationNormal = Duration(milliseconds: 200);
  static const Duration durationSlow = Duration(milliseconds: 300);
  static const Duration durationSlower = Duration(milliseconds: 500);
  static const Duration durationPageTransition = Duration(milliseconds: 300);

  /// Animation curves
  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInCubic;
  static const Curve curveSharp = Curves.easeInOut;
  static const Curve curveSpring = Curves.elasticOut;

  /// Z-index layers
  static const int zBase = 0;
  static const int zRaised = 10;
  static const int zDropdown = 100;
  static const int zSticky = 200;
  static const int zOverlay = 300;
  static const int zModal = 400;
  static const int zPopover = 500;
  static const int zTooltip = 600;
  static const int zToast = 700;
  static const int zOverlayWindow = 1000; // FlutterOverlayWindow

  /// Breakpoints for responsive design
  static const double bpMobile = 480;
  static const double bpTablet = 768;
  static const double bpDesktop = 1024;
  static const double bpWide = 1440;

  /// Check if width is mobile
  static bool isMobile(double width) => width < bpTablet;
  static bool isTablet(double width) => width >= bpTablet && width < bpDesktop;
  static bool isDesktop(double width) => width >= bpDesktop;
}

/// Component dimension tokens - reusable sizing
class CypherDimensions {
  // Chat bubbles
  static const double chatBubbleMaxWidth = 0.75; // 75% of container
  static const double chatBubbleMinWidth = 60;
  static const double chatAvatarSize = CypherSpacing.avatarMd; // 40px
  static const double chatGap = CypherSpacing.space8; // 16px between messages

  // Composer
  static const double composerMinHeight = 56;
  static const double composerMaxHeight = 160;
  static const double composerPadding = CypherSpacing.space12; // 24px
  static const double composerInputPadding = CypherSpacing.space4; // 8px
  static const double composerButtonSize = 40;

  // Settings
  static const double settingsSectionSpacing = CypherSpacing.space20; // 40px
  static const double settingsItemSpacing = CypherSpacing.space12; // 24px
  static const double settingsRowHeight = 56;
  static const double settingsIconSize = CypherSpacing.iconLg; // 24px

  // Navigation
  static const double navBarHeight = 64;
  static const double navBarHeightMobile = 56;
  static const double navItemSpacing = CypherSpacing.space4; // 8px
  static const double navIndicatorHeight = 3;

  // Overlay
  static const double orbSize = 60;
  static const double orbSizeExpanded = 120;
  static const double orbMenuWidth = 280;
  static const double orbMenuItemHeight = 48;

  // Cards
  static const double cardPadding = CypherSpacing.space16; // 32px
  static const double cardSpacing = CypherSpacing.space12; // 24px

  // Lists
  static const double listItemHeight = 56;
  static const double listItemHeightDense = 48;
  static const double listDividerIndent = CypherSpacing.space16; // 32px

  // Dialogs/Modals
  static const double dialogMaxWidth = 400;
  static const double dialogPadding = CypherSpacing.space24; // 48px
  static const double dialogBorderRadius = CypherSpacing.radiusModal; // 24px

  // Tooltips
  static const double tooltipMaxWidth = 280;
  static const double tooltipPadding = space4; // 8px all
  static const double tooltipArrowSize = 8;

  // Snackbars/Toasts
  static const double snackbarMinWidth = 288;
  static const double snackbarMaxWidth = 568;
  static const double snackbarPadding = space6; // 12px all
}