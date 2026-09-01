import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import 'dev_console_utils.dart';

/// Compile-time feature flags (Phase 4). Flags are constants, so this page
/// is read-only evidence rather than a fake toggle panel.
class FeatureFlagCenterPage extends StatelessWidget {
  const FeatureFlagCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final flags = <(String, bool, String)>[
      (
        'floatingOverlayEnabled',
        FeatureFlags.floatingOverlayEnabled,
        'Floating overlay launcher (stable, production enabled).',
      ),
      (
        'mediaPostWorkflowEnabled',
        FeatureFlags.mediaPostWorkflowEnabled,
        'External social-post workflow. Disabled until real-device '
        'evidence confirms the draft-to-final-confirm flow.',
      ),
      (
        'isDevelopmentBuild',
        FeatureFlags.isDevelopmentBuild,
        'True only for actual development builds. Never fabricated for '
        'production binaries.',
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Feature Flags', style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CypherSpacing.space6),
            children: [
              DevSection(
                title: 'Compile-time flags',
                subtitle:
                    'Static constants — changing them requires a rebuild, so '
                    'they are displayed read-only.',
                children: [
                  for (final (name, value, description) in flags) ...[
                    DevStatusRow(
                      label: name,
                      detail: description,
                      health: value ? DevHealth.ok : DevHealth.unavailable,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
