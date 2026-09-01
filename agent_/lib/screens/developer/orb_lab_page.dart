import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../core/ui/cypher_voice_orb.dart';
import '../../core/ui/orb_config.dart';
import '../../services/developer_config_service.dart';

/// Orb Lab (Phase 5): interactive development tool for the REAL procedural
/// orb. This page never re-implements rendering â€” it drives the same
/// [CypherVoiceOrb] the app uses through [CypherOrbConfig] and
/// [CypherOrbController]. Configurations persist as developer-only profiles
/// (Phase 6) via [CypherDeveloperConfig].
class OrbLabPage extends StatefulWidget {
  const OrbLabPage({super.key});

  @override
  State<OrbLabPage> createState() => _OrbLabPageState();
}

class _OrbLabPageState extends State<OrbLabPage> {
  final CypherOrbController _orbController = CypherOrbController();
  final TextEditingController _profileName = TextEditingController();

  CypherVoiceOrbState _state = CypherVoiceOrbState.idle;
  CypherOrbConfig _config = const CypherOrbConfig.standard();
  bool _paused = false;
  bool _simulatingAudio = false;
  double _audio = 0;
  Timer? _audioTimer;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    await developerConfig.ensureInitialized();
    if (!mounted) return;
    setState(() {
      final saved = developerConfig.orbLabConfig;
      if (saved != null) {
        _config = saved;
      }
      _configLoaded = true;
    });
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    _profileName.dispose();
    if (_configLoaded) {
      unawaited(developerConfig.setOrbLabConfig(_config));
    }
    super.dispose();
  }

  void _updateConfig(CypherOrbConfig config) {
    setState(() => _config = config);
  }

  void _toggleAudioSimulation() {
    if (_simulatingAudio) {
      _audioTimer?.cancel();
      _audioTimer = null;
      setState(() {
        _simulatingAudio = false;
        _audio = 0;
      });
      return;
    }
    final random = math.Random();
    setState(() => _simulatingAudio = true);
    _audioTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        _audio = (0.25 + random.nextDouble() * 0.75).clamp(0.0, 1.0);
      });
    });
  }

  void _simulateTouch() {
    if (!_orbController.isAttached) return;
    _orbController.beginTouch(0.45, -0.35);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _orbController.moveTouch(0.1, 0.2);
    });
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (mounted) _orbController.moveTouch(-0.3, 0.4);
    });
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _orbController.endTouch();
    });
  }

  void _setPaused(bool paused) {
    HapticFeedback.selectionClick();
    setState(() => _paused = paused);
  }

  @override
  Widget build(BuildContext context) => _orbLabBuild(context);
}

