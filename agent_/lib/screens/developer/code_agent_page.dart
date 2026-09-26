import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/developer_config_service.dart';
import '../../services/workspace_agent_service.dart';

/// Developer Mode — the real code-editing workflow.
///
/// The user sees ONE request box and ONE confirmation. Everything else —
/// repository discovery, file selection, planning, editing, and validation —
/// is the workspace bridge's job (see [WorkspaceAgentService]). The app never
/// asks for paths and never fakes an edit: when the bridge is not connected
/// this page shows a clean unavailable state instead.
class CodeAgentPage extends StatefulWidget {
  const CodeAgentPage({super.key});

  @override
  State<CodeAgentPage> createState() => _CodeAgentPageState();
}

enum _DevPhase { checking, unavailable, idle, analyzing, editing, done, failed }

class _CodeAgentPageState extends State<CodeAgentPage> {
  final WorkspaceAgentService _agent = WorkspaceAgentService();
  final TextEditingController _request = TextEditingController();

  _DevPhase _phase = _DevPhase.checking;
  String? _unavailableReason;
  String? _error;
  WorkspaceRunReport? _report;
  String? _lastRequest;

  @override
  void initState() {
    super.initState();
    developerConfig.ensureInitialized();
    _checkWorkspace();
  }

  @override
  void dispose() {
    _request.dispose();
    super.dispose();
  }

  Future<void> _checkWorkspace() async {
    setState(() {
      _phase = _DevPhase.checking;
      _error = null;
      _report = null;
    });
    final reason = await _agent.probeUnavailableReason();
    if (!mounted) return;
    setState(() {
      _unavailableReason = reason;
      _phase = reason == null ? _DevPhase.idle : _DevPhase.unavailable;
    });
  }

  Future<void> _execute() async {
    final request = _request.text.trim();
    if (request.isEmpty) return;

    setState(() {
      _phase = _DevPhase.analyzing;
      _error = null;
      _report = null;
      _lastRequest = request;
    });

    final WorkspacePlan plan;
    try {
      plan = await _agent.plan(request);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _DevPhase.failed;
        _error = error.toString();
      });
      return;
    }
    if (!mounted) return;

    // THE single confirmation for the whole change.
    final approved = await _confirmPlan(plan);
    if (!mounted) return;
    if (!approved) {
      unawaited(_agent.cancel(plan.id));
      setState(() => _phase = _DevPhase.idle);
      return;
    }

    setState(() => _phase = _DevPhase.editing);
    try {
      final report = await _agent.apply(plan.id);
      if (!mounted) return;
      setState(() {
        _report = report;
        _phase = report.ok ? _DevPhase.done : _DevPhase.failed;
        if (!report.ok) _error = report.error;
      });
      unawaited(developerConfig.saveCodeAgentSession(<String, dynamic>{
        'id': plan.id,
        'request': request,
        'summary': plan.summary,
        'files': plan.files.map((f) => f.path).join('\n'),
        'result': report.ok ? 'success' : 'failed',
        'report': report.report,
        'validation': <String, String>{
          'analyzer': report.validation.analyzer,
          'tests': report.validation.tests,
          'format': report.validation.format,
        },
        'updatedAt': DateTime.now().toIso8601String(),
      }));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _DevPhase.failed;
        _error = error.toString();
      });
    }
  }

  Future<bool> _confirmPlan(WorkspacePlan plan) async {
    final c = context.cypher;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply this change?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.summary.isEmpty
                  ? 'The workspace agent will inspect and edit the project.'
                  : plan.summary,
              style: c.typography.bodyMedium,
            ),
            if (plan.files.isNotEmpty) ...[
              const SizedBox(height: CypherSpacing.space3),
              Text(
                'Files:',
                style: c.typography.labelMedium.copyWith(
                  color: c.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: CypherSpacing.space1),
              for (final file in plan.files.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: CypherSpacing.space1),
                  child: Text(
                    '• ${file.path}',
                    style: c.typography.bodySmall.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: c.colors.textSecondary,
                    ),
                  ),
                ),
              if (plan.files.length > 8)
                Text(
                  '+ ${plan.files.length - 8} more',
                  style: c.typography.bodySmall
                      .copyWith(color: c.colors.textTertiary),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final phase = _phase;
    final busy = phase == _DevPhase.analyzing || phase == _DevPhase.editing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: c.colors.textPrimary,
        elevation: 0,
        title: Text('Code Agent', style: c.typography.titleMedium),
        actions: [
          IconButton(
            tooltip: 'Recheck workspace bridge',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: busy ? null : _checkWorkspace,
          ),
        ],
      ),
      body: CypherBackground(
        child: phase == _DevPhase.checking
            ? const Center(child: CircularProgressIndicator())
            : phase == _DevPhase.unavailable
                ? _UnavailableView(
                    reason: _unavailableReason ?? '',
                    onRetry: _checkWorkspace,
                  )
                : _IdleView(
                    controller: _request,
                    phase: phase,
                    lastRequest: _lastRequest,
                    error: _error,
                    report: _report,
                    onExecute: _execute,
                  ),
      ),
    );
  }
}

