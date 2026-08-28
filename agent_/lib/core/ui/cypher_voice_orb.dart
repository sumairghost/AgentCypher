import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/cypher_theme.dart';

/// A premium, procedurally rendered voice-assistant orb.
///
/// Rendered entirely with Flutter's [CustomPainter] — no Lottie, Rive, GIFs,
/// videos, or external animation assets. The silhouette organically deforms
/// (a multi-frequency jelly blob), internal light flows through several
/// shades of the active Cypher accent family, and touch / audio amplitude
/// deform the material in real time.
///
/// Everything visual is driven by semantic theme tokens (`context.cypher`),
/// so the orb automatically follows the selected preset and any future custom
/// accent without duplicating per-theme implementations.
///
/// See `.claude/skills/cypher-voice-orb/SKILL.md` for the rendering
/// architecture, motion model, and state mapping.
class CypherVoiceOrb extends StatefulWidget {
  final CypherVoiceOrbState state;
  final double audioLevel;
  final bool enabled;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const CypherVoiceOrb({
    super.key,
    this.state = CypherVoiceOrbState.idle,
    this.audioLevel = 0.0,
    this.enabled = true,
    this.size = 120,
    this.onTap,
    this.semanticLabel,
  });

  @override
  State<CypherVoiceOrb> createState() => _CypherVoiceOrbState();
}

/// Real application-driven voice states. Each maps to its own rendering
/// profile; the orb never lies about the underlying voice lifecycle.
enum CypherVoiceOrbState {
  idle,
  opening,
  listening,
  processing,
  executing,
  speaking,
  closing,
  cancelled,
  error,
  unavailable,
}

/// Per-state visual profile: how much the material breathes, flows, and
/// deforms. Energy is normalised 0..1 and scales every motion layer.
class _StateProfile {
  final double energy; // 0..1 overall liveliness
  final double deformAmp; // jelly amplitude (fraction of radius)
  final double deformSpeed; // jelly frequency
  final double flowSpeed; // internal color flow frequency
  final double audioGain; // how strongly audioLevel contributes
  final bool useErrorTint;
  final bool useDimTint;

  const _StateProfile({
    required this.energy,
    required this.deformAmp,
    required this.deformSpeed,
    required this.flowSpeed,
    this.audioGain = 0.0,
    this.useErrorTint = false,
    this.useDimTint = false,
  });

  static _StateProfile of(CypherVoiceOrbState s) {
    switch (s) {
      case CypherVoiceOrbState.opening:
        return const _StateProfile(
          energy: 0.5, deformAmp: 0.09, deformSpeed: 2.4, flowSpeed: 1.6);
      case CypherVoiceOrbState.listening:
        return const _StateProfile(
          energy: 0.34, deformAmp: 0.05, deformSpeed: 1.6,
          flowSpeed: 1.1, audioGain: 0.6);
      case CypherVoiceOrbState.processing:
        return const _StateProfile(
          energy: 0.7, deformAmp: 0.085, deformSpeed: 2.0, flowSpeed: 2.2);
      case CypherVoiceOrbState.executing:
        return const _StateProfile(
          energy: 0.95, deformAmp: 0.12, deformSpeed: 3.0, flowSpeed: 3.2);
      case CypherVoiceOrbState.speaking:
        return const _StateProfile(
          energy: 0.45, deformAmp: 0.065, deformSpeed: 1.9,
          flowSpeed: 1.4, audioGain: 0.55);
      case CypherVoiceOrbState.closing:
        return const _StateProfile(
          energy: 0.4, deformAmp: 0.08, deformSpeed: 2.6, flowSpeed: 1.8);
      case CypherVoiceOrbState.cancelled:
        return const _StateProfile(
          energy: 0.3, deformAmp: 0.1, deformSpeed: 2.8, flowSpeed: 2.0);
      case CypherVoiceOrbState.error:
        return const _StateProfile(
          energy: 0.5, deformAmp: 0.11, deformSpeed: 3.4,
          flowSpeed: 2.6, useErrorTint: true);
      case CypherVoiceOrbState.unavailable:
        return const _StateProfile(
          energy: 0.1, deformAmp: 0.02, deformSpeed: 0.5,
          flowSpeed: 0.4, useDimTint: true);
      case CypherVoiceOrbState.idle:
      default:
        return const _StateProfile(
          energy: 0.14, deformAmp: 0.035, deformSpeed: 0.9, flowSpeed: 0.7);
    }
  }
}

/// Touch-interaction physics: displacement, velocity, damping, elasticity,
/// influence radius and recovery speed. Feels like pushing viscous jelly.
class _OrbInteraction {
  double x = 0, y = 0; // displacement (fraction of size)
  double vx = 0, vy = 0; // velocity
  double pressure = 0; // 0..1 press depth
  double squash = 0; // vertical compression from swipe
  bool active = false;
  bool _hasTouch = false;
  double _touchAngle = 0;

