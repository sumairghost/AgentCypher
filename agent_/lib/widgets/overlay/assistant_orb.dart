import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../models/assistant_overlay_phase.dart';

/// Original Agent Cypher animated orb — code-drawn, asset-free.
/// Uses layered radial gradients and smooth AnimationControllers.
/// Respects reduced-motion; pauses when not visible.
class AssistantOrb extends StatefulWidget {
  final AssistantOverlayPhase phase;
  final double size;
  const AssistantOrb({super.key, required this.phase, this.size = 56});

  @override
  State<AssistantOrb> createState() => _AssistantOrbState();
}

class _AssistantOrbState extends State<AssistantOrb>
    with TickerProviderStateMixin {
  late AnimationController _breath;
  late AnimationController _spin;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AssistantOrb old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase && widget.phase == AssistantOverlayPhase.listening) {
      _breath.duration = const Duration(milliseconds: 900);
    } else if (widget.phase == AssistantOverlayPhase.idle) {
      _breath.duration = const Duration(milliseconds: 2200);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return _StaticOrb(phase: widget.phase, size: widget.size);
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _spin]),
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _OrbPainter(
          phase: widget.phase,
          breath: _breath.value,
          spin: _spin.value,
          base: _energyColor(context, widget.phase),
        ),
      ),
    );
  }

  /// Maps the assistant phase to a semantic token color so the orb follows
  /// the active theme preset instead of hardcoded hues.
  Color _energyColor(BuildContext context, AssistantOverlayPhase phase) {
    final c = CypherTheme.of(context);
    return switch (phase) {
      AssistantOverlayPhase.listening => c.colors.info,
      AssistantOverlayPhase.thinking => c.colors.accent,
      AssistantOverlayPhase.executing => c.colors.accentLight,
      AssistantOverlayPhase.success => c.colors.success,
      AssistantOverlayPhase.error => c.colors.error,
      _ => c.colors.accent,
    };
  }
}

class _StaticOrb extends StatelessWidget {
  final AssistantOverlayPhase phase;
  final double size;
  const _StaticOrb({required this.phase, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _OrbPainter(
        phase: phase,
        breath: 0.5,
        spin: 0,
        base: _staticColor(context),
      ),
    );
  }

  Color _staticColor(BuildContext context) {
    final c = CypherTheme.of(context);
    return switch (phase) {
      AssistantOverlayPhase.listening => c.colors.info,
      AssistantOverlayPhase.thinking => c.colors.accent,
      AssistantOverlayPhase.executing => c.colors.accentLight,
      AssistantOverlayPhase.success => c.colors.success,
      AssistantOverlayPhase.error => c.colors.error,
      _ => c.colors.accent,
    };
  }
}

class _OrbPainter extends CustomPainter {
  final AssistantOverlayPhase phase;
  final double breath;
  final double spin;
  final Color base;
  _OrbPainter({
    required this.phase,
    required this.breath,
    required this.spin,
    required this.base,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 * 0.85;

    // Background glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [base.withOpacity(0.35), base.withOpacity(0.05), Colors.transparent],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.6));
    canvas.drawCircle(Offset(cx, cy), r * 1.6, glow);

    // Outer ring with slow spin for dynamic states
    final ring = Paint()
      ..shader = SweepGradient(
        colors: [base.withOpacity(0.4), base.withOpacity(0.1), base.withOpacity(0.4)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final ringR = r * (0.92 + breath * 0.06);
    final ringPath = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: ringR));
    canvas.save();
    canvas.translate(cx, cy);
    if (phase == AssistantOverlayPhase.thinking || phase == AssistantOverlayPhase.executing) {
      canvas.rotate(spin * 2 * 3.14159);
    }
    canvas.translate(-cx, -cy);
    canvas.drawPath(ringPath, ring);
    canvas.restore();

    // Inner radial gradient body
    final body = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.9), base.withOpacity(0.7), base.withOpacity(0.35)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * (0.85 + breath * 0.08), body);

    // Soft inner highlight
    final highlight = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(cx - r * 0.25, cy - r * 0.25),
      r * 0.35,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.phase != phase || old.breath != breath || old.spin != spin;
}
