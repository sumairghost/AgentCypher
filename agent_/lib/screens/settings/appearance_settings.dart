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