  static const double _stiffness = 90;
  static const double _damping = 9;
  static const double _maxDisp = 0.20;

  void begin(Offset center, Offset local) {
    _hasTouch = true;
    active = true;
    pressure = 0.35;
    _touchAngle = math.atan2(local.dy - center.dy, local.dx - center.dx);
  }

  void update(Offset center, Offset local) {
    if (!_hasTouch) return;
    final _ = center;
    final nx = (local.dx - center.dx) / (center.dx == 0 ? 1 : center.dx);
    final ny = (local.dy - center.dy) / (center.dy == 0 ? 1 : center.dy);
    final dist =
        math.sqrt(nx * nx + ny * ny).clamp(0.0, 1.2).toDouble();
    final pull = (1 - dist) * 0.6;
    final tx = (nx.isNaN || nx.isInfinite ? 0 : nx)
        .clamp(-1, 1)
        .toDouble() *
        _maxDisp *
        pull;
    final ty = (ny.isNaN || ny.isInfinite ? 0 : ny)
        .clamp(-1, 1)
        .toDouble() *
        _maxDisp *
        pull;
    vx += (_stiffness * (tx - x) - _damping * vx) * 0.016;
    vy += (_stiffness * (ty - y) - _damping * vy) * 0.016;
    x += vx * 0.016;
    y += vy * 0.016;
    _touchAngle = math.atan2(local.dy - center.dy, local.dx - center.dx);
  }

  void press() {
    pressure = (pressure + 0.25).clamp(0.0, 1.0).toDouble();
  }

  void swipe(Offset delta) {
    vx += delta.dx / 320;
    vy += delta.dy / 320;
    squash = (squash + delta.dy / 240).clamp(-1.0, 1.0).toDouble();
  }

  void release() {
    _hasTouch = false;
    pressure = 0;
    active = false;
  }

  /// Called every frame even without a touch: lets the mat settle back.
  void relax() {
    if (_hasTouch) return;
    vx += (_stiffness * (0 - x) - _damping * vx) * 0.016;
    vy += (_stiffness * (0 - y) - _damping * vy) * 0.016;
    x += vx * 0.016;
    y += vy * 0.016;
    squash += (0 - squash) * 0.06;
    pressure += (0 - pressure) * 0.08;
  }

  double get angleToTouch => _touchAngle;
  bool get hasTouch => _hasTouch;

  void reset() {
    x = 0; y = 0; vx = 0; vy = 0;
    pressure = 0; squash = 0; active = false; _hasTouch = false;
  }
}