/// Honest empty state when the workspace bridge cannot be reached. The page
/// refuses to pretend; it tells the user exactly what to run instead.
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.reason, required this.onRetry});

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CypherSpacing.space6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CypherGlass(
                padding: const EdgeInsets.all(CypherSpacing.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.extension_off_outlined,
                      size: 36,
                      color: c.colors.textTertiary,
                    ),
                    const SizedBox(height: CypherSpacing.space4),
                    Text(
                      'Workspace bridge unavailable',
                      textAlign: TextAlign.center,
                      style: c.typography.titleMedium,
                    ),
                    const SizedBox(height: CypherSpacing.space2),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: c.typography.bodyMedium,
                    ),
                    const SizedBox(height: CypherSpacing.space3),
                    Text(
                      'Developer Mode edits real files on your machine. A small '
                      'bridge must run next to your source checkout; the app '
                      'talks to it over adb. Nothing is faked.',
                      textAlign: TextAlign.center,
                      style: c.typography.bodySmall,
                    ),
                    const SizedBox(height: CypherSpacing.space4),
                    Text(
                      'adb reverse tcp:8791 tcp:8791',
                      textAlign: TextAlign.center,
                      style: c.typography.monoSmall.copyWith(
                        color: c.colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CypherSpacing.space4),
              TextButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded,
                    size: 18, color: c.colors.textSecondary),
                label: Text(
                  'Retry connection',
                  style: c.typography.labelLarge
                      .copyWith(color: c.colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single working surface of Developer Mode: one request box, one
/// action, and one inline run report. Nothing else competes for attention.
class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.controller,
    required this.phase,
    required this.lastRequest,
    required this.error,
    required this.report,
    required this.onExecute,
  });

  final TextEditingController controller;
  final _DevPhase phase;
  final String? lastRequest;
  final String? error;
  final WorkspaceRunReport? report;
  final VoidCallback onExecute;

  bool get _busy => phase == _DevPhase.analyzing || phase == _DevPhase.editing;

  String get _statusText {
    switch (phase) {
      case _DevPhase.analyzing:
        return 'Planning… (inspecting workspace, choosing files)';
      case _DevPhase.editing:
        return 'Applying and validating… this can take a while';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CypherSpacing.space5,
                CypherSpacing.space4,
                CypherSpacing.space5,
                CypherSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'What should change?',
                    style: c.typography.headlineSmall,
                  ),
                  const SizedBox(height: CypherSpacing.space2),
                  Text(
                    'Describe it in one line. The bridge plans the edit and '
                    'waits for your confirmation before touching any file.',
                    style: c.typography.bodyMedium,
                  ),
                  const SizedBox(height: CypherSpacing.space5),
                  TextField(
                    controller: controller,
                    enabled: !_busy,
                    maxLines: 4,
                    minLines: 2,
                    textInputAction: TextInputAction.done,
                    style: c.typography.inputText,
                    decoration: InputDecoration(
                      hintText: 'e.g. Rename SettingsViewModel to '
                          'SettingsPageModel and update its tests',
                      hintStyle: c.typography.bodyMedium.copyWith(
                        color: c.colors.textTertiary,
                      ),
                      filled: true,
                      fillColor: c.colors.surface.withValues(alpha: 0.6),
                      contentPadding:
                          const EdgeInsets.all(CypherSpacing.space4),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(CypherSpacing.radiusLg),
                        borderSide: BorderSide(color: c.colors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(CypherSpacing.radiusLg),
                        borderSide: BorderSide(color: c.colors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(CypherSpacing.radiusLg),
                        borderSide: BorderSide(color: c.colors.accent),
                      ),
                    ),
                    onSubmitted: (_) => onExecute(),
                  ),
                  if (error != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: CypherSpacing.space4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: c.colors.error,
                          ),
                          const SizedBox(width: CypherSpacing.space2),
                          Expanded(
                            child: Text(
                              error!,
                              style: c.typography.bodyMedium.copyWith(
                                color: c.colors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (report != null) ...[
                    const SizedBox(height: CypherSpacing.space5),
                    _ReportCard(report: report!, lastRequest: lastRequest),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: CypherSpacing.space5),
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.colors.accent,
                          ),
                        ),
                        const SizedBox(width: CypherSpacing.space3),
                        Expanded(
                          child: Text(
                            _statusText,
                            style: c.typography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CypherSpacing.space5,
              CypherSpacing.space3,
              CypherSpacing.space5,
              CypherSpacing.space4,
            ),
            child: FilledButton(
              onPressed: _busy ? null : onExecute,
              style: FilledButton.styleFrom(
                backgroundColor: c.colors.accent,
                foregroundColor: c.colors.textOnAccent,
                disabledBackgroundColor:
                    c.colors.accent.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(
                  vertical: CypherSpacing.space4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
                ),
              ),
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.colors.textOnAccent,
                      ),
                    )
                  : Text('Plan change', style: c.typography.buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline run report: what changed, whether validation passed, and the raw
/// bridge output — exactly what happened, nothing invented.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.lastRequest});

  final WorkspaceRunReport report;
  final String? lastRequest;

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final ok = report.ok;
    return CypherGlass(
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                size: 20,
                color: ok ? c.colors.success : c.colors.error,
              ),
              const SizedBox(width: CypherSpacing.space2),
              Expanded(
                child: Text(
                  ok ? 'Change applied' : 'Run failed',
                  style: c.typography.titleSmall.copyWith(
                    color: ok ? c.colors.success : c.colors.error,
                  ),
                ),
              ),
            ],
          ),
          if (lastRequest != null && lastRequest!.isNotEmpty) ...[
            const SizedBox(height: CypherSpacing.space2),
            Text(
              lastRequest!,
              style: c.typography.bodySmall.copyWith(
                color: c.colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (report.changedFiles.isNotEmpty) ...[
            const SizedBox(height: CypherSpacing.space4),
            Text('Changed files', style: c.typography.labelMedium),
            const SizedBox(height: CypherSpacing.space1),
            for (final file in report.changedFiles)
              Padding(
                padding: const EdgeInsets.only(
                  left: CypherSpacing.space2,
                  bottom: CypherSpacing.space1,
                ),
                child: Text(
                  file,
                  style: c.typography.monoSmall.copyWith(
                    color: c.colors.textSecondary,
                  ),
                ),
              ),
          ],
          const SizedBox(height: CypherSpacing.space4),
          Wrap(
            spacing: CypherSpacing.space2,
            runSpacing: CypherSpacing.space2,
            children: [
              _StatusChip(
                  label: 'analyzer', value: report.validation.analyzer),
              _StatusChip(label: 'tests', value: report.validation.tests),
              _StatusChip(label: 'format', value: report.validation.format),
            ],
          ),
          if (report.report.isNotEmpty) ...[
            const SizedBox(height: CypherSpacing.space3),
            SelectableText(
              report.report,
              style: c.typography.monoSmall.copyWith(
                color: c.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small pass/fail chip for one validation dimension. Anything that is not
/// an explicit `pass` (including `not run`) renders neutral or failed —
/// never as a fake success.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final passed = value == 'pass';
    final failed = value.contains('fail') || value.contains('error');
    final color = passed
        ? c.colors.success
        : (failed ? c.colors.error : c.colors.textTertiary);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CypherSpacing.space3,
        vertical: CypherSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CypherSpacing.radiusFull),
      ),
      child: Text(
        '$label · $value',
        style: c.typography.labelSmall.copyWith(color: color),
      ),
    );
  }
}
