import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/ui/cypher_components.dart';
import '../../services/ai_service.dart';
import '../../services/developer_config_service.dart';
import '../../services/screen_automation_service.dart';
import '../../services/shizuku_service.dart';
import '../../services/voice_service.dart';
import '../developer/developer_console_home.dart';
import '../settings_screen.dart';
import 'about_page.dart';
import 'appearance_settings.dart';

/// Settings category hub (Phase 10).
///
/// Every tile either opens a real, implemented page or states precisely why
/// there is nothing to configure (honest unavailability — never "Coming
/// soon" for functionality that exists). Categories whose functionality
/// lives in the consolidated assistant settings screen route there with the
/// SAME live service instances the chat uses, so edits keep taking effect
/// immediately.
class SettingsMainPage extends StatefulWidget {
  final AiService aiService;
  final ShizukuService shizukuService;
  final ScreenAutomationService screenAutomationService;
  final VoiceService voiceService;

  const SettingsMainPage({
    super.key,
    required this.aiService,
    required this.shizukuService,
    required this.screenAutomationService,
    required this.voiceService,
  });

  @override
  State<SettingsMainPage> createState() => _SettingsMainPageState();
}

class _SettingsMainPageState extends State<SettingsMainPage> {
  @override
  void initState() {
    super.initState();
    developerConfig.ensureInitialized();
  }

  void _openAssistantSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          aiService: widget.aiService,
          shizukuService: widget.shizukuService,
          screenAutomationService: widget.screenAutomationService,
          voiceService: widget.voiceService,
        ),
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
        title: Text('Settings', style: c.typography.titleMedium),
      ),
      body: CypherBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: developerConfig,
            builder: (context, _) {
              final devEnabled = developerConfig.developerModeEnabled;
              return ListView(
                padding: const EdgeInsets.all(CypherSpacing.space6),
                children: [
                  _SettingsTile(
                    title: 'Appearance',
                    subtitle: 'Theme, accent, background gradients',
                    icon: Icons.palette_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppearanceSettingsPage(),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: 'Chat',
                    subtitle:
                        'No chat-specific preferences exist yet — conversation '
                        'defaults follow the app theme',
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                  _SettingsTile(
                    title: 'Voice',
                    subtitle: 'Microphone readiness and wake word state',
                    icon: Icons.mic_none_rounded,
                    onTap: _openAssistantSettings,
                  ),
                  _SettingsTile(
                    title: 'Models & AI',
                    subtitle: 'Providers, models, memory, agent behavior',
                    icon: Icons.psychology_outlined,
                    onTap: _openAssistantSettings,
                  ),
                  _SettingsTile(
                    title: 'Providers',
                    subtitle: 'OpenAI-compatible endpoints and credentials',
                    icon: Icons.cloud_outlined,
                    onTap: _openAssistantSettings,
                  ),
                  _SettingsTile(
                    title: 'Permissions',
                    subtitle: 'Microphone, overlay, accessibility, Shizuku',
                    icon: Icons.shield_outlined,
                    onTap: _openAssistantSettings,
                  ),
                  _SettingsTile(
                    title: 'Notifications',
                    subtitle: 'Notification permission is managed by Android '
                        'and checked at runtime',
                    icon: Icons.notifications_none_rounded,
                    onTap: _openAssistantSettings,
                  ),
                  _SettingsTile(
                    title: 'Overlay',
                    subtitle: 'Floating assistant launcher permission',
                    icon: Icons.layers_outlined,
                    onTap: _openAssistantSettings,
                  ),
                  _SettingsTile(
                    title: 'Accessibility',
                    subtitle: 'Screen-control service used by the agent',
                    icon: Icons.accessibility_new_rounded,
                    onTap: _openAssistantSettings,
                  ),
                  _SettingsTile(
                    title: 'Privacy',
                    subtitle:
                        'All processing is on-device except provider requests; '
                        'diagnostics are privacy-sanitized',
                    icon: Icons.lock_outline,
                  ),
                  _SettingsTile(
                    title: 'Storage & data',
                    subtitle: 'Chat history and task history management',
                    icon: Icons.storage_outlined,
                    onTap: _openAssistantSettings,
                  ),
                  if (devEnabled)
                    _SettingsTile(
                      title: 'Developer',
                      subtitle: 'Console, theme studio, orb lab, diagnostics',
                      icon: Icons.developer_mode_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DeveloperConsoleHome(),
                        ),
                      ),
                    ),
                  _SettingsTile(
                    title: 'About',
                    subtitle: 'Version, build number, credits, licenses',
                    icon: Icons.info_outline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutPage(),
                      ),
                    ),
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

/// Settings category tile. Non-tappable rows are honest statements of
/// unavailability (greyed), never fake navigation.
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final available = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: CypherSpacing.space3),
      child: Material(
        color: c.colors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(CypherSpacing.space4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.colors.accent.withOpacity(0.16),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: available
                        ? c.colors.accent
                        : c.colors.textTertiary,
                  ),
                ),
                const SizedBox(width: CypherSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: c.typography.settingsItemTitle.copyWith(
                          color: available
                              ? c.colors.textPrimary
                              : c.colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: c.typography.settingsItemSubtitle,
                      ),
                    ],
                  ),
                ),
                if (available)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: c.colors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
