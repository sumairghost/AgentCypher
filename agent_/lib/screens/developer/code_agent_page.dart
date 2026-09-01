import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/developer_config_service.dart';

/// Code Agent workflow (Phase 7).
///
/// HONEST SCOPE: this app cannot modify its own source or rebuild itself.
/// The page structures the development workflow — request, analysis, proposed
/// patch, explicit approval, application through the AUTHORIZED DEVELOPMENT
/// ENVIRONMENT (the developer's machine), and validation results — and
/// persists each session. It never writes source files and never reports a
/// change as applied unless the developer explicitly attests it.
class CodeAgentPage extends StatefulWidget {
  const CodeAgentPage({super.key});

  @override
  State<CodeAgentPage> createState() => _CodeAgentPageState();
}

class _CodeAgentPageState extends State<CodeAgentPage> {
  final TextEditingController _request = TextEditingController();
  final TextEditingController _affectedFiles = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _diff = TextEditingController();
  final TextEditingController _checkpoint = TextEditingController();
  final TextEditingController _revertNote = TextEditingController();

  String _risk = 'medium';
  bool _approved = false;
  bool _appliedViaEnvironment = false;
  String _validationAnalyzer = 'not tested';
  String _validationTests = 'not tested';
  String _validationBuild = 'not tested';
  String _result = 'unverified';
  String? _editingSessionId;

  @override
  void initState() {
    super.initState();
    developerConfig.ensureInitialized();
  }

  @override
  void dispose() {
    for (final controller in [
      _request, _affectedFiles, _reason, _summary, _diff, _checkpoint,
      _revertNote,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _sessionMap() {
    return {
      'id': _editingSessionId ??
          'code_${DateTime.now().millisecondsSinceEpoch}',
      'request': _request.text,
      'affectedFiles': _affectedFiles.text,
      'reason': _reason.text,
      'risk': _risk,
      'proposedChange': _summary.text,
      'diff': _diff.text,
      'approved': _approved,
      'appliedViaEnvironment': _appliedViaEnvironment,
      'validationAnalyzer': _validationAnalyzer,
      'validationTests': _validationTests,
      'validationBuild': _validationBuild,
      'result': _result,
      'checkpoint': _checkpoint.text,
      'revertNote': _revertNote.text,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      _editingSessionId = session['id'] as String?;
      _request.text = session['request'] as String? ?? '';
      _affectedFiles.text = session['affectedFiles'] as String? ?? '';
      _reason.text = session['reason'] as String? ?? '';
      _summary.text = session['proposedChange'] as String? ?? '';
      _diff.text = session['diff'] as String? ?? '';
      _checkpoint.text = session['checkpoint'] as String? ?? '';
      _revertNote.text = session['revertNote'] as String? ?? '';
      _risk = session['risk'] as String? ?? 'medium';
      _approved = session['approved'] as bool? ?? false;
      _appliedViaEnvironment =
          session['appliedViaEnvironment'] as bool? ?? false;
      _validationAnalyzer =
          session['validationAnalyzer'] as String? ?? 'not tested';
      _validationTests = session['validationTests'] as String? ?? 'not tested';
      _validationBuild = session['validationBuild'] as String? ?? 'not tested';
      _result = session['result'] as String? ?? 'unverified';
    });
  }

  Future<void> _saveSession() async {
    if (_request.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Describe the developer request first')),
      );
      return;
    }
    await developerConfig.saveCodeAgentSession(_sessionMap());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session saved (developer-only storage)')),
    );
  }

  void _newSession() {
    setState(() {
      _editingSessionId = null;
      _request.clear();
      _affectedFiles.clear();
      _reason.clear();
      _summary.clear();
      _diff.clear();
      _checkpoint.clear();
      _revertNote.clear();
      _risk = 'medium';
      _approved = false;
      _appliedViaEnvironment = false;
      _validationAnalyzer = 'not tested';
      _validationTests = 'not tested';
      _validationBuild = 'not tested';
      _result = 'unverified';
    });
  }

  @override
  Widget build(BuildContext context) => _codeAgentBuild(context);
}

