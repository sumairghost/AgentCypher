import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/ai_service.dart';
import '../../services/provider/provider_manager.dart';
import 'dev_console_utils.dart';

/// Model & provider lab (Phase 4). Lists the real provider configurations
/// and offers an opt-in connectivity probe with measured latency.
class ModelLabPage extends StatefulWidget {
  const ModelLabPage({super.key});

  @override
  State<ModelLabPage> createState() => _ModelLabPageState();
}

class _ModelLabPageState extends State<ModelLabPage> {
  final ProviderManager _providerManager = ProviderManager();
  final AiService _aiService = AiService();

  bool _loading = true;
  String? _loadError;
  bool _probing = false;
  String? _probeResult;
  int? _probeLatencyMs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await _providerManager.init();
      await _aiService.init();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$error';
      });
    }
  }

  Future<void> _probe() async {
    setState(() {
      _probing = true;
      _probeResult = null;
      _probeLatencyMs = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      await _aiService.init();
      if (!_aiService.isConfigured) {
        if (!mounted) return;
        setState(() {
          _probing = false;
          _probeResult = 'No provider configured. Configure a provider in '
              'settings first.';
        });
        return;
      }
      final response = await _aiService
          .sendMessage('Reply with exactly: OK', isAgentMode: false)
          .timeout(const Duration(seconds: 12));
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _probing = false;
        _probeLatencyMs = stopwatch.elapsedMilliseconds;
        _probeResult = response.length > 200
            ? '${response.substring(0, 200)}…'
            : response;
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _probing = false;
        _probeResult = 'Probe failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Model Lab', style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CypherSpacing.space6),
            children: [
              DevSection(
                title: 'Active model',
                subtitle: 'Loaded from persisted provider configuration.',
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else if (_loadError != null)
                    Text('Failed to load providers: $_loadError',
                        style: c.typography.bodyMedium
                            .copyWith(color: c.colors.error))
                  else ...[
                    DevStatusRow(
                      label: 'Configured',
                      detail: _aiService.isConfigured
                          ? 'Yes (credential stored)'
                          : 'No',
                      health: _aiService.isConfigured
                          ? DevHealth.ok
                          : DevHealth.warning,
                    ),
                    DevStatusRow(
                        label: 'Model', detail: _aiService.model),
                    DevStatusRow(
                        label: 'Endpoint', detail: _aiService.baseUrl),
                    DevStatusRow(
                      label: 'Active provider',
                      detail: _providerManager.activeProviderId ?? '—',
                    ),
                  ],
                ],
              ),
              DevSection(
                title: 'Connectivity probe',
                subtitle:
                    'Explicit, user-initiated model round-trip with latency.',
                children: [
                  CypherButton(
                    label: _probing ? 'Probing…' : 'Run probe',
                    onPressed: _probing ? null : _probe,
                  ),
                  if (_probeResult != null) ...[
                    const SizedBox(height: CypherSpacing.space3),
                    DevStatusRow(
                      label: 'Latency',
                      detail: _probeLatencyMs == null
                          ? '—'
                          : '$_probeLatencyMs ms',
                      health: _probeLatencyMs == null
                          ? DevHealth.error
                          : DevHealth.ok,
                    ),
                    Text(_probeResult!, style: c.typography.bodySmall),
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
