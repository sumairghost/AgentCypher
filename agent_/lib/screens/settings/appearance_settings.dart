import 'package:flutter/material.dart';

import '../../core/theme/color_tokens.dart';
import '../../core/theme/cypher_theme.dart';
import '../../core/theme/gradient_tokens.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/ui/cypher_components.dart';

/// Appearance settings (redesign Phases 6, 7, 8, 16).
///
/// Theme selection is visual-first (preset swatch cards) rather than a plain
/// color-name list; gradient controls are kept behind an "Advanced"
/// disclosure so the default experience stays subtle. Every change goes
/// through [themeController], which persists and rebuilds the whole app.
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final c = context.cypher;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text('Appearance', style: c.typography.titleMedium),
          ),
          body: CypherBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(CypherSpacing.space6),
                children: [
                  const _ThemePreview(),
                  CypherSectionHeader(
                    title: 'Theme mode',
                    subtitle:
                        'Dark is the designed default. Light is available for all presets.',
                  ),
                  const _ModeSelector(),
                  CypherSectionHeader(
                    title: 'Theme',
                    subtitle: 'A foundation plus a restrained accent family.',
                  ),
                  const _PresetGrid(),
                  CypherSectionHeader(
                    title: 'Accent',
                    subtitle: 'Curated professional accent families.',
                  ),
                  const _AccentSelector(),
                  CypherSectionHeader(
                    title: 'Custom accent',
                    subtitle:
                        'Curated colors or a color you blend yourself — applied as an accent throughout Cypher.',
                  ),
                  const _CustomAccentSection(),
                  CypherSectionHeader(
                    title: 'Background',
                    subtitle: 'Gradient style used behind the whole app.',
                  ),
                  const _BackgroundStyleSelector(),
                  const _AdvancedBackgroundControls(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Live miniature of the conversation rendered with the active theme.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assistant reply', style: c.typography.bodyMedium),
          const SizedBox(height: CypherSpacing.space2),
          Text('Second line of readable content.', style: c.typography.bodySmall),
          const SizedBox(height: CypherSpacing.space3),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CypherSpacing.space4,
                vertical: CypherSpacing.space2,
              ),
              decoration: BoxDecoration(
                color: c.colors.accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
                border: Border.all(color: c.colors.accent.withOpacity(0.3)),
              ),
              child: Text('Your message', style: c.typography.bodyMedium),
            ),
          ),
          const SizedBox(height: CypherSpacing.space3),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
                    border: Border.all(color: c.colors.glassBorder),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CypherSpacing.space4,
                  ),
                  child: Text('Message Cypher', style: c.typography.helperText),
                ),
              ),
              const SizedBox(width: CypherSpacing.space2),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.colors.accent,
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: c.colors.textOnAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector();

  @override
  Widget build(BuildContext context) {
    final controller = themeController;
    return Wrap(
      spacing: CypherSpacing.space2,
      children: [
        for (final mode in CypherThemeMode.values)
          CypherChip(
            label: switch (mode) {
              CypherThemeMode.system => 'System',
              CypherThemeMode.dark => 'Dark',
              CypherThemeMode.light => 'Light',
            },
            selected: controller.mode == mode,
            onTap: () => controller.setMode(mode),
          ),
      ],
    );
  }
}

class _PresetGrid extends StatelessWidget {
  const _PresetGrid();

