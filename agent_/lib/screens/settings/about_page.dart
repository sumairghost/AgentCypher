import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/developer_config_service.dart';
import '../../services/settings_service.dart';
import '../developer/developer_console_home.dart';

/// About Cypher (Phase 3 + 25).
///
/// Hosts the Android-style seven-tap build-number developer-mode activation:
/// Settings → About Cypher → Build number → 7 rapid taps → "Developer mode
/// enabled". Debounce and inactivity timeout live in [DeveloperTapActivator].
/// This is Cypher's own in-app developer mode and never touches Android
/// system Developer Options.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final DeveloperTapActivator _tapActivator = DeveloperTapActivator();
  final SettingsService _settingsService = SettingsService();

  String _version = 'Unavailable';
  String _buildNumber = 'Unavailable';
  bool _developerMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber =
            info.buildNumber.isEmpty ? 'Unavailable' : info.buildNumber;
      });
    } catch (_) {
      // Version stays 'Unavailable' — honest when the plugin fails.
    }
    try {
      await _settingsService.init();
      if (!mounted) return;
      setState(() {
        _developerMode = _settingsService.isDeveloperModeEnabled();
      });
    } catch (_) {
      // Keep the flag off if preferences are unavailable.
    }
  }

  Future<void> _handleBuildNumberTap() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    if (_developerMode) {
      const msg = 'Developer mode is already enabled';
      SemanticsService.announce(msg, TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(msg)),
      );
      return;
    }

    final progress = _tapActivator.registerTap(DateTime.now());
    if (progress.rejected) return;
    if (progress.activated) {
      _tapActivator.reset();
      await _settingsService.setDeveloperModeEnabled(true);
      await developerConfig.setDeveloperModeEnabled(true);
      if (!mounted) return;
      setState(() => _developerMode = true);
      const msg = 'Developer mode enabled';
      SemanticsService.announce(msg, TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!progress.shouldGiveFeedback) return;
    final msg =
        'You are now ${progress.remaining} steps away from being a developer';
    SemanticsService.announce(msg, TextDirection.ltr);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
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
        title: Text('About Cypher', style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CypherSpacing.space6),
            children: [
              CypherCard(
                color: Colors.transparent,
                padding: const EdgeInsets.all(CypherSpacing.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agent Cypher', style: c.typography.titleLarge),
                    const SizedBox(height: CypherSpacing.space1),
                    Text(
                      'An AI assistant for Sumair',
                      style: c.typography.bodyMedium,
                    ),
                    const SizedBox(height: CypherSpacing.space4),
                    DevAboutRow(label: 'Version', detail: _version),
                    DevAboutRow(label: 'Build', detail: _buildNumber),
                  ],
                ),
              ),
              CypherSectionHeader(
                title: 'Build number',
                subtitle:
                    'Tapping the build number seven times rapidly enables '
                    'Cypher developer mode. Sparse taps reset automatically.',
              ),
              CypherCard(
                color: Colors.transparent,
                padding: EdgeInsets.zero,
                onTap: _handleBuildNumberTap,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: CypherSpacing.space4),
                      Icon(Icons.build_circle_outlined,
                          size: 20, color: c.colors.accent),
                      const SizedBox(width: CypherSpacing.space4),
                      Expanded(
                        child: Text(
                          _developerMode
                              ? '$_buildNumber · Developer mode is on'
                              : _buildNumber,
                          style: c.typography.settingsItemTitle,
                        ),
                      ),
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: c.colors.textTertiary),
                      const SizedBox(width: CypherSpacing.space4),
                    ],
                  ),
                ),
              ),
              CypherSectionHeader(title: 'Links'),
              CypherCard(
                color: Colors.transparent,
                padding: EdgeInsets.zero,
                onTap: () {
                  launchUrl(
                    Uri.parse('https://github.com/sumairghost/AgentCypher'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: CypherSpacing.space4),
                      Icon(Icons.code_rounded, size: 20, color: c.colors.accent),
                      const SizedBox(width: CypherSpacing.space4),
                      Expanded(
                        child: Text('Project repository',
                            style: c.typography.settingsItemTitle),
                      ),
                      Icon(Icons.open_in_new_rounded,
                          size: 16, color: c.colors.textTertiary),
                      const SizedBox(width: CypherSpacing.space4),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CypherSpacing.space3),
              CypherCard(
                color: Colors.transparent,
                padding: EdgeInsets.zero,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Agent Cypher',
                ),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: CypherSpacing.space4),
                      Icon(Icons.menu_book_outlined,
                          size: 20, color: c.colors.accent),
                      const SizedBox(width: CypherSpacing.space4),
                      Expanded(
                        child: Text('Open source licenses',
                            style: c.typography.settingsItemTitle),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: c.colors.textTertiary),
                      const SizedBox(width: CypherSpacing.space4),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CypherSpacing.space3),
              CypherCard(
                color: Colors.transparent,
                padding: const EdgeInsets.all(CypherSpacing.space5),
                child: Text(
                  'Made by Sumair (Cypher Ghost) — personal AI assistant, '
                  'open source.',
                  style: c.typography.bodyMedium,
                ),
              ),
              if (_developerMode) ...[
                CypherSectionHeader(
                  title: 'Developer',
                  subtitle: 'Visible because developer mode is enabled.',
                ),
                CypherCard(
                  color: Colors.transparent,
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeveloperConsoleHome(),
                    ),
                  ),
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: CypherSpacing.space4),
                        Icon(Icons.terminal_rounded,
                            size: 20, color: c.colors.accent),
                        const SizedBox(width: CypherSpacing.space4),
                        Expanded(
                          child: Text('Open Developer Console',
                              style: c.typography.settingsItemTitle),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: c.colors.textTertiary),
                        const SizedBox(width: CypherSpacing.space4),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DevAboutRow extends StatelessWidget {
  final String label;
  final String detail;

  const DevAboutRow({super.key, required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CypherSpacing.space1),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style:
                  c.typography.labelMedium.copyWith(color: c.colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: c.typography.monoMedium.copyWith(
                color: c.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