class _CypherVoiceOrbState extends State<CypherVoiceOrb>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _t = 0; // running time in seconds (continuous, non-looping phases)
  double _scale = 1.0;
  double _tapPulse = 0;
  final _OrbInteraction _interaction = _OrbInteraction();
  late bool _reduced;

  /// A small per-instance seed so each orb deforms idiosyncratically instead
  /// of every orb playing the identical loop.
  final double _phaseA = math.Random().nextDouble() * math.pi * 2;
  final double _phaseB = math.Random().nextDouble() * math.pi * 2;
  final double _phaseC = math.Random().nextDouble() * math.pi * 2;
  final double _phaseD = math.Random().nextDouble() * math.pi * 2;

  @override
  void initState() {
    super.initState();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1) return; // guard against pauses/jumps
    _t += dt;
    _interaction.relax();
    _tapPulse = (_tapPulse - dt * 3).clamp(0.0, 1.0).toDouble();
    final target = _targetScale();
    _scale += (target - _scale) * math.min(1.0, dt * 4.0);
    if (mounted) setState(() {});
  }

  double _targetScale() {
    switch (widget.state) {
      case CypherVoiceOrbState.opening:
        return 1.0;
      case CypherVoiceOrbState.closing:
      case CypherVoiceOrbState.cancelled:
        return 0.35;
      default:
        return 1.0;
    }
  }

  Offset _center() => Offset(widget.size / 2, widget.size / 2);

  void _handleTap() {
    _tapPulse = 1.0;
    widget.onTap?.call();
  }

  String _defaultLabel() {
    return switch (widget.state) {
      CypherVoiceOrbState.idle => 'Cypher assistant, idle',
      CypherVoiceOrbState.opening => 'Opening Cypher assistant',
      CypherVoiceOrbState.listening => 'Cypher is listening',
      CypherVoiceOrbState.processing => 'Cypher is processing',
      CypherVoiceOrbState.executing => 'Cypher is executing a task',
      CypherVoiceOrbState.speaking => 'Cypher is speaking',
      CypherVoiceOrbState.closing => 'Closing Cypher assistant',
      CypherVoiceOrbState.cancelled => 'Cypher action cancelled',
      CypherVoiceOrbState.error => 'Cypher encountered an error',
      CypherVoiceOrbState.unavailable => 'Voice unavailable',
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final profile = _StateProfile.of(
      widget.enabled ? widget.state : CypherVoiceOrbState.unavailable,
    );
    final palette = _resolvePalette(context, profile);

    return Semantics(
      label: widget.semanticLabel ?? _defaultLabel(),
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: (d) => _interaction.begin(_center(), d.localPosition),
        onTapCancel: () => _interaction.release(),
        onLongPressStart: (_) => _interaction.press(),
        onPanStart: (d) => _interaction.begin(_center(), d.localPosition),
        onPanUpdate: (d) {
          _interaction.update(_center(), d.localPosition);
          _interaction.swipe(d.delta);
        },
        onPanEnd: (_) => _interaction.release(),
        onPanCancel: () => _interaction.release(),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _OrbPainter(
              t: _t,
              profile: profile,
              palette: palette,
              audio: widget.enabled ? widget.audioLevel : 0.0,
              scale: _scale,
              tapPulse: _tapPulse,
              interaction: _interaction,
              reduced: _reduced,
              phaseA: _phaseA,
              phaseB: _phaseB,
              phaseC: _phaseC,
              phaseD: _phaseD,
            ),
          ),
        ),
      ),
    );
  }

  /// Resolves the orb palette exclusively from semantic theme tokens so the
  /// orb follows the active preset and custom accents automatically.
  _OrbPalette _resolvePalette(BuildContext context, _StateProfile profile) {
    final c = context.cypher.colors;
    if (profile.useErrorTint) {
      return _OrbPalette(
        deep: Color.lerp(c.error, c.background, 0.35)!,
        base: c.error,
        light: Color.lerp(c.error, Colors.white, 0.35)!,
        glow: c.error,
        tint: c.errorContainer,
      );
    }
    if (profile.useDimTint) {
      return _OrbPalette(
        deep: c.textTertiary.withOpacity(0.25),
        base: c.textTertiary.withOpacity(0.55),
        light: Color.lerp(c.textTertiary, Colors.white, 0.4)!,
        glow: c.textTertiary,
        tint: c.surfaceContainerHigh,
      );
    }
    return _OrbPalette(
      deep: Color.lerp(c.accentDark, c.background, 0.4)!,
      base: c.accent,
      light: Color.lerp(c.accentLight, Colors.white, 0.15)!,
      glow: c.accent,
      tint: c.accentContainer,
    );
  }
}

/// Multi-shade ramp (all one theme family — no rainbow, no unrelated colors).
class _OrbPalette {
  final Color deep;
  final Color base;
  final Color light;
  final Color glow;
  final Color tint;

  const _OrbPalette({
    required this.deep,
    required this.base,
    required this.light,
    required this.glow,
    required this.tint,
  });
}

/// Pure `CustomPainter` renderer. Everything is computed procedurally and
/// GPU-friendly: no BitmapShader, no BackdropFilter, no allocations beyond a
/// handful of paths/gradients per frame.
class _OrbPainter extends CustomPainter {
  final double t; // continuous seconds
  final _StateProfile profile;
  final _OrbPalette palette;
  final double audio; // 0..1 voice amplitude
  final double scale;
  final double tapPulse; // 0..1 decaying tap wave
  final _OrbInteraction interaction;
  final bool reduced;
  final double phaseA, phaseB, phaseC, phaseD;

  _OrbPainter({
    required this.t,
    required this.profile,
    required this.palette,
    required this.audio,
    required this.scale,
    required this.tapPulse,
    required this.interaction,
    required this.reduced,
    required this.phaseA,
    required this.phaseB,
    required this.phaseC,
    required this.phaseD,
  });

  static const int _segments = 60;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R = size.width / 2 * 0.72 * scale;
    if (R < 1) return;

    final motionFactor = reduced ? 0.15 : 1.0;
    final energy = (profile.energy + profile.audioGain * audio)
        .clamp(0.02, 1.0)
        .toDouble();
    final amp = profile.deformAmp * motionFactor * math.min(1.0, energy * 1.4);

