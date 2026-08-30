import 'package:flutter/material.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import 'appearance_settings.dart';

/// Settings category hub.
///
/// Renders a single coherent list of category tiles. Each entry navigates to
/// an existing or planned settings page. Tiles for which no real
/// implementation yet exists are still shown (per category brief) but display
/// a "Coming soon" subtitle so the user is never told a fake button does
/// something. No duplicate implementations of existing pages are created —
/// Appearance routes to the real [AppearanceSettingsPage].
class SettingsMainPage extends StatelessWidget {
  const SettingsMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final entries = _SettingsCatalog.entries;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Settings', style: c.typography.titleMedium),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(CypherSpacing.space6),
          itemCount: entries.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: CypherSpacing.space3),
          itemBuilder: (context, i) {
            final entry = entries[i];
            return _SettingsTile(entry: entry);
          },
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final _SettingsEntry entry;
  const _SettingsTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final isAvailable = entry.builder != null;

    return Material(
      color: c.colors.surface.withOpacity(0.6),
      borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
        onTap: isAvailable
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => entry.builder!(),
                  ),
                );
              }
            : null,
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
                  entry.icon,
                  size: 20,
                  color: c.colors.accent,
                ),
              ),
              const SizedBox(width: CypherSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: c.typography.settingsItemTitle.copyWith(
                        color: isAvailable
                            ? c.colors.textPrimary
                            : c.colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAvailable
                          ? entry.subtitle
                          : '${entry.subtitle} • Coming soon',
                      style: c.typography.settingsItemSubtitle,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder? builder;
  const _SettingsEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.builder,
  });
}

class _SettingsCatalog {
  static const List<_SettingsEntry> entries = [
    _SettingsEntry(
      title: 'Appearance',
      subtitle: 'Theme, accent, background',
      icon: Icons.palette_outlined,
      builder: _appearanceBuilder,
    ),
    _SettingsEntry(
      title: 'Chat',
      subtitle: 'Conversation defaults',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    _SettingsEntry(
      title: 'Voice',
      subtitle: 'Voice and audio preferences',
      icon: Icons.mic_none_rounded,
    ),
    _SettingsEntry(
      title: 'Models & AI',
      subtitle: 'Configured model and provider',
      icon: Icons.psychology_outlined,
    ),
    _SettingsEntry(
      title: 'Providers',
      subtitle: 'Provider endpoints',
      icon: Icons.cloud_outlined,
    ),
    _SettingsEntry(
      title: 'Permissions',
      subtitle: 'System permissions and consent',
      icon: Icons.shield_outlined,
    ),
    _SettingsEntry(
      title: 'Notifications',
      subtitle: 'Alerts and ongoing tasks',
      icon: Icons.notifications_none_rounded,
    ),
    _SettingsEntry(
      title: 'Overlay',
      subtitle: 'Floating assistant launcher',
      icon: Icons.layers_outlined,
    ),
    _SettingsEntry(
      title: 'Accessibility',
      subtitle: 'Motion, contrast, scaling',
      icon: Icons.accessibility_new_rounded,
    ),
    _SettingsEntry(
      title: 'Privacy',
      subtitle: 'On-device data handling',
      icon: Icons.lock_outline,
    ),
    _SettingsEntry(
      title: 'Storage & data',
      subtitle: 'Local cache and history',
      icon: Icons.storage_outlined,
    ),
    _SettingsEntry(
      title: 'Developer',
      subtitle: 'Diagnostics and logs',
      icon: Icons.developer_mode_outlined,
    ),
    _SettingsEntry(
      title: 'About',
      subtitle: 'App version and licenses',
      icon: Icons.info_outline,
    ),
  ];
}

Widget _appearanceBuilder(BuildContext _) => const AppearanceSettingsPage();
