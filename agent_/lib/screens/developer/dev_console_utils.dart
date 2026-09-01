import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/ui/cypher_components.dart';
import '../../core/theme/spacing_tokens.dart';

/// Evidence-based health states for developer diagnostics.
///
/// A state may only be shown when the corresponding evidence was actually
/// collected; pages must never guess. See `.claude/skills/
/// cypher-developer-console/SKILL.md`.
enum DevHealth {
  ok,
  warning,
  error,
  unavailable,
  notTested,
}

/// Label + color + icon for a [DevHealth] value, driven by semantic tokens.
class DevHealthStyle {
  final DevHealth health;

  const DevHealthStyle(this.health);

  String get label => switch (health) {
        DevHealth.ok => 'OK',
        DevHealth.warning => 'WARNING',
        DevHealth.error => 'ERROR',
        DevHealth.unavailable => 'UNAVAILABLE',
        DevHealth.notTested => 'NOT TESTED',
      };

  Color color(CypherThemeData c) => switch (health) {
        DevHealth.ok => c.colors.success,
        DevHealth.warning => c.colors.warning,
        DevHealth.error => c.colors.error,
        DevHealth.unavailable => c.colors.textTertiary,
        DevHealth.notTested => c.colors.textTertiary,
      };

  IconData get icon => switch (health) {
        DevHealth.ok => Icons.check_circle_outline_rounded,
        DevHealth.warning => Icons.warning_amber_rounded,
        DevHealth.error => Icons.error_outline_rounded,
        DevHealth.unavailable => Icons.not_interested_rounded,
        DevHealth.notTested => Icons.help_outline_rounded,
      };
}

/// One labeled evidence row used across the developer console.
class DevStatusRow extends StatelessWidget {
  final String label;
  final String detail;
  final DevHealth? health;

  const DevStatusRow({
    super.key,
    required this.label,
    required this.detail,
    this.health,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final style = health == null ? null : DevHealthStyle(health!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CypherSpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: c.typography.labelLarge.copyWith(
                color: c.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail.isEmpty ? '—' : detail,
              style: c.typography.bodyMedium.copyWith(
                color: c.colors.textPrimary,
              ),
            ),
          ),
          if (style != null) ...[
            const SizedBox(width: CypherSpacing.space3),
            Semantics(
              label: '${style.label}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(style.icon, size: 14, color: style.color(c)),
                  const SizedBox(width: CypherSpacing.space1),
                  Text(
                    style.label,
                    style: c.typography.labelSmall.copyWith(
                      color: style.color(c),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standard section container for developer console pages.
class DevSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const DevSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CypherSectionHeader(title: title, subtitle: subtitle),
        CypherCard(
          color: Colors.transparent,
          padding: const EdgeInsets.all(CypherSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}