  @override
  Widget build(BuildContext context) {
    final activeId = themeController.presetId;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones, three on tablet-width canvases.
        final columns = CypherSpacing.isMobile(constraints.maxWidth) ? 2 : 3;
        const gap = CypherSpacing.space3;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final preset in CypherThemePreset.all)
              SizedBox(
                width: tileWidth,
                child: _PresetTile(
                  preset: preset,
                  selected: preset.id == activeId,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PresetTile extends StatelessWidget {
  final CypherThemePreset preset;
  final bool selected;

  const _PresetTile({required this.preset, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final accent = preset.accentFamily.colors[500]!;
    // The preview shows the foundation each preset is designed for:
    // near-black charcoal, except Platinum which ships as the light preset.
    final previewBg = preset.defaultMode == CypherThemeMode.light
        ? CypherColorPalette.warmWhite100
        : CypherColorPalette.charcoal600;
    final previewText = preset.defaultMode == CypherThemeMode.light
        ? CypherColorPalette.charcoal900
        : CypherColorPalette.warmWhite100;

    return InkWell(
      onTap: () => themeController.setPreset(preset.id),
      borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(CypherSpacing.space3),
        decoration: BoxDecoration(
          color: previewBg,
          borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
          border: Border.all(
            color: selected ? c.colors.accent : c.colors.borderLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.85),
                  ),
                ),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: c.colors.accent,
                  ),
              ],
            ),
            const SizedBox(height: CypherSpacing.space6),
            Text(
              preset.name,
              style: c.typography.labelLarge.copyWith(color: previewText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CypherSpacing.space1),
            Text(
              preset.description,
              style: c.typography.labelSmall.copyWith(
                color: previewText.withOpacity(0.55),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSelector extends StatelessWidget {
  const _AccentSelector();

  @override
  Widget build(BuildContext context) {
    final current = themeController.accentFamily;
    return Wrap(
      spacing: CypherSpacing.space2,
      runSpacing: CypherSpacing.space2,
      children: [
        for (final family in AccentFamily.values)
          CypherChip(
            label: family.displayName,
            selected: family == current,
            onTap: () => themeController.setAccentFamily(family),
          ),
      ],
    );
  }
}

class _BackgroundStyleSelector extends StatelessWidget {
  const _BackgroundStyleSelector();

  @override
  Widget build(BuildContext context) {
    final controller = themeController;
    return Wrap(
      spacing: CypherSpacing.space2,
      runSpacing: CypherSpacing.space2,
      children: [
        for (final style in GradientStyle.values)
          CypherChip(
            label: switch (style) {
              GradientStyle.ambient => 'Ambient',
              GradientStyle.radial => 'Radial',
              GradientStyle.linear => 'Linear',
              GradientStyle.dualGlow => 'Dual glow',
              GradientStyle.subtleMesh => 'Subtle mesh',
            },
            selected: controller.gradientStyle == style,
            onTap: () => controller.setGradientStyle(style),
          ),
      ],
    );
  }
}

/// Gradient intensity / softness live behind this disclosure so the default
/// experience remains the designer-tuned preset values.
class _AdvancedBackgroundControls extends StatelessWidget {
  const _AdvancedBackgroundControls();

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final controller = themeController;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: CypherSpacing.space4),
        title: Text(
          'Advanced background controls',
          style: c.typography.settingsItemTitle,
        ),
        subtitle: Text(
          'Keep values low for readability and battery life.',
          style: c.typography.settingsItemSubtitle,
        ),
        iconColor: c.colors.textTertiary,
        collapsedIconColor: c.colors.textTertiary,
        children: [
          Text(
            'Gradient intensity: ${controller.gradientIntensity.name}',
            style: c.typography.bodyMedium,
          ),
          Slider(
            value: controller.gradientIntensity.index.toDouble(),
            min: 0,
            max: (GradientIntensity.values.length - 1).toDouble(),
            divisions: GradientIntensity.values.length - 1,
            label: controller.gradientIntensity.name,
            onChanged: (value) => controller.setGradientIntensity(
              GradientIntensity.values[value.round()],
            ),
          ),
          Text(
            'Glow softness: ${controller.gradientBlur.round()}',
            style: c.typography.bodyMedium,
          ),
          Slider(
            value: controller.gradientBlur,
            min: 0,
            max: 200,
            label: controller.gradientBlur.round().toString(),
            onChanged: (value) => controller.setGradientBlur(value),
          ),
        ],
      ),
    );
  }
}

/// Custom accent: a curated professional palette plus an advanced HSV
/// blender. Selecting either applies a live custom accent through the theme
/// controller; components, gradients, and the voice orb all follow it.
///
/// The constant colors below are the *user-facing picker data* (the palette
/// of colors to choose from), not theme styling, so they are intentionally
/// independent of the active preset.
class _CustomAccentSection extends StatelessWidget {
  const _CustomAccentSection();

  static const List<Color> _curated = <Color>[
    Color(0xFF9F263D), // Crimson
    Color(0xFFC73E4C), // Ruby
    Color(0xFFA02542), // Burgundy
    Color(0xFF72253D), // Wine
    Color(0xFF7A3B69), // Plum
    Color(0xFFBF5A6C), // Rose
    Color(0xFFB25E3C), // Copper
    Color(0xFFC9862B), // Amber
    Color(0xFFC9A227), // Gold
    Color(0xFF5560B5), // Indigo
    Color(0xFF3F5C9E), // Navy
    Color(0xFF5A6B7C), // Slate
    Color(0xFF746E66), // Graphite
    Color(0xFF9A9790), // Silver
  ];

  @override
  Widget build(BuildContext context) {
    final controller = themeController;
    final isCustom = controller.isCustomAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: CypherSpacing.space2,
          runSpacing: CypherSpacing.space2,
          children: [
            for (final color in _curated)
              _SwatchCircle(
                color: color,
                selected: isCustom && controller.customAccent == color,
                onTap: () => controller.setCustomAccent(color),
              ),
          ],
        ),
        const SizedBox(height: CypherSpacing.space6),
        const _CustomColorBlender(),
        if (isCustom) ...[
          const SizedBox(height: CypherSpacing.space4),
          OutlinedButton.icon(
            onPressed: controller.clearCustomAccent,
            icon: const Icon(Icons.undo_rounded, size: 16),
            label: const Text('Use the preset accent instead'),
          ),
        ],
      ],
    );
  }
}