extension _OrbLabBuildSection on _OrbLabPageState {
  Widget _orbLabBuild(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Orb Lab', style: c.typography.titleMedium),
        actions: [
          IconButton(
            tooltip: _paused ? 'Play' : 'Pause',
            onPressed: () => _setPaused(!_paused),
            icon: Icon(_paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded),
          ),
          IconButton(
            tooltip: 'Reset configuration',
            onPressed: () async {
              await developerConfig.setOrbLabConfig(null);
              if (!mounted) return;
              setState(() {
                _config = const CypherOrbConfig.standard();
                _state = CypherVoiceOrbState.idle;
                _audio = 0;
              });
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CypherSpacing.space6),
            children: [
              Center(
                child: CypherVoiceOrb(
                  state: _state,
                  audioLevel: _audio,
                  size: 180,
                  config: _config,
                  controller: _orbController,
                  paused: _paused,
                  semanticLabel: 'Orb lab preview in ${_state.name} state',
                ),
              ),
              const SizedBox(height: CypherSpacing.space4),
              Wrap(
                spacing: CypherSpacing.space3,
                runSpacing: CypherSpacing.space3,
                alignment: WrapAlignment.center,
                children: [
                  CypherButton(
                    label: _simulatingAudio
                        ? 'Stop audio sim'
                        : 'Simulate audio',
                    variant: CypherButtonVariant.secondary,
                    icon: Icons.graphic_eq_rounded,
                    onPressed: _toggleAudioSimulation,
                  ),
                  CypherButton(
                    label: 'Simulate touch',
                    variant: CypherButtonVariant.secondary,
                    icon: Icons.touch_app_rounded,
                    onPressed: _simulateTouch,
                  ),
                  CypherButton(
                    label: 'Trigger tap',
                    variant: CypherButtonVariant.secondary,
                    icon: Icons.ads_click_rounded,
                    onPressed: _orbController.pulse,
                  ),
                  CypherButton(
                    label: 'Trigger swipe',
                    variant: CypherButtonVariant.secondary,
                    icon: Icons.swipe_right_rounded,
                    onPressed: () => _orbController.swipe(180, 0),
                  ),
                  CypherButton(
                    label: 'Trigger error',
                    variant: CypherButtonVariant.danger,
                    icon: Icons.error_outline_rounded,
                    onPressed: () =>
                        setState(() => _state = CypherVoiceOrbState.error),
                  ),
                ],
              ),
              CypherSectionHeader(
                title: 'State',
                subtitle:
                    'Drives the same state profiles the voice runtime uses.',
              ),
              Wrap(
                spacing: CypherSpacing.space2,
                runSpacing: CypherSpacing.space2,
                children: [
                  for (final state in CypherVoiceOrbState.values)
                    ChoiceChip(
                      label: Text(state.name.toUpperCase()),
                      selected: _state == state,
                      onSelected: (_) => setState(() => _state = state),
                    ),
                ],
              ),
              CypherSectionHeader(
                title: 'State energy overrides',
                subtitle:
                    'Sliders override the built-in per-state energy; clear '
                    'restores the stock profiles.',
              ),
              _EnergySliders(config: _config, onChanged: _updateConfig),
              CypherSectionHeader(
                title: 'Material & motion',
                subtitle:
                    'Live multipliers over the real renderer â€” no duplicated '
                    'painter exists.',
              ),
              _MultiplierSliders(config: _config, onChanged: _updateConfig),
              CypherSectionHeader(
                title: 'Profiles',
                subtitle:
                    'Saved developer-only orb configurations (restore, '
                    'duplicate, delete; the app theme is untouched).',
              ),
              _ProfileSection(
                config: _config,
                nameController: _profileName,
                onApply: (profileConfig) =>
                    setState(() => _config = profileConfig),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-state energy overrides with a clear control.
class _EnergySliders extends StatelessWidget {
  final CypherOrbConfig config;
  final ValueChanged<CypherOrbConfig> onChanged;

  const _EnergySliders({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabSlider(
            label: 'Idle energy',
            value: config.idleEnergy ?? 0.14,
            min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(idleEnergy: v)),
          ),
          _LabSlider(
            label: 'Listening energy',
            value: config.listeningEnergy ?? 0.34,
            min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(listeningEnergy: v)),
          ),
          _LabSlider(
            label: 'Processing energy',
            value: config.processingEnergy ?? 0.70,
            min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(processingEnergy: v)),
          ),
          _LabSlider(
            label: 'Execution energy',
            value: config.executingEnergy ?? 0.95,
            min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(executingEnergy: v)),
          ),
          _LabSlider(
            label: 'Speaking energy',
            value: config.speakingEnergy ?? 0.45,
            min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(speakingEnergy: v)),
          ),
          const SizedBox(height: CypherSpacing.space2),
          Align(
            alignment: Alignment.centerRight,
            child: CypherButton(
              label: 'Clear energy overrides',
              variant: CypherButtonVariant.ghost,
              onPressed: () => onChanged(config.copyWith(
                clearIdleEnergy: true,
                clearListeningEnergy: true,
                clearProcessingEnergy: true,
                clearExecutingEnergy: true,
                clearSpeakingEnergy: true,
              )),
            ),
          ),
          Text(
            'Values shown before adjustment are the stock profile defaults.',
            style: c.typography.settingsItemSubtitle,
          ),
        ],
      ),
    );
  }
}

/// Material / motion multipliers over the real renderer.
class _MultiplierSliders extends StatelessWidget {
  final CypherOrbConfig config;
  final ValueChanged<CypherOrbConfig> onChanged;

