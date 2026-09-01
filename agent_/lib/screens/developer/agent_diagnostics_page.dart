import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../models/capability_registry.dart';
import '../../services/diagnostics_service.dart';
import '../../services/task_telemetry_service.dart';
import 'dev_console_utils.dart';

/// Live, privacy-sanitized agent execution diagnostics (Phase 4/16).
/// All data comes from [TaskTelemetryService] — the same source the runtime
/// publishes to. No content, prompts, or screenshots are shown.
class AgentDiagnosticsPage extends StatelessWidget {
  const AgentDiagnosticsPage({super.key});

  Future<void> _copySnapshot(BuildContext context) async {
    final snapshot = TaskTelemetryService.shared.developerState.value;
    final report = DiagnosticsService.buildSanitizedDeveloperReport(
      snapshot: snapshot,
      system: {'source': 'agent_diagnostics_page'},
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Sanitized snapshot copied to clipboard')),
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
        title: Text('Agent Diagnostics', style: c.typography.titleMedium),
        actions: [
          IconButton(
            tooltip: 'Copy sanitized snapshot',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copySnapshot(context),
          ),
        ],
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
                    title: 'Execution',
                    subtitle: snapshot.isRunning
                        ? 'A task is currently running'
                        : 'No task running',
                    children: [
                      DevStatusRow(
                          label: 'Root goal', detail: snapshot.rootGoal),
                      DevStatusRow(
                          label: 'Stage',
                          detail: snapshot.executionStage),
                      DevStatusRow(
                          label: 'Sub goal',
                          detail: snapshot.currentSubGoal),
                      DevStatusRow(
                          label: 'Verification',
                          detail: snapshot.verificationResult,
                          health:
                              _verificationHealth(snapshot.verificationResult)),
                      DevStatusRow(
                        label: 'Confidence',
                        detail: snapshot.confidence == null
                            ? '—'
                            : '${(snapshot.confidence! * 100).toStringAsFixed(0)}%',
                      ),
                      DevStatusRow(
                          label: 'Duration',
                          detail:
                              '${snapshot.totalTaskDurationMs} ms'),
                    ],
                  ),
                  DevSection(
                    title: 'Counters',
                    children: [
                      DevStatusRow(
                          label: 'Actions',
                          detail: '${snapshot.actionCount}'),
                      DevStatusRow(
                          label: 'Screen observations',
                          detail: '${snapshot.screenObservations}'),
                      DevStatusRow(
                          label: 'Model calls',
                          detail: '${snapshot.aiCalls}'),
                      DevStatusRow(
                          label: 'Recovery attempts',
                          detail: '${snapshot.recoveryAttempts}'),
                      DevStatusRow(
                          label: 'Duplicate blocks',
                          detail: '${snapshot.duplicateActionBlocks}'),
                      DevStatusRow(
                          label: 'Stale screen blocks',
                          detail: '${snapshot.staleScreenBlocks}'),
                      DevStatusRow(
                          label: 'Observations reused',
                          detail: '${snapshot.observationsReused}'),
                      DevStatusRow(
                          label: 'Route',
                          detail: snapshot.routeSelection),
                    ],
                  ),
                  DevSection(
                    title: 'Capability registry',
                    subtitle:
                        'Typed action contracts the planner may use.',
                    children: [
                      for (final capability in CapabilityRegistry.all)
                        DevStatusRow(
                          label: capability.id,
                          detail:
                              'actions: ${capability.actions.join(', ')} · '
                              'safety: ${capability.safety.name} · '
                              'verification: ${capability.defaultVerification.name}',
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

  DevHealth _verificationHealth(String result) {
    final lower = result.toLowerCase();
    if (lower.contains('passed') || lower.contains('verified')) {
      return DevHealth.ok;
    }
    if (lower.contains('fail')) return DevHealth.error;
    if (lower.contains('unverified')) return DevHealth.warning;
    return DevHealth.notTested;
  }
}
