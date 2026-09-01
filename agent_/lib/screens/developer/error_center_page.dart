import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/task_telemetry_service.dart';
import 'dev_console_utils.dart';

/// Execution errors reported by the real pipeline (Phase 4: Errors).
class ErrorCenterPage extends StatelessWidget {
  const ErrorCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Errors', style: c.typography.titleMedium),
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
                    title: 'Reported errors',
                    subtitle:
                        'Sanitized details from the execution pipeline.',
                    children: [
                      if (snapshot.errors.isEmpty)
                        Text(
                          'No errors reported. Errors appear here when a task '
                          'fails or reports a problem.',
                          style: c.typography.bodyMedium,
                        )
                      else
                        for (final error in snapshot.errors)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: CypherSpacing.space2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    size: 16, color: c.colors.error),
                                const SizedBox(
                                    width: CypherSpacing.space2),
                                Expanded(
                                  child: SelectableText(error,
                                      style: c.typography.bodySmall),
                                ),
                              ],
                            ),
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