  const _MultiplierSliders({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabSlider(
            label: 'Deformation', value: config.deformation, min: 0, max: 2,
            onChanged: (v) => onChanged(config.copyWith(deformation: v))),
          _LabSlider(
            label: 'Deformation speed', value: config.deformationSpeed,
            min: 0, max: 3,
            onChanged: (v) =>
                onChanged(config.copyWith(deformationSpeed: v))),
          _LabSlider(
            label: 'Fluid speed', value: config.fluidSpeed, min: 0, max: 3,
            onChanged: (v) => onChanged(config.copyWith(fluidSpeed: v))),
          _LabSlider(
            label: 'Jelly softness', value: config.jellySoftness, min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(jellySoftness: v))),
          _LabSlider(
            label: 'Elasticity', value: config.elasticity, min: 0.2, max: 2.5,
            onChanged: (v) => onChanged(config.copyWith(elasticity: v))),
          _LabSlider(
            label: 'Damping', value: config.damping, min: 0.2, max: 3,
            onChanged: (v) => onChanged(config.copyWith(damping: v))),
          _LabSlider(
            label: 'Audio influence', value: config.audioInfluence,
            min: 0, max: 2,
            onChanged: (v) => onChanged(config.copyWith(audioInfluence: v))),
          _LabSlider(
            label: 'Tap response', value: config.tapResponse, min: 0, max: 2,
            onChanged: (v) => onChanged(config.copyWith(tapResponse: v))),
          _LabSlider(
            label: 'Touch influence', value: config.touchInfluence,
            min: 0, max: 2,
            onChanged: (v) => onChanged(config.copyWith(touchInfluence: v))),
          _LabSlider(
            label: 'Wave strength', value: config.waveStrength, min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(waveStrength: v))),
          _LabSlider(
            label: 'Glow', value: config.glow, min: 0, max: 2,
            onChanged: (v) => onChanged(config.copyWith(glow: v))),
          _LabSlider(
            label: 'Highlight', value: config.highlight, min: 0, max: 2,
            onChanged: (v) => onChanged(config.copyWith(highlight: v))),
          _LabSlider(
            label: 'Internal color mix', value: config.internalColorMix,
            min: 0, max: 1,
            onChanged: (v) => onChanged(config.copyWith(internalColorMix: v))),
          _LabSlider(
            label: 'Motion scale', value: config.motionScale, min: 0, max: 2,
            onChanged: (v) => onChanged(config.copyWith(motionScale: v))),
        ],
      ),
    );
  }
}

/// Save / restore / duplicate / delete developer orb profiles.
class _ProfileSection extends StatelessWidget {
  final CypherOrbConfig config;
  final TextEditingController nameController;
  final ValueChanged<CypherOrbConfig> onApply;

  const _ProfileSection({
    required this.config,
    required this.nameController,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: AnimatedBuilder(
        animation: developerConfig,
        builder: (context, _) {
          final profiles = developerConfig.orbProfiles;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CypherInput(
                      controller: nameController,
                      hint: 'Profile name',
                      label: 'Save current configuration as',
                    ),
                  ),
                  const SizedBox(width: CypherSpacing.space3),
                  CypherButton(
                    label: 'Save',
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a profile name first')),
                        );
                        return;
                      }
                      final id = 'orb_${DateTime.now().millisecondsSinceEpoch}';
                      await developerConfig.saveOrbProfile(
                        CypherOrbProfile(
                          id: id,
                          name: name,
                          config: config,
                          updatedAt: DateTime.now(),
                        ),
                      );
                      nameController.clear();
                    },
                  ),
                ],
              ),
              if (profiles.isEmpty) ...[
                const SizedBox(height: CypherSpacing.space3),
                Text(
                  'No saved profiles yet. Saved profiles are developer-only '
                  'and never change the running app theme.',
                  style: c.typography.settingsItemSubtitle,
                ),
              ] else ...[
                const SizedBox(height: CypherSpacing.space3),
                for (final profile in profiles)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: CypherSpacing.space2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile.name,
                                  style: c.typography.settingsItemTitle),
                              Text(
                                'updated '
                                '${profile.updatedAt.toLocal()}'
                                .split('.')
                                .first,
                                style: c.typography.settingsItemSubtitle,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Restore profile',
                          onPressed: () => onApply(profile.config),
                          icon: const Icon(Icons.restore_rounded, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Duplicate profile',
                          onPressed: () async {
                            await developerConfig.saveOrbProfile(
                              CypherOrbProfile(
                                id: 'orb_'
                                    '${DateTime.now().millisecondsSinceEpoch}',
                                name: '${profile.name} copy',
                                config: profile.config,
                                updatedAt: DateTime.now(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete profile',
                          onPressed: () =>
                              developerConfig.deleteOrbProfile(profile.id),
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 20, color: c.colors.error),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Lab slider row with live value badge.
class _LabSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _LabSlider({
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
          width: 148,
          child: Text(label, style: c.typography.settingsItemSubtitle),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            style: c.typography.monoSmall.copyWith(
              color: c.colors.textSecondary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