class _SwatchCircle extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SwatchCircle({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? c.colors.textPrimary : c.colors.borderLight,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

/// Dependency-free HSV color blender with a live preview swatch.
class _CustomColorBlender extends StatefulWidget {
  const _CustomColorBlender();

  @override
  State<_CustomColorBlender> createState() => _CustomColorBlenderState();
}

class _CustomColorBlenderState extends State<_CustomColorBlender> {
  double _hue = 350; // crimson-ish seed
  double _sat = 0.52;
  double _val = 0.5;

  Color get _preview => HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: CypherSpacing.space4),
        title: Text(
          'Blend a custom color',
          style: c.typography.settingsItemTitle,
        ),
        subtitle: Text(
          'Hue, saturation, and lightness — applied as the accent.',
          style: c.typography.settingsItemSubtitle,
        ),
        iconColor: c.colors.textTertiary,
        collapsedIconColor: c.colors.textTertiary,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _preview,
                  border: Border.all(color: c.colors.borderLight),
                ),
              ),
              const SizedBox(width: CypherSpacing.space4),
              Expanded(
                child: Text(
                  '#${(_preview.value.toRadixString(16).padLeft(8, '0')).substring(2).toUpperCase()}',
                  style: c.typography.bodyMedium,
                ),
              ),
              CypherButton(
                label: 'Apply',
                variant: CypherButtonVariant.secondary,
                onPressed: () => themeController.setCustomAccent(_preview),
              ),
            ],
          ),
          const SizedBox(height: CypherSpacing.space4),
          _SliderRow(
            label: 'Hue',
            value: _hue,
            min: 0,
            max: 360,
            onChanged: (v) => setState(() => _hue = v),
          ),
          _SliderRow(
            label: 'Saturation',
            value: _sat,
            min: 0,
            max: 1,
            onChanged: (v) => setState(() => _sat = v),
          ),
          _SliderRow(
            label: 'Lightness',
            value: _val,
            min: 0.05,
            max: 0.85,
            onChanged: (v) => setState(() => _val = v),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: c.typography.settingsItemSubtitle),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
