import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/developer_config_service.dart';

/// Reset developer configuration (Phase 4 quick action target).
/// Clears ONLY developer state; user data is never touched.
class ResetPage extends StatelessWidget {
  const ResetPage({super.key});

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset developer configuration?'),
        content: const Text(
          'Clears: developer mode flag, orb profiles, orb lab state, '
          'code-agent sessions, and expensive-diagnostics opt-in. '
          'Chats, providers, memory, and permissions are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await developerConfig.resetDeveloperConfiguration();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Developer configuration reset')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Reset Developer Configuration',
            style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CypherSpacing.space6),
            children: [
              CypherCard(
                color: Colors.transparent,
                padding: const EdgeInsets.all(CypherSpacing.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What gets cleared',
                        style: c.typography.settingsItemTitle),
                    const SizedBox(height: CypherSpacing.space3),
                    Text(
                      '• Developer mode enabled flag\n'
                      '• Saved orb profiles and orb lab state\n'
                      '• Code Agent session history\n'
                      '• Expensive diagnostics opt-in',
                      style: c.typography.bodyMedium,
                    ),
                  ],
                ),
              ),
              CypherCard(
                color: Colors.transparent,
                padding: const EdgeInsets.all(CypherSpacing.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What is never touched',
                        style: c.typography.settingsItemTitle),
                    const SizedBox(height: CypherSpacing.space3),
                    Text(
                      'Chats and history · provider credentials (secure '
                      'storage) · user memory · skills · Android permissions '
                      '· the running theme.',
                      style: c.typography.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CypherSpacing.space5),
              CypherButton(
                label: 'Reset developer configuration',
                variant: CypherButtonVariant.danger,
                icon: Icons.restart_alt_rounded,
                onPressed: () => _reset(context),
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
