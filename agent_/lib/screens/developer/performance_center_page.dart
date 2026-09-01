import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/developer_config_service.dart';
import '../../services/task_telemetry_service.dart';
import 'dev_console_utils.dart';

/// Latency evidence collected by the execution pipeline (Phase 4/19).
/// Expensive probes are gated behind the explicit opt-in toggle.
class PerformanceCenterPage extends StatefulWidget {
  const PerformanceCenterPage({super.key});

  @override
  State<PerformanceCenterPage> createState() => _PerformanceCenterPageState();
}

class _PerformanceCenterPageState extends State<PerformanceCenterPage> {
  @override
  void initState() {
    super.initState();
    developerConfig.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Performance', style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ValueListenableBuilder<TaskDeveloperSnapshot>(
            valueListenable: TaskTelemetryService.shared.developerState,
            builder: (context, snapshot, _) {
              return AnimatedBuilder(
                animation: developerConfig,
                builder: (context, _) {
                  return ListView(
                    padding: const EdgeInsets.all(CypherSpacing.space6),
                    children: [
                      DevSection(
                        title: 'Stage latencies',
                        subtitle:
                            'Measured during real task execution (ms).',
                        children: [
                          if (snapshot.actionTimings.isEmpty)
                            Text(
                              'No timings recorded yet. Run a task to '
                              'collect latency evidence.',
                              style: c.typography.bodyMedium,
                            )
                          else
                            for (final entry
                                in snapshot.actionTimings.entries)
                              DevStatusRow(
                                label: entry.key,
                                detail: '${entry.value} ms',
                              ),
                          DevStatusRow(
                            label: 'Total task duration',
                            detail:
                                '${snapshot.totalTaskDurationMs} ms',
                          ),
                        ],
                      ),
                      DevSection(
                        title: 'Efficiency',
                        subtitle:
                            'Guard counters that indicate wasted work.',
                        children: [
                          DevStatusRow(
                              label: 'Duplicate action blocks',
                              detail:
                                  '${snapshot.duplicateActionBlocks}'),
                          DevStatusRow(
                              label: 'Stale screen blocks',
                              detail: '${snapshot.staleScreenBlocks}'),
                          DevStatusRow(
                              label: 'Observations reused',
                              detail: '${snapshot.observationsReused}'),
                        ],
                      ),
                      DevSection(
                        title: 'Opt-in instrumentation',
                        subtitle:
                            'Expensive diagnostics stay off unless explicitly '
                            'enabled so the normal app is never slowed down.',
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                                'Enable expensive diagnostics probes'),
                            subtitle: const Text(
                                'Adds extra on-demand measurements in '
                                'developer pages only. Never active for '
                                'normal users.'),
                            value: developerConfig
                                .expensiveDiagnosticsEnabled,
                            onChanged: (enabled) => developerConfig
                                .setExpensiveDiagnosticsEnabled(enabled),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