    // ── Ambient glow (cheap radial fill, no blur filter) ────────────────
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.glow.withOpacity(0.10 + 0.10 * energy),
          palette.glow.withOpacity(0.03 * energy),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
        center: Alignment(
          interaction.x * 0.3,
          interaction.y * 0.3,
        ),
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: R * 2.6),
      );
    canvas.drawCircle(Offset(cx, cy), R * 2.6, glowPaint);

    // ── Organic silhouette ───────────────────────────────────────────────
    final points = <Offset>[];
    final touchPull = interaction.hasTouch ? interaction.pressure * 0.10 : 0.0;
    final swipeX = interaction.squash * 0.10;
    final swipeY = -interaction.squash * 0.10;
    for (var i = 0; i < _segments; i++) {
      final theta = i / _segments * math.pi * 2;
      final d1 =
          0.75 * math.sin(theta + t * profile.deformSpeed * 2.3 + phaseA);
      final d2 = 0.5 * math.sin(2 * theta - t * profile.flowSpeed * 1.7 + phaseB);
      final d3 =
          0.35 * math.sin(3 * theta + t * profile.deformSpeed * 4.1 + phaseC);
      final d4 = 0.22 * math.sin(4 * theta - t * profile.flowSpeed * 3.1 + phaseD);

      // Audio reacts like jelly: amplitude pushes low-order harmonics.
      final audioTerm = audio *
          0.9 *
          (math.sin(3 * theta + t * 7.0) * 0.6 +
              math.sin(theta * 2 + t * 5.0) * 0.4);

      // A tap sends a fast traveling wave around the rim, then settles.
      final pulseTerm = tapPulse * 0.16 * math.sin(2 * theta + t * 18.0);

      // Finger indentation near the touch angle.
      final indent =
          touchPull * math.max(0, math.cos(theta - interaction.angleToTouch));

      final radius = R *
          (1 +
              amp * (d1 + d2 + d3 + d4) +
              audioTerm * amp +
              pulseTerm -
              indent);

      final px =
          cx + interaction.x * size.width + swipeX * R * math.cos(theta);
      final py =
          cy + interaction.y * size.height + swipeY * R * math.sin(theta);

      points.add(Offset(
        px + math.cos(theta) * radius,
        py + math.sin(theta) * radius,
      ));
    }

    final blob = Path()
      ..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final n = points[(i + 1) % points.length];
      final mid = Offset((p.dx + n.dx) / 2, (p.dy + n.dy) / 2);
      blob.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    blob.close();

    _paintInterior(canvas, blob, cx, cy, R, energy);
    _paintRim(canvas, blob, size, R, energy);
  }

  void _paintInterior(
      Canvas canvas, Path blob, double cx, double cy, double R, double energy) {
    canvas.save();
    canvas.clipPath(blob);

    final flowX = (cx + interaction.x * blob.getBounds().width / 2) +
        math.sin(t * profile.flowSpeed * 0.8 + phaseB) * R * 0.35;
    final flowY = (cy + interaction.y * blob.getBounds().height / 2) +
        math.cos(t * profile.flowSpeed * 0.6 + phaseC) * R * 0.35;

    final body = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          ((flowX - cx) / (R * 2)).clamp(-1.0, 1.0),
          ((flowY - cy) / (R * 2)).clamp(-1.0, 1.0),
        ),
        radius: 1.1,
        colors: [palette.light, palette.base, palette.tint, palette.deep],
        stops: const [0.0, 0.42, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: R * 1.6));
    canvas.drawCircle(Offset(flowX, flowY), R * 1.6, body);

    // Overlapping soft light regions orbiting inside the jelly (color flow).
    final highlight1 = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.light.withOpacity(0.55 * energy + 0.1),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & Size(R * 1.4, R * 1.4));
    final h1x = cx + math.cos(t * profile.flowSpeed + phaseA) * R * 0.42;
    final h1y = cy + math.sin(t * profile.flowSpeed * 1.3 + phaseB) * R * 0.36;
    canvas.drawCircle(Offset(h1x, h1y), R * 0.7, highlight1);

    final highlight2 = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.tint.withOpacity(0.5),
          palette.base.withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & Size(R * 1.6, R * 1.6));
    final h2x = cx - math.cos(t * profile.flowSpeed * 0.7 + phaseC) * R * 0.34;
    final h2y = cy - math.sin(t * profile.flowSpeed + phaseD) * R * 0.30;
    canvas.drawCircle(Offset(h2x, h2y), R * 0.8, highlight2);

    // Brighten the touched region slightly (press interaction).
    if (interaction.hasTouch && interaction.pressure > 0) {
      final touchGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            palette.light.withOpacity(0.5 * interaction.pressure),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & Size(R * 1.0, R * 1.0));
      final tx = cx +
          math.cos(interaction.angleToTouch) * R * 0.45 +
          interaction.x * blob.getBounds().width;
      final ty = cy +
          math.sin(interaction.angleToTouch) * R * 0.45 +
          interaction.y * blob.getBounds().height;
      canvas.drawCircle(Offset(tx, ty), R * 0.5, touchGlow);
    }

    canvas.restore();
  }

  void _paintRim(Canvas canvas, Path blob, Size size, double R, double energy) {
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, R * 0.045)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        math.max(0.5, R * 0.03),
      )
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.light.withOpacity(0.6 * energy + 0.25),
          palette.base.withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(blob, rim);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}
