import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/task_telemetry_service.dart';
import 'dev_console_utils.dart';

/// Live execution event log (Phase 4: Logs).
/// Events are published by the real execution pipeline; nothing is synthetic.
class LoggingCenterPage extends StatelessWidget {
  const LoggingCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Logs', style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ValueListenableBuilder<TaskDeveloperSnapshot>(
            valueListenable: TaskTelemetryService.shared.developerState,
            builder: (context, snapshot, _) {
              final events = snapshot.events.reversed.toList();
              return ListView(
                padding: const EdgeInsets.all(CypherSpacing.space6),
                children: [
                  DevSection(
                    title: 'Execution events',
                    subtitle:
                        '${events.length} recorded (bounded in-memory history)',
                    children: [
                      if (events.isEmpty)
                        Text(
                          'No execution events recorded yet. Events appear '
                          'when the agent runs a task.',
                          style: c.typography.bodyMedium,
                        )
                      else
                        for (final event in events)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: CypherSpacing.space1),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 84,
                                  child: Text(
                                    '${event.timestamp.hour.toString().padLeft(2, '0')}:'
                                    '${event.timestamp.minute.toString().padLeft(2, '0')}:'
                                    '${event.timestamp.second.toString().padLeft(2, '0')}',
                                    style: c.typography.monoSmall.copyWith(
                                        color: c.colors.textTertiary),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Text(event.stage,
                                      style: c.typography.labelMedium),
                                ),
                                Expanded(
                                  child: Text(event.detail,
                                      style: c.typography.bodySmall),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                  DevSection(
                    title: 'Workspace commands',
                    subtitle:
                        'Bounded record of developer workspace commands.',
                    children: [
                      if (snapshot.workspaceCommands.isEmpty)
                        Text('No workspace commands recorded.',
                            style: c.typography.bodyMedium)
                      else
                        for (final command in snapshot.workspaceCommands)
                          DevStatusRow(
                            label: command.command,
                            detail: command.succeeded
                                ? 'succeeded'
                                : 'failed',
                            health: command.succeeded
                                ? DevHealth.ok
                                : DevHealth.error,
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