extension _CodeAgentBuildSection on _CodeAgentPageState {
  Widget _codeAgentBuild(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Code Agent', style: c.typography.titleMedium),
        actions: [
          IconButton(
            tooltip: 'New session',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _newSession,
          ),
        ],
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CypherSpacing.space6),
            children: [
              CypherCard(
                color: c.colors.surface.withOpacity(0.4),
                padding: const EdgeInsets.all(CypherSpacing.space4),
                child: Text(
                  'This workflow never modifies source files from the app. '
                  'Changes are applied through your authorized development '
                  'environment after explicit approval, then validated '
                  '(analyzer, tests, build) and recorded honestly.',
                  style: c.typography.bodySmall,
                ),
              ),
              CypherSectionHeader(
                title: 'Request',
                subtitle: 'What should change, and why.',
              ),
              CypherInput(
                controller: _request,
                label: 'Developer request',
                hint: 'Describe the change for the development environment…',
                maxLines: 4,
                minLines: 3,
              ),
              CypherSectionHeader(
                title: 'Analysis',
                subtitle: 'Developer-entered inspection results.',
              ),
              CypherInput(
                controller: _affectedFiles,
                label: 'Affected files',
                hint: 'lib/services/example.dart\nlib/screens/example.dart',
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: CypherSpacing.space3),
              CypherInput(
                controller: _reason,
                label: 'Reason',
                hint: 'Root cause / motivation for the change',
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: CypherSpacing.space3),
              Wrap(
                spacing: CypherSpacing.space2,
                children: [
                  for (final risk in ['low', 'medium', 'high'])
                    ChoiceChip(
                      label: Text('Risk: $risk'),
                      selected: _risk == risk,
                      onSelected: (_) => setState(() => _risk = risk),
                    ),
                ],
              ),
              CypherSectionHeader(
                title: 'Proposed changes',
                subtitle:
                    'Files, summary, and the diff/patch where possible.',
              ),
              CypherInput(
                controller: _summary,
                label: 'Change summary',
                hint: 'What the patch does, file by file',
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: CypherSpacing.space3),
              CypherInput(
                controller: _diff,
                label: 'Diff / patch',
                hint: 'Unified diff or description of intended edits',
                maxLines: 10,
                minLines: 4,
              ),
              CypherSectionHeader(
                title: 'Approval',
                subtitle: 'Required before application.',
              ),
              CypherCard(
                color: Colors.transparent,
                padding: const EdgeInsets.all(CypherSpacing.space4),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Approve proposed changes'),
                      subtitle: const Text(
                          'Explicit developer approval for this exact patch.'),
                      value: _approved,
                      onChanged: (value) => setState(() => _approved = value),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'Applied via authorized development environment'),
                      subtitle: const Text(
                          'Attestation only — the app itself never writes '
                          'source files.'),
                      value: _appliedViaEnvironment,
                      onChanged: _approved
                          ? (value) =>
                              setState(() => _appliedViaEnvironment = value)
                          : null,
                    ),
                  ],
                ),
              ),
              CypherSectionHeader(
                title: 'Validation',
                subtitle: 'Record real results from each gate.',
              ),
              _ValidationDropdown(
                label: 'Analyzer',
                value: _validationAnalyzer,
                onChanged: (v) => setState(() => _validationAnalyzer = v),
              ),
              _ValidationDropdown(
                label: 'Tests',
                value: _validationTests,
                onChanged: (v) => setState(() => _validationTests = v),
              ),
              _ValidationDropdown(
                label: 'Build',
                value: _validationBuild,
                onChanged: (v) => setState(() => _validationBuild = v),
              ),
              CypherSectionHeader(
                title: 'Result',
                subtitle: 'Honest outcome classification.',
              ),
              Wrap(
                spacing: CypherSpacing.space2,
                children: [
                  for (final result in [
                    'unverified', 'success', 'partial', 'failed'
                  ])
                    ChoiceChip(
                      label: Text(result),
                      selected: _result == result,
                      onSelected: (_) => setState(() => _result = result),
                    ),
                ],
              ),
              CypherSectionHeader(
                title: 'Checkpoint / revert',
                subtitle:
                    'Name the environment checkpoint to roll back to.',
              ),
              CypherInput(
                controller: _checkpoint,
                label: 'Checkpoint',
                hint: 'e.g. git commit / tag created before applying',
              ),
              const SizedBox(height: CypherSpacing.space3),
              CypherInput(
                controller: _revertNote,
                label: 'Revert note',
                hint: 'How to undo this change safely',
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: CypherSpacing.space5),
              CypherButton(
                label: 'Save session',
                icon: Icons.save_outlined,
                onPressed: _saveSession,
                expand: true,
              ),
              const SizedBox(height: CypherSpacing.space2),
              CypherButton(
                label: 'Copy session report',
                variant: CypherButtonVariant.secondary,
                icon: Icons.copy_rounded,
                onPressed: () async {
                  final map = _sessionMap();
                  final buffer = StringBuffer()
                    ..writeln('Code Agent session')
                    ..writeln('request: ${map['request']}')
                    ..writeln('affected files: ${map['affectedFiles']}')
                    ..writeln('reason: ${map['reason']}')
                    ..writeln('risk: ${map['risk']}')
                    ..writeln('summary: ${map['proposedChange']}')
                    ..writeln('diff: ${map['diff']}')
                    ..writeln('approved: ${map['approved']}')
                    ..writeln(
                        'applied via environment: ${map['appliedViaEnvironment']}')
                    ..writeln('analyzer: ${map['validationAnalyzer']}')
                    ..writeln('tests: ${map['validationTests']}')
                    ..writeln('build: ${map['validationBuild']}')
                    ..writeln('result: ${map['result']}')
                    ..writeln('checkpoint: ${map['checkpoint']}')
                    ..writeln('revert note: ${map['revertNote']}');
                  await Clipboard.setData(
                      ClipboardData(text: buffer.toString()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Session report copied to clipboard')),
                  );
                },
                expand: true,
              ),
              CypherSectionHeader(
                title: 'Saved sessions',
                subtitle: 'Most recent first (max 20, developer-only).',
              ),
              _SessionList(
                onLoad: _loadSession,
                onNew: _newSession,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One validation gate selector (analyzer / tests / build).
class _ValidationDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _ValidationDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Padding(
      padding: const EdgeInsets.only(bottom: CypherSpacing.space3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: c.typography.settingsItemSubtitle),
          ),
          Expanded(
            child: Wrap(
              spacing: CypherSpacing.space2,
              children: [
                for (final option in ['not tested', 'pass', 'fail'])
                  ChoiceChip(
                    label: Text(option),
                    selected: value == option,
                    onSelected: (_) => onChanged(option),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Persisted sessions list bound to [CypherDeveloperConfig].
class _SessionList extends StatelessWidget {
  final ValueChanged<Map<String, dynamic>> onLoad;
  final VoidCallback onNew;

  const _SessionList({required this.onLoad, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return CypherCard(
      color: Colors.transparent,
      padding: const EdgeInsets.all(CypherSpacing.space5),
      child: AnimatedBuilder(
        animation: developerConfig,
        builder: (context, _) {
          final sessions = developerConfig.codeAgentSessions;
          if (sessions.isEmpty) {
            return Text(
              'No saved sessions yet. Sessions persist developer-only and '
              'can be reloaded to continue a workflow.',
              style: c.typography.settingsItemSubtitle,
            );
          }
          return Column(
            children: [
              for (final session in sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: CypherSpacing.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (session['request'] as String? ?? '')
                                  .split('\n')
                                  .first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.typography.settingsItemTitle,
                            ),
                            Text(
                              'result: ${session['result']} · approved: '
                              '${session['approved'] == true}',
                              style: c.typography.settingsItemSubtitle,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Load session',
                        icon: const Icon(Icons.folder_open_outlined,
                            size: 20),
                        onPressed: () {
                          onLoad(session);
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete session',
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 20, color: c.colors.error),
                        onPressed: () => developerConfig
                            .deleteCodeAgentSession(
                                session['id'] as String? ?? ''),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
