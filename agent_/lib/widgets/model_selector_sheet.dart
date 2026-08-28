import 'package:flutter/material.dart';

import '../core/theme/cypher_theme.dart';
import '../core/theme/spacing_tokens.dart';
import '../core/ui/cypher_components.dart';
import '../services/ai_service.dart';
import '../services/provider/provider_manager.dart';
import '../services/provider/provider_configuration.dart';

/// Model selection experience (redesign Phase 14).
///
/// Separates the three concepts the configuration actually has:
/// - MODEL: the model id used for chat requests (direct endpoint config)
/// - PROVIDER: configured OpenAI-compatible capability profiles
/// - ENDPOINT: the base URL the direct connection points at
///
/// Only real functionality is exposed: browsing models from the configured
/// endpoint, picking one, and switching the active provider profile.
/// Everything else links to Settings.
class ModelSelectorSheet extends StatefulWidget {
  final AiService aiService;
  final VoidCallback? onOpenSettings;

  const ModelSelectorSheet({
    super.key,
    required this.aiService,
    this.onOpenSettings,
  });

  /// Opens the sheet inside the shared Cypher sheet chrome.
  static Future<void> show(
    BuildContext context, {
    required AiService aiService,
    VoidCallback? onOpenSettings,
  }) {
    return showCypherSheet(
      context: context,
      title: 'Choose model',
      builder: (_) => ModelSelectorSheet(
        aiService: aiService,
        onOpenSettings: onOpenSettings,
      ),
    );
  }

  @override
  State<ModelSelectorSheet> createState() => _ModelSelectorSheetState();
}

class _ModelSelectorSheetState extends State<ModelSelectorSheet> {
  List<ProviderConfiguration> _providers = const [];
  String _activeProviderId = '';
  bool _loadingProviders = true;

  List<String>? _models;
  bool _loadingModels = false;
  String? _modelsError;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final manager = ProviderManager();
      await manager.init();
      if (!mounted) return;
      setState(() {
        _providers = manager.configurations;
        _activeProviderId = manager.activeProviderId;
        _loadingProviders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProviders = false);
    }
  }

  Future<void> _browseModels() async {
    final baseUrl = widget.aiService.baseUrl.trim();
    final apiKey = widget.aiService.apiKey.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      setState(() {
        _modelsError = 'Configure an endpoint and API key in Settings first.';
        _models = const [];
      });
      return;
    }
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });
    final models = await widget.aiService.fetchAvailableModels(baseUrl, apiKey);
    if (!mounted) return;
    setState(() {
      _models = models;
      _loadingModels = false;
      if (models.isEmpty) _modelsError = 'No models found on this endpoint.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CypherSpacing.space6,
          0,
          CypherSpacing.space6,
          CypherSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current connection summary ──────────────────────────────
            _SummaryTile(
              label: 'Endpoint',
              value: widget.aiService.baseUrl.isEmpty
                  ? 'Not configured'
                  : widget.aiService.baseUrl,
            ),
            _SummaryTile(
              label: 'Model',
              value:
                  widget.aiService.model.isEmpty ? 'Default' : widget.aiService.model,
            ),
            const SizedBox(height: CypherSpacing.space4),

            // ── Model browsing (direct endpoint) ────────────────────────
            if (_loadingModels)
              const Padding(
                padding: EdgeInsets.all(CypherSpacing.space4),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_models != null && _models!.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _models!.length,
                  itemBuilder: (context, index) {
                    final model = _models![index];
                    final isCurrent = model == widget.aiService.model;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCurrent
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: isCurrent ? c.colors.accent : c.colors.textTertiary,
                      ),
                      title: Text(model, style: c.typography.bodyMedium),
                      onTap: () async {
                        await widget.aiService.saveSettings(
                          apiKey: widget.aiService.apiKey,
                          baseUrl: widget.aiService.baseUrl,
                          model: model,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              )
            else ...[
              if (_modelsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: CypherSpacing.space2),
                  child: Text(
                    _modelsError!,
                    style: c.typography.errorText,
                  ),
                ),
              CypherButton(
                label: 'Browse models on this endpoint',
                icon: Icons.list_alt_rounded,
                variant: CypherButtonVariant.secondary,
                expand: true,
                onPressed: _browseModels,
              ),
              const SizedBox(height: CypherSpacing.space4),
            ],

            // ── Provider profiles ───────────────────────────────────────
            CypherSectionHeader(title: 'Provider profiles'),
            if (_loadingProviders)
              Text('Loading…', style: c.typography.bodySmall)
            else if (_providers.isEmpty)
              Text(
                'No provider profiles configured. The direct connection above is used.',
                style: c.typography.bodySmall,
              )
            else
              ..._providers.map((provider) {
                final isActive = provider.id == _activeProviderId;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: isActive ? c.colors.success : c.colors.textTertiary,
                  ),
                  title: Text(provider.name, style: c.typography.bodyMedium),
                  subtitle: Text(
                    '${provider.model.isEmpty ? 'default model' : provider.model}'
                    ' · ${provider.capabilities.length} capabilities',
                    style: c.typography.chatMeta,
                  ),
                  onTap: isActive
                      ? null
                      : () async {
                          await ProviderManager().setActiveProvider(provider.id);
                          if (!mounted) return;
                          setState(() => _activeProviderId = provider.id);
                        },
                );
              }),

            const SizedBox(height: CypherSpacing.space4),
            CypherButton(
              label: 'Manage in Settings',
              icon: Icons.settings_rounded,
              variant: CypherButtonVariant.ghost,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenSettings?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Padding(
      padding: const EdgeInsets.only(bottom: CypherSpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label.toUpperCase(),
              style: c.typography.labelSmall.copyWith(
                color: c.colors.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: c.typography.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
