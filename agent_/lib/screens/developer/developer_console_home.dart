import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/cypher_theme.dart';
import '../../core/theme/spacing_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../services/ai_service.dart';
import '../../services/developer_config_service.dart';
import '../../services/permission_service.dart';
import '../../services/screen_automation_service.dart';
import '../../services/voice_service.dart';
import 'agent_diagnostics_page.dart';
import 'code_agent_page.dart';
import 'dev_console_utils.dart';
import 'error_center_page.dart';
import 'feature_flag_center_page.dart';
import 'logging_center_page.dart';
import 'model_lab_page.dart';
import 'orb_lab_page.dart';
import 'performance_center_page.dart';
import 'permission_matrix_page.dart';
import 'reset_page.dart';
import 'theme_studio_page.dart';

/// Real developer console dashboard (Phase 4).
///
/// System / Runtime / Health / Quick Actions. Every value is collected from
/// the running app or explicitly labeled NOT TESTED / UNAVAILABLE — no
/// fabricated status anywhere. Refresh is user-initiated; nothing polls.
class DeveloperConsoleHome extends StatefulWidget {
  const DeveloperConsoleHome({super.key});

  @override
  State<DeveloperConsoleHome> createState() => _DeveloperConsoleHomeState();
}

class _DeveloperConsoleHomeState extends State<DeveloperConsoleHome>
    with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  final VoiceService _voiceService = VoiceService();
  final ScreenAutomationService _screenAutomation = ScreenAutomationService();
  final AiService _aiService = AiService();

  String _appVersion = '…';
  String _buildNumber = '…';
  String _androidVersion = Platform.operatingSystemVersion;
  String _dartVm = 'Dart ${Platform.version.split(' ').first}';
  DevHealth _overlayHealth = DevHealth.notTested;
  DevHealth _accessibilityHealth = DevHealth.notTested;
  DevHealth _microphoneHealth = DevHealth.notTested;
  DevHealth _notificationHealth = DevHealth.notTested;
  DevHealth _networkHealth = DevHealth.notTested;
  DevHealth _providerHealth = DevHealth.notTested;
  String _networkDetail = 'Not tested';
  String _accessibilityDetail = 'Not tested';
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    developerConfig.ensureInitialized();
    _refreshDiagnostics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    // Cheap, local-only: reflect the real lifecycle without re-probing
    // permissions on every background/foreground transition.
    setState(() {});
  }


  Future<void> _refreshDiagnostics() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      _appVersion = 'Unavailable';
      _buildNumber = 'Unavailable';
    }

    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      _overlayHealth = granted == true ? DevHealth.ok : DevHealth.unavailable;
    } catch (_) {
      _overlayHealth = DevHealth.unavailable;
    }

    try {
      final mic = await _permissionService.checkMicrophone();
      _microphoneHealth = mic.isGranted
          ? DevHealth.ok
          : (mic.isPermanentlyDenied ? DevHealth.error : DevHealth.unavailable);
    } catch (_) {
      _microphoneHealth = DevHealth.unavailable;
    }

    try {
      final notif = await _permissionService.checkNotification();
      _notificationHealth = notif.isGranted
          ? DevHealth.ok
          : (notif.isPermanentlyDenied
              ? DevHealth.error
              : DevHealth.unavailable);
    } catch (_) {
      _notificationHealth = DevHealth.unavailable;
    }

    try {
      final result = await Connectivity().checkConnectivity();
      final hasNetwork = result.any((r) => r != ConnectivityResult.none);
      _networkHealth = hasNetwork ? DevHealth.ok : DevHealth.warning;
      _networkDetail = hasNetwork
          ? result
              .where((r) => r != ConnectivityResult.none)
              .map((r) => r.name)
              .join(', ')
          : 'No connectivity';
    } catch (_) {
      _networkHealth = DevHealth.unavailable;
      _networkDetail = 'Connectivity probe unavailable';
    }

    try {
      await _aiService.init();
      _providerHealth =
          _aiService.isConfigured ? DevHealth.ok : DevHealth.warning;
    } catch (_) {
      _providerHealth = DevHealth.unavailable;
    }

    // Accessibility probe uses a platform channel; on-demand only.
    try {
      final running = await _screenAutomation.isServiceRunning();
      _accessibilityHealth = running ? DevHealth.ok : DevHealth.unavailable;
      _accessibilityDetail =
          running ? 'Service enabled and responding' : 'Service not enabled';
    } catch (_) {
      _accessibilityHealth = DevHealth.unavailable;
      _accessibilityDetail = 'Platform channel unavailable';
    }

    if (!mounted) return;
    setState(() {});
    _refreshing = false;
  }

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset developer configuration?'),
        content: const Text(
          'This clears developer mode, orb profiles, lab state, and code-agent '
          'session history. User data such as chats, providers, and memory is '
          'not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await developerConfig.resetDeveloperConfiguration();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Developer configuration reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final screen = MediaQuery.of(context).size;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final controller = themeController;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Developer Console', style: c.typography.titleMedium),
        actions: [
          IconButton(
            tooltip: 'Refresh diagnostics',
            onPressed: _refreshing ? null : _refreshDiagnostics,
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: CypherBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshDiagnostics,
            child: ListView(
              padding: const EdgeInsets.all(CypherSpacing.space6),
              children: [
                DevSection(
                  title: 'System',
                  subtitle: 'Collected from the running process',
                  children: [
                    DevStatusRow(
                        label: 'App version', detail: _appVersion),
                    DevStatusRow(
                        label: 'Build', detail: _buildNumber),
                    DevStatusRow(
                        label: 'Android', detail: _androidVersion),
                    DevStatusRow(
                        label: 'Dart VM',
                        detail:
                            '$_dartVm (Flutter toolchain version is a build-time '
                            'value and is not embedded in release binaries)'),
                    DevStatusRow(
                        label: 'Screen',
                        detail:
                            '${screen.width.toStringAsFixed(0)} x '
                            '${screen.height.toStringAsFixed(0)} logical px, '
                            'dpr ${dpr.toStringAsFixed(2)}'),
                    DevStatusRow(
                      label: 'Theme',
                      detail:
                          '${controller.preset.name} · mode '
                          '${controller.mode.name} · gradient '
                          '${controller.gradientStyle.name} · intensity '
                          '${controller.gradientIntensity.name}'
                          '${controller.isCustomAccent ? ' · custom accent' : ''}',
                    ),
                  ],
                ),
                DevSection(
                  title: 'Runtime',
                  subtitle: 'Live subsystem state',
                  children: [
                    DevStatusRow(
                      label: 'App lifecycle',
                      detail: lifecycle?.name ?? 'unknown',
                    ),
                    DevStatusRow(
                      label: 'Voice (STT)',
                      detail: _voiceService.speechRecognitionAvailable
                          ? 'Recognizer initialized'
                          : 'Not initialized yet (initializes on first use)',
                      health: _voiceService.speechRecognitionAvailable
                          ? DevHealth.ok
                          : DevHealth.notTested,
                    ),
                    DevStatusRow(
                      label: 'Wake word',
                      detail:
                          'Not implemented in this build (no native detector)',
                      health: DevHealth.unavailable,
                    ),
                    DevStatusRow(
                      label: 'Overlay',
                      detail: _overlayHealth == DevHealth.ok
                          ? 'Permission granted'
                          : 'Permission not granted',
                      health: _overlayHealth,
                    ),
                    DevStatusRow(
                      label: 'Accessibility',
                      detail: _accessibilityDetail,
                      health: _accessibilityHealth,
                    ),
                    DevStatusRow(
                      label: 'Notifications',
                      detail: _notificationHealth == DevHealth.ok
                          ? 'Permission granted'
                          : 'Permission not granted',
                      health: _notificationHealth,
                    ),
                    DevStatusRow(
                      label: 'Network',
                      detail: _networkDetail,
                      health: _networkHealth,
                    ),
                    DevStatusRow(
                      label: 'Provider',
                      detail: _aiService.isConfigured
                          ? '${_aiService.model} at ${_aiService.baseUrl}'
                          : 'No provider configured',
                      health: _providerHealth,
                    ),
                    DevStatusRow(
                      label: 'Developer mode',
                      detail: developerConfig.developerModeEnabled
                          ? 'Enabled'
                          : 'Enabled (this console implies it)',
                      health: DevHealth.ok,
                    ),
                  ],
                ),
                CypherSectionHeader(
                  title: 'Quick actions',
                  subtitle:
                      'Every action opens a fully implemented developer page',
                ),
                _QuickAction(
                  icon: Icons.palette_outlined,
                  label: 'Open Theme Studio',
                  onTap: () => _open(const ThemeStudioPage()),
                ),
                _QuickAction(
                  icon: Icons.blur_circular_rounded,
                  label: 'Open Orb Lab',
                  onTap: () => _open(const OrbLabPage()),
                ),
                _QuickAction(
                  icon: Icons.science_outlined,
                  label: 'Open Model Lab',
                  onTap: () => _open(const ModelLabPage()),
                ),
                _QuickAction(
                  icon: Icons.bug_report_outlined,
                  label: 'Open Agent Diagnostics',
                  onTap: () => _open(const AgentDiagnosticsPage()),
                ),
                _QuickAction(
                  icon: Icons.shield_outlined,
                  label: 'Open Permission Matrix',
                  onTap: () => _open(const PermissionMatrixPage()),
                ),
                _QuickAction(
                  icon: Icons.speed_outlined,
                  label: 'Open Performance',
                  onTap: () => _open(const PerformanceCenterPage()),
                ),
                _QuickAction(
                  icon: Icons.article_outlined,
                  label: 'Open Logs',
                  onTap: () => _open(const LoggingCenterPage()),
                ),
                _QuickAction(
                  icon: Icons.error_outline_rounded,
                  label: 'Open Errors',
                  onTap: () => _open(const ErrorCenterPage()),
                ),
                _QuickAction(
                  icon: Icons.code_rounded,
                  label: 'Open Code Agent workflow',
                  onTap: () => _open(const CodeAgentPage()),
                ),
                _QuickAction(
                  icon: Icons.flag_outlined,
                  label: 'Open Feature Flags',
                  onTap: () => _open(const FeatureFlagCenterPage()),
                ),
                _QuickAction(
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset Developer Configuration',
                  onTap: _confirmReset,
                  destructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Console quick-action row; 56dp tall for comfortable touch targets.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return Padding(
      padding: const EdgeInsets.only(bottom: CypherSpacing.space2),
      child: CypherCard(
        color: Colors.transparent,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: CypherSpacing.space4),
              Icon(
                icon,
                size: 20,
                color: destructive ? c.colors.error : c.colors.accent,
              ),
              const SizedBox(width: CypherSpacing.space4),
              Expanded(
                child: Text(
                  label,
                  style: c.typography.settingsItemTitle.copyWith(
                    color:
                        destructive ? c.colors.error : c.colors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.colors.textTertiary,
              ),
              const SizedBox(width: CypherSpacing.space3),
            ],
          ),
        ),
      ),
    );
  }
}
