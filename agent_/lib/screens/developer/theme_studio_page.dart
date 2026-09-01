import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/gradient_tokens.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/ui/cypher_components.dart';
import '../../core/ui/cypher_voice_orb.dart';
import '../../services/settings_service.dart';

/// Developer Theme Studio (Phase 8).
///
/// Bound exclusively to the existing [ThemeController] token architecture â€”
/// presets, custom accent, gradient style, intensity and blur are the real
/// persisted values the whole app renders with. The token inspector is
/// read-only evidence of what the tokens resolve to; it does not bypass the
/// system with raw overrides (per the developer-console skill contract).
class ThemeStudioPage extends StatefulWidget {
  const ThemeStudioPage({super.key});

  @override
  State<ThemeStudioPage> createState() => _ThemeStudioPageState();
}

class _ThemeStudioPageState extends State<ThemeStudioPage> {
  final SettingsService _settings = SettingsService();

  Future<void> _persistMode(String mode) async {
    try {
      await _settings.init();
      await _settings.setThemeMode(mode);
    } catch (_) {
      // Persistence is best-effort here; the controller already persists via
      // its own preference keys.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final controller = themeController;
        final c = context.cypher;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text('Theme Studio', style: c.typography.titleMedium),
          ),
          body: CypherBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(CypherSpacing.space6),
                children: [
                  const _LivePreview(),
                  CypherSectionHeader(
                    title: 'Mode',
                    subtitle: 'Brightness used by the material theme pair.',
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'system', label: Text('System')),
                      ButtonSegment(value: 'dark', label: Text('Dark')),
                      ButtonSegment(value: 'light', label: Text('Light')),
                    ],
                    selected: {controller.mode.name},
                    onSelectionChanged: (s) {
                      final value = s.first;
                      switch (value) {
                        case 'dark':
                          controller.setMode(CypherThemeMode.dark);
                          break;
                        case 'light':
                          controller.setMode(CypherThemeMode.light);
                          break;
                        default:
                          controller.setMode(CypherThemeMode.system);
                      }
                      _persistMode(value);
                    },
                  ),
                  CypherSectionHeader(
                    title: 'Presets',
                    subtitle:
                        'Crimson Night, Obsidian, Burgundy, Midnight, Ember, Platinum.',
                  ),
                  _PresetGrid(
                    presets: CypherThemePreset.all,
                    selectedId: controller.presetId,
                    onSelect: controller.setPreset,
                  ),
                  CypherSectionHeader(
                    title: 'Custom accent',
                    subtitle:
                        'Overrides the preset accent family everywhere (derived '
                        'shades, gradients, orb included).',
                  ),
                  _CustomAccentControls(controller: controller),
                  CypherSectionHeader(
                    title: 'Gradient',
                    subtitle: 'Ambient, radial, linear, dual glow, subtle mesh.',
                  ),
                  _GradientStyleSelector(controller: controller),
                  CypherSectionHeader(
                    title: 'Fine controls',
                    subtitle: 'Intensity, blur softness, and flow position.',
                  ),
                  _GradientFineControls(controller: controller),
                  CypherSectionHeader(
                    title: 'Token inspector',
                    subtitle:
                        'Read-only resolution of the active semantic tokens.',
                  ),
                  _TokenInspector(controller: controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


/// Live miniature conversation + orb rendered with the active tokens.
class _LivePreview extends StatelessWidget {
  const _LivePreview();

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CypherVoiceOrb(state: CypherVoiceOrbState.listening, size: 84),
          const SizedBox(width: CypherSpacing.space5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant reply preview', style: c.typography.bodyMedium),
                const SizedBox(height: CypherSpacing.space2),
                Text('Readable body text over the active background.',
                    style: c.typography.bodySmall),
                const SizedBox(height: CypherSpacing.space3),
                Row(
                  children: [
                    CypherButton(
                      label: 'Primary',
                      variant: CypherButtonVariant.primary,
                      onPressed: () {},
                    ),
                    const SizedBox(width: CypherSpacing.space3),
                    CypherButton(
                      label: 'Secondary',
                      variant: CypherButtonVariant.secondary,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// All six built-in presets as swatch cards.
class _PresetGrid extends StatelessWidget {
  final List<CypherThemePreset> presets;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _PresetGrid({
    required this.presets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Column(
      children: [
        for (final preset in presets)
          Padding(
            padding: const EdgeInsets.only(bottom: CypherSpacing.space2),
            child: CypherCard(
              color: Colors.transparent,
              padding: EdgeInsets.zero,
              onTap: () => onSelect(preset.id),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(width: CypherSpacing.space4),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: preset.accentFamily.colors[400],
                        border: Border.all(color: c.colors.borderLight),
                      ),
                    ),
                    const SizedBox(width: CypherSpacing.space4),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.name, style: c.typography.settingsItemTitle),
                          Text(
                            preset.description,
                            style: c.typography.settingsItemSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (preset.id == selectedId)
                      Icon(Icons.check_circle_rounded,
                          color: c.colors.accent, size: 20),
                    const SizedBox(width: CypherSpacing.space4),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Curated swatches + HSV blender for the custom accent.
class _CustomAccentControls extends StatelessWidget {
  final ThemeController controller;

  /// Curated, professional seeds (restrained â€” no neon).
  static const List<Color> curated = [
    Color(0xFF8C1D2C), // deep crimson
    Color(0xFF6B2737), // burgundy wine
    Color(0xFF8A4B2A), // ember copper
    Color(0xFF31456E), // restrained navy
    Color(0xFF4E5D6C), // graphite blue
    Color(0xFF5C5C5C), // neutral graphite
    Color(0xFF7A6A54), // warm taupe
    Color(0xFF3E5E52), // muted pine
  ];

  const _CustomAccentControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: CypherSpacing.space3,
            runSpacing: CypherSpacing.space3,
            children: [
              for (final color in curated)
                _AccentSwatch(
                  color: color,
                  selected: controller.customAccent == color,
                  onSelect: () => controller.setCustomAccent(color),
                ),
            ],
          ),
          const SizedBox(height: CypherSpacing.space4),
          const _HsvBlender(),
          const SizedBox(height: CypherSpacing.space3),
          Text(
            controller.isCustomAccent
                ? 'Custom accent active â€” derived shades update everywhere.'
                : 'Using the preset accent family.',
            style: c.typography.settingsItemSubtitle,
          ),
          const SizedBox(height: CypherSpacing.space3),
          CypherButton(
            label: 'Return to preset accent',
            variant: CypherButtonVariant.secondary,
            onPressed:
                controller.isCustomAccent ? controller.clearCustomAccent : null,
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onSelect;

  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Accent color',
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(CypherSpacing.radiusFull),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? c.colors.textPrimary : c.colors.borderLight,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded,
                  size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// HSV sliders that apply through the token controller (never raw).
class _HsvBlender extends StatefulWidget {
  const _HsvBlender();

  @override
  State<_HsvBlender> createState() => _HsvBlenderState();
}

class _HsvBlenderState extends State<_HsvBlender> {
  double _hue = 350;
  double _sat = 0.52;
  double _val = 0.5;

  Color get _preview => HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _preview,
                border: Border.all(color: c.colors.borderLight),
              ),
            ),
            const SizedBox(width: CypherSpacing.space3),
            Expanded(
              child: Text(
                '#${_preview.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: c.typography.monoMedium,
              ),
            ),
            CypherButton(
              label: 'Apply',
              variant: CypherButtonVariant.secondary,
              onPressed: () => themeController.setCustomAccent(_preview),
            ),
          ],
        ),
        const SizedBox(height: CypherSpacing.space3),
        _StudioSlider(
            label: 'Hue', value: _hue, min: 0, max: 360,
            onChanged: (v) => setState(() => _hue = v)),
        _StudioSlider(
            label: 'Saturation', value: _sat, min: 0, max: 1,
            onChanged: (v) => setState(() => _sat = v)),
        _StudioSlider(
            label: 'Value', value: _val, min: 0.05, max: 0.85,
            onChanged: (v) => setState(() => _val = v)),
      ],
    );
  }
}

class _StudioSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _StudioSlider({
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
          width: 92,
          child: Text(label, style: c.typography.settingsItemSubtitle),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            label: label,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// The five supported gradient styles.
class _GradientStyleSelector extends StatelessWidget {
  final ThemeController controller;

  const _GradientStyleSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final entries = <(GradientStyle, String)>[
      (GradientStyle.ambient, 'Ambient'),
      (GradientStyle.radial, 'Radial'),
      (GradientStyle.linear, 'Linear'),
      (GradientStyle.dualGlow, 'Dual glow'),
      (GradientStyle.subtleMesh, 'Subtle mesh'),
    ];
    return Wrap(
      spacing: CypherSpacing.space2,
      runSpacing: CypherSpacing.space2,
      children: [
        for (final (style, label) in entries)
          ChoiceChip(
            label: Text(label),
            selected: controller.gradientStyle == style,
            onSelected: (_) => controller.setGradientStyle(style),
          ),
      ],
    );
  }
}

/// Fine controls. Position and flow are derived from the chosen style by the
/// token system itself â€” no separate fake sliders.
class _GradientFineControls extends StatelessWidget {
  final ThemeController controller;

  const _GradientFineControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Intensity (opacity)', style: c.typography.settingsItemTitle),
          const SizedBox(height: CypherSpacing.space2),
          Wrap(
            spacing: CypherSpacing.space2,
            children: [
              for (final intensity in GradientIntensity.values)
                ChoiceChip(
                  label: Text(intensity.name),
                  selected: controller.gradientIntensity == intensity,
                  onSelected: (_) =>
                      controller.setGradientIntensity(intensity),
                ),
            ],
          ),
          const SizedBox(height: CypherSpacing.space4),
          Text('Softness (blur radius)',
              style: c.typography.settingsItemTitle),
          Slider(
            value: controller.gradientBlur.clamp(0, 200).toDouble(),
            min: 0,
            max: 200,
            divisions: 40,
            label: controller.gradientBlur.round().toString(),
            onChanged: controller.setGradientBlur,
          ),
          Text(
            'Position and flow follow the selected gradient style.',
            style: c.typography.settingsItemSubtitle,
          ),
        ],
      ),
    );
  }
}

/// Read-only evidence of what the tokens currently resolve to.
class _TokenInspector extends StatelessWidget {
  final ThemeController controller;

  const _TokenInspector({required this.controller});

  String _hex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final colors = c.colors;
    final rows = <String, String>{
      'preset': controller.presetId,
      'accent': _hex(colors.accent),
      'accentLight': _hex(colors.accentLight),
      'accentDark': _hex(colors.accentDark),
      'accentContainer': _hex(colors.accentContainer),
      'background': _hex(colors.background),
      'surface': _hex(colors.surface),
      'surfaceElevated': _hex(colors.surfaceElevated),
      'border': _hex(colors.border),
      'textPrimary': _hex(colors.textPrimary),
      'glass': _hex(colors.glass),
    };
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Column(
        children: [
          for (final entry in rows.entries)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: CypherSpacing.space1),
              child: Row(
                children: [
                  SizedBox(
                    width: 148,
                    child: Text(
                      entry.key,
                      style: c.typography.labelMedium
                          .copyWith(color: c.colors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: c.typography.monoMedium
                          .copyWith(color: c.colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
