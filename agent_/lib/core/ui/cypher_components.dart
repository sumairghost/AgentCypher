/// Agent Cypher reusable UI components.
///
/// Every component consumes the semantic tokens from `lib/core/theme/` —
/// never hardcoded colors. See `.claude/skills/cypher-ui-design/SKILL.md`.

import 'package:flutter/material.dart';
import '../theme/cypher_theme.dart';

/// Ambient page background: token gradient plus two faint accent glows.
///
/// Deliberately does NOT use BackdropFilter — the atmosphere must remain
/// cheap to render behind scrolling content.
class CypherBackground extends StatelessWidget {
  final Widget child;

  const CypherBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final accent = c.colors.accent;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: c.gradients.backgroundGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -CypherSpacing.space64 * 2,
            right: -CypherSpacing.space64,
            child: _GlowCircle(size: 280, color: accent, opacity: 0.10),
          ),
          Positioned(
            bottom: -CypherSpacing.space64 * 3,
            left: -CypherSpacing.space64 * 2,
            child: _GlowCircle(size: 340, color: accent, opacity: 0.07),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(opacity * 0.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Glass material surface. Blur is opt-in and intended for small surfaces
/// (composer, floating controls, sheets) — never behind scrolling text.
class CypherGlass extends StatelessWidget {
  final Widget child;
  final bool blur;
  final GlassSpec? spec;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const CypherGlass({
    super.key,
    required this.child,
    this.blur = false,
    this.spec,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final glass = spec ?? c.defaultGlassSpec;
    final radius = borderRadius ?? BorderRadius.circular(CypherSpacing.radiusLg);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: glass.surfaceColor,
        borderRadius: radius,
        border: Border.all(color: c.colors.glassBorder, width: 1),
      ),
      child: child,
    );

    if (blur) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: glass.backdropFilterLight,
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Token-styled card with optional tap behaviour.
class CypherCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius? borderRadius;

  const CypherCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final radius =
        borderRadius ?? BorderRadius.circular(CypherSpacing.radiusLg);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? c.colors.surface,
        borderRadius: radius,
        border: Border.all(color: c.colors.borderLight, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Primary action button with token styling and a 48dp minimum height.
class CypherButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final CypherButtonVariant variant;
  final bool expand;

  const CypherButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = CypherButtonVariant.primary,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;

    final (Color background, Color foreground, BorderSide side) =
        switch (variant) {
      CypherButtonVariant.primary => (
          c.colors.accent,
          c.colors.textOnAccent,
          BorderSide.none,
        ),
      CypherButtonVariant.secondary => (
          c.colors.surfaceContainerHigh,
          c.colors.textPrimary,
          BorderSide(color: c.colors.borderLight),
        ),
      CypherButtonVariant.ghost => (
          Colors.transparent,
          c.colors.accent,
          BorderSide.none,
        ),
      CypherButtonVariant.danger => (
          c.colors.errorContainer,
          c.colors.errorOnContainer,
          BorderSide.none,
        ),
    };

    final enabled = onPressed != null && !loading;

    final button = SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? background : c.colors.surfaceContainer,
          foregroundColor: enabled ? foreground : c.colors.textTertiary,
          elevation: 0,
          textStyle: c.typography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
            side: side,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: CypherSpacing.space8,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.colors.textTertiary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: CypherSpacing.space3),
                  ],
                  Text(label),
                ],
              ),
      ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

enum CypherButtonVariant { primary, secondary, ghost, danger }

/// Circular icon button with a guaranteed ≥44dp touch target.
class CypherIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final Color? color;
  final double size;

  const CypherIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
    this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final effectiveColor =
        color ?? (selected ? c.colors.accent : c.colors.textSecondary);

    final button = SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size),
        color: effectiveColor,
        disabledColor: c.colors.textTertiary,
        splashRadius: 24,
        padding: EdgeInsets.zero,
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Token-styled text field.
class CypherInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const CypherInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: c.typography.inputText,
      cursorColor: c.colors.accent,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: c.typography.inputLabel,
        hintStyle: c.typography.helperText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: c.colors.textTertiary),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.colors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CypherSpacing.space6,
          vertical: CypherSpacing.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
          borderSide: BorderSide(color: c.colors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
          borderSide: BorderSide(color: c.colors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
          borderSide: BorderSide(color: c.colors.accent, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
          borderSide: BorderSide(color: c.colors.border.withOpacity(0.4)),
        ),
      ),
    );
  }
}

/// Opens a token-styled modal bottom sheet. Keyboard-aware and safe-area
/// aware. Returns the future from [showModalBottomSheet].
Future<T?> showCypherSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = true,
}) {
  final c = context.cypher;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: c.colors.surface,
    barrierColor: c.colors.scrim,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(CypherSpacing.radiusModal),
      ),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(
                      top: CypherSpacing.space3,
                      bottom: CypherSpacing.space2,
                    ),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.colors.borderStrong,
                      borderRadius: BorderRadius.circular(
                        CypherSpacing.radiusFull,
                      ),
                    ),
                  ),
                ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CypherSpacing.space8,
                      CypherSpacing.space2,
                      CypherSpacing.space8,
                      CypherSpacing.space4,
                    ),
                    child: Text(title, style: c.typography.titleMedium),
                  ),
                builder(sheetContext),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Thin token divider.
class CypherDivider extends StatelessWidget {
  final double indent;
  final double endIndent;

  const CypherDivider({super.key, this.indent = 0, this.endIndent = 0});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Divider(
      height: 1,
      thickness: 1,
      color: c.colors.border.withOpacity(0.5),
      indent: indent,
      endIndent: endIndent,
    );
  }
}

/// Compact pill for tags, filters, and quick toggles.
class CypherChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const CypherChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final background =
        selected ? c.colors.accentContainer : c.colors.surfaceContainer;
    final foreground = selected ? c.colors.accent : c.colors.textSecondary;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(CypherSpacing.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CypherSpacing.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CypherSpacing.space5,
            vertical: CypherSpacing.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: CypherSpacing.space2),
              ],
              Text(
                label,
                style: c.typography.labelMedium.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular avatar with initials or an icon, on an accent container.
class CypherAvatar extends StatelessWidget {
  final String? initials;
  final IconData? icon;
  final double size;

  const CypherAvatar({super.key, this.initials, this.icon, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.colors.accentContainer,
      ),
      alignment: Alignment.center,
      child: initials != null
          ? Text(
              initials!,
              style: c.typography.labelLarge.copyWith(
                color: c.colors.accentOnContainer,
                fontSize: size * 0.36,
              ),
            )
          : Icon(
              icon ?? Icons.auto_awesome,
              size: size * 0.5,
              color: c.colors.accentOnContainer,
            ),
    );
  }
}

/// Overline-style section label with optional trailing control.
class CypherSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const CypherSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Padding(
      padding: const EdgeInsets.only(
        top: CypherSpacing.space8,
        bottom: CypherSpacing.space4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: c.typography.labelSmall.copyWith(
                    color: c.colors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: CypherSpacing.space1),
                  Text(
                    subtitle!,
                    style: c.typography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
