import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/permission_service.dart';
import 'dev_console_utils.dart';

/// Real Android permission states with remediation (Phase 4/17).
/// Values come from [PermissionService] — never fabricated.
class PermissionMatrixPage extends StatefulWidget {
  const PermissionMatrixPage({super.key});

  @override
  State<PermissionMatrixPage> createState() => _PermissionMatrixPageState();
}

class _PermissionMatrixPageState extends State<PermissionMatrixPage> {
  final PermissionService _permissionService = PermissionService();
  Map<String, PermissionStatusInfo>? _statuses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final statuses = await _permissionService.getAllPermissionsStatus();
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  DevHealth _health(PermissionStatus status) {
    if (status.isGranted) return DevHealth.ok;
    if (status.isPermanentlyDenied) return DevHealth.error;
    return DevHealth.unavailable;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Permission Matrix', style: c.typography.titleMedium),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _statuses = null);
              _load();
            },
          ),
        ],
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CypherSpacing.space6),
            children: [
              DevSection(
                title: 'Android permission states',
                subtitle: 'Live values from the permission handlers.',
                children: [
                  if (_error != null)
                    Text('Probe failed: $_error',
                        style: c.typography.bodyMedium
                            .copyWith(color: c.colors.error))
                  else if (_statuses == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else
                    for (final entry in _statuses!.entries)
                      DevStatusRow(
                        label: entry.value.name,
                        detail:
                            '${entry.value.statusText}${entry.value.required ? ' · required' : ''}',
                        health: _health(entry.value.status),
                      ),
                ],
              ),
              DevSection(
                title: 'Remediation',
                subtitle:
                    'Explanations mirror what the agent tells the user.',
                children: [
                  for (final type in [
                    'microphone',
                    'notification',
                    'overlay',
                    'accessibility',
                  ])
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: CypherSpacing.space2),
                      child: Text(
                        '$type: '
                        '${_permissionService.getPermissionExplanation(type)}',
                        style: c.typography.bodySmall,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
