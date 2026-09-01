import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/task_telemetry_service.dart';
import 'dev_console_utils.dart';

/// Controlled-upgrade checkpoint view (Phase 7 support surface).
///
/// The self-upgrade workflow is intentionally NOT enabled in this build;
/// [ControlledUpgradeService] publishes explicit "unavailable" states. This
/// page shows exactly that published state — it never fabricates checkpoints.
class CheckpointsPage extends StatelessWidget {
  const CheckpointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Checkpoints', style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ValueListenableBuilder<TaskDeveloperSnapshot>(
            valueListenable: TaskTelemetryService.shared.developerState,
            builder: (context, snapshot, _) {
              return ListView(
                padding: const EdgeInsets.all(CypherSpacing.space6),
                children: [
                  DevSection(
                    title: 'Controlled upgrade state',
                    subtitle:
                        'Published by ControlledUpgradeService (honest '
                        'no-op in this build).',
                    children: [
                      DevStatusRow(
                        label: 'Stage',
                        detail: snapshot.upgradeStage.isEmpty
                            ? '— (workflow not started)'
                            : snapshot.upgradeStage,
                        health: DevHealth.unavailable,
                      ),
                      DevStatusRow(
                          label: 'Problem',
                          detail:
                              snapshot.upgradeProblem.isEmpty ? '—' : snapshot.upgradeProblem),
                      DevStatusRow(
                          label: 'Allowed files',
                          detail:
                              snapshot.upgradeFiles.isEmpty ? '—' : snapshot.upgradeFiles),
                      DevStatusRow(
                          label: 'Reason',
                          detail:
                              snapshot.upgradeReason.isEmpty ? '—' : snapshot.upgradeReason),
                      DevStatusRow(
                          label: 'Evidence',
                          detail: snapshot.upgradeEvidence.isEmpty
                              ? '—'
                              : snapshot.upgradeEvidence),
                      DevStatusRow(
                          label: 'Final result',
                          detail: snapshot.upgradeFinalResult.isEmpty
                              ? '—'
                              : snapshot.upgradeFinalResult),
                    ],
                  ),
                  DevSection(
                    title: 'Why this is unavailable',
                    children: [
                      Text(
                        'A real checkpoint/revert workflow requires the '
                        'authorized development environment to apply and '
                        'validate patches. The app cannot rebuild itself; '
                        'the Code Agent page documents the approval-based '
                        'workflow instead of pretending to apply changes.',
                        style: c.typography.bodyMedium,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
