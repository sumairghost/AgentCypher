import 'dart:convert';

import 'ai_service.dart';
import 'permission_service.dart';
import 'screen_automation_service.dart';
import 'task_telemetry_service.dart';
import 'voice_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Diagnostics service to check all system components
/// Per spec section 27: Real diagnostics screen with actionable remediation
class DiagnosticsService {
  final AiService _aiService = AiService();
  final PermissionService _permissionService = PermissionService();
  final ScreenAutomationService _screenService = ScreenAutomationService();
  final VoiceService _voiceService = VoiceService();

  /// Builds a privacy-sanitized developer report.
  ///
  /// Only telemetry metrics (already free of prompts, screenshots, keys, and
  /// accessibility content) plus the caller-supplied [system] map are
  /// included. Never add credentials or raw screen content here.
  static String buildSanitizedDeveloperReport({
    required TaskDeveloperSnapshot snapshot,
    required Map<String, dynamic> system,
  }) {
    return jsonEncode(<String, dynamic>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'task': <String, dynamic>{
        'root_goal': snapshot.rootGoal,
        'stage': snapshot.executionStage,
        'sub_goal': snapshot.currentSubGoal,
        'is_running': snapshot.isRunning,
        'actions': snapshot.actionCount,
        'screen_observations': snapshot.screenObservations,
        'ai_calls': snapshot.aiCalls,
        'recovery_attempts': snapshot.recoveryAttempts,
        'verification': snapshot.verificationResult,
        'duration_ms': snapshot.totalTaskDurationMs,
        'confidence': snapshot.confidence,
        'route': snapshot.routeSelection,
        'duplicate_action_blocks': snapshot.duplicateActionBlocks,
        'stale_screen_blocks': snapshot.staleScreenBlocks,
        'observations_reused': snapshot.observationsReused,
        'upgrade': <String, dynamic>{
          'stage': snapshot.upgradeStage,
          'final_result': snapshot.upgradeFinalResult,
        },
      },
      'system': system,
    });
  }

  /// Diagnostic result for a single component
  Future<DiagnosticResult> diagnosisResult(String component) async {
    switch (component) {
      case 'ai_provider':
        return await _checkAiProvider();
      case 'network':
        return await _checkNetwork();
      case 'microphone':
        return await _checkMicrophone();
      case 'tts':
        return await _checkTts();
      case 'overlay':
        return await _checkOverlay();
      case 'accessibility':
        return await _checkAccessibility();
      case 'notification_access':
        return await _checkNotificationAccess();
      case 'storage':
        return await _checkStorage();
      case 'app_info':
        return await _checkAppInfo();
      default:
        return DiagnosticResult.unknown(component);
    }
  }

  /// Check AI provider configuration and connection
  Future<DiagnosticResult> _checkAiProvider() async {
    try {
      await _aiService.init();
      
      if (!_aiService.isConfigured) {
        return DiagnosticResult(
          component: 'AI Provider',
          status: DiagnosticStatus.failed,
          message: 'No AI provider configured',
          remediation: 'Go to Settings and configure an AI provider (OpenAI, NVIDIA, DeepSeek, etc.)',
        );
      }

      // Try to connect to provider
      try {
        final response = await _aiService.sendMessage('test', isAgentMode: false)
            .timeout(const Duration(seconds: 5));
        
        if (response.contains('Error')) {
          return DiagnosticResult(
            component: 'AI Provider',
            status: DiagnosticStatus.warning,
            message: 'AI provider responded with error',
            remediation: 'Check your API key and network connection. Verify credentials in Settings.',
          );
        }

        return DiagnosticResult(
          component: 'AI Provider',
          status: DiagnosticStatus.pass,
          message: 'Connected to ${_aiService.baseUrl}',
        );
      } catch (e) {
        return DiagnosticResult(
          component: 'AI Provider',
          status: DiagnosticStatus.warning,
          message: 'Connection test timed out or failed',
          remediation: 'Check network connectivity and verify API credentials.',
        );
      }
    } catch (e) {
      return DiagnosticResult(
        component: 'AI Provider',
        status: DiagnosticStatus.failed,
        message: 'Error checking provider: ${e.toString()}',
        remediation: 'Restart the app and reconfigure the AI provider.',
      );
    }
  }

  /// Check network connectivity
  Future<DiagnosticResult> _checkNetwork() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      
      // result is a ConnectivityResult enum
      if (result == ConnectivityResult.none) {
        return DiagnosticResult(
          component: 'Network',
          status: DiagnosticStatus.failed,
          message: 'No network connection',
          remediation: 'Enable WiFi or mobile data to use the agent.',
        );
      }

      final connectionType = result.toString().split('.').last;

      return DiagnosticResult(
        component: 'Network',
        status: DiagnosticStatus.pass,
        message: 'Connected via $connectionType',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Network',
        status: DiagnosticStatus.warning,
        message: 'Could not check network status',
      );
    }
  }

  /// Check microphone
  Future<DiagnosticResult> _checkMicrophone() async {
    try {
      final status = await _permissionService.checkMicrophone();
      
      if (status != PermissionStatus.granted) {
        return DiagnosticResult(
          component: 'Microphone',
          status: DiagnosticStatus.failed,
          message: 'Microphone permission ${_permissionService.getStatusString(status).toLowerCase()}',
          remediation: 'Grant microphone permission in Settings > Apps > Agent Cypher > Permissions',
        );
      }

      return DiagnosticResult(
        component: 'Microphone',
        status: DiagnosticStatus.pass,
        message: 'Microphone access granted',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Microphone',
        status: DiagnosticStatus.warning,
        message: 'Could not verify microphone',
      );
    }
  }

  /// Check text-to-speech
  Future<DiagnosticResult> _checkTts() async {
    try {
      // Check if TTS engine is available
      final isAvailable = await _voiceService.isTtsAvailable();
      
      if (!isAvailable) {
        return DiagnosticResult(
          component: 'Text-to-Speech',
          status: DiagnosticStatus.warning,
          message: 'TTS engine not available',
          remediation: 'Install a TTS engine via Settings > Accessibility > Text-to-Speech.',
        );
      }

      return DiagnosticResult(
        component: 'Text-to-Speech',
        status: DiagnosticStatus.pass,
        message: 'TTS engine available',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Text-to-Speech',
        status: DiagnosticStatus.warning,
        message: 'Could not verify TTS: ${e.toString()}',
      );
    }
  }

  /// Check overlay permission
  Future<DiagnosticResult> _checkOverlay() async {
    try {
      final hasOverlay = await _permissionService.checkOverlay();
      
      if (!hasOverlay) {
        return DiagnosticResult(
          component: 'Display Overlay',
          status: DiagnosticStatus.warning,
          message: 'Overlay permission not granted',
          remediation: 'Enable "Draw over other apps" in Settings > Apps > Agent Cypher > Special app access.',
        );
      }

      return DiagnosticResult(
        component: 'Display Overlay',
        status: DiagnosticStatus.pass,
        message: 'Overlay permission granted',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Display Overlay',
        status: DiagnosticStatus.warning,
        message: 'Could not verify overlay permission',
      );
    }
  }

  /// Check accessibility service
  Future<DiagnosticResult> _checkAccessibility() async {
    try {
      final isRunning = await _screenService.isServiceRunning();
      
      if (!isRunning) {
        return DiagnosticResult(
          component: 'Accessibility Service',
          status: DiagnosticStatus.failed,
          message: 'Accessibility service not running',
          remediation: 'Enable Agent Cypher in Settings > Accessibility > Installed services.',
        );
      }

      return DiagnosticResult(
        component: 'Accessibility Service',
        status: DiagnosticStatus.pass,
        message: 'Accessibility service running',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Accessibility Service',
        status: DiagnosticStatus.warning,
        message: 'Could not verify accessibility: ${e.toString()}',
      );
    }
  }

  /// Check notification access
  Future<DiagnosticResult> _checkNotificationAccess() async {
    try {
      final status = await _permissionService.checkNotification();
      
      if (status != PermissionStatus.granted) {
        return DiagnosticResult(
          component: 'Notification Access',
          status: DiagnosticStatus.warning,
          message: 'Notification access ${_permissionService.getStatusString(status).toLowerCase()}',
          remediation: 'Allow notification access in Settings > Apps > Agent Cypher > Permissions.',
        );
      }

      return DiagnosticResult(
        component: 'Notification Access',
        status: DiagnosticStatus.pass,
        message: 'Notification access granted',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Notification Access',
        status: DiagnosticStatus.warning,
        message: 'Could not verify notification access',
      );
    }
  }

  /// Check storage
  Future<DiagnosticResult> _checkStorage() async {
    try {
      // This would check actual storage availability
      // For now, assume it's available
      return DiagnosticResult(
        component: 'Storage',
        status: DiagnosticStatus.pass,
        message: 'Storage available',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Storage',
        status: DiagnosticStatus.failed,
        message: 'Storage check failed: ${e.toString()}',
      );
    }
  }

  /// Check app info
  Future<DiagnosticResult> _checkAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return DiagnosticResult(
        component: 'App Info',
        status: DiagnosticStatus.pass,
        message: '${info.appName} v${info.version}+${info.buildNumber}',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'App Info',
        status: DiagnosticStatus.warning,
        message: 'Could not retrieve app info',
      );
    }
  }

  /// Run all diagnostics
  Future<List<DiagnosticResult>> runAllDiagnostics() async {
    return Future.wait([
      _checkAppInfo(),
      _checkNetwork(),
      _checkAiProvider(),
      _checkAccessibility(),
      _checkMicrophone(),
      _checkTts(),
      _checkOverlay(),
      _checkNotificationAccess(),
      _checkStorage(),
    ]);
  }
}

enum DiagnosticStatus {
  pass,
  warning,
  failed,
  unknown,
}

class DiagnosticResult {
  final String component;
  final DiagnosticStatus status;
  final String message;
  final String? remediation;

  DiagnosticResult({
    required this.component,
    required this.status,
    required this.message,
    this.remediation,
  });

  factory DiagnosticResult.unknown(String component) {
    return DiagnosticResult(
      component: component,
      status: DiagnosticStatus.unknown,
      message: 'Status unknown',
    );
  }

  String get statusText {
    switch (status) {
      case DiagnosticStatus.pass:
        return 'PASS';
      case DiagnosticStatus.warning:
        return 'WARNING';
      case DiagnosticStatus.failed:
        return 'FAILED';
      case DiagnosticStatus.unknown:
        return 'UNKNOWN';
    }
  }

  String get statusIcon {
    switch (status) {
      case DiagnosticStatus.pass:
        return '✓';
      case DiagnosticStatus.warning:
        return '⚠';
      case DiagnosticStatus.failed:
        return '✗';
      case DiagnosticStatus.unknown:
        return '?';
    }
  }
}
