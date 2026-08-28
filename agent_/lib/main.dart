import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:developer';
import 'config/feature_flags.dart';
import 'config/app_theme.dart';
import 'core/theme/cypher_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'overlay_main.dart';
import 'services/agent_setup.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  // The overlay isolate resolves its own theme from the shared token system;
  // the controller self-initializes from SharedPreferences.
  final overlayCypher = themeController.theme;
  final overlayColors = overlayCypher.colors;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: Colors.transparent,
        dialogBackgroundColor: Colors.transparent,
        primaryColor: overlayColors.accent,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          background: Colors.transparent,
          primary: overlayColors.accent,
          surface: overlayColors.surface,
          onSurface: overlayColors.textPrimary,
          onPrimary: overlayColors.textInverse,
        ),
      ),
      builder: (context, child) {
        return CypherTheme(
          data: overlayCypher,
          child: Container(color: Colors.transparent, child: child),
        );
      },
      home: const OverlayApp(),
    ),
  );
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void Function(String task)? onOverlayTask;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Agent Cypher services
  try {
    final agent = AgentSetup();
    await agent.initialize();
    log('Agent Cypher initialization successful', name: 'main');
  } catch (e) {
    log('Agent Cypher initialization failed: $e', name: 'main', level: 2000);
    // Continue anyway - some features may still work
  }

  if (FeatureFlags.floatingOverlayEnabled) {
    FlutterOverlayWindow.overlayListener.listen(
      (event) {
        log("Main app received from overlay: $event");
        if (event is String && event.trim().isNotEmpty) {
          final handler = onOverlayTask;
          if (handler != null) {
            handler(event.trim());
          } else {
            log("Warning: overlay task received but no handler registered yet");
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        log(
          'Overlay listener error: $error',
          name: 'main',
          error: error,
          stackTrace: stackTrace,
        );
      },
      cancelOnError: false,
    );
  }

  var onboardingCompleted = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  } catch (error, stackTrace) {
    log(
      'Local preferences unavailable; using safe defaults: $error',
      name: 'main',
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );
  }

  // Bridge the token-based ThemeController with the legacy themeNotifier and
  // seed it from stored preferences (including the legacy `themeMode` key).
  try {
    await syncThemeNotifier();
  } catch (error, stackTrace) {
    log(
      'Theme controller initialization failed; using defaults: $error',
      name: 'main',
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );
  }

  runApp(AgentCypherApp(onboardingCompleted: onboardingCompleted));
}

class AgentCypherApp extends StatelessWidget {
  final bool onboardingCompleted;
  const AgentCypherApp({super.key, required this.onboardingCompleted});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'Agent Cypher',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Both themes derive from the active token preset so preset changes
          // and brightness-driven switching stay consistent.
          theme: themeController.materialThemeFor(Brightness.light),
          darkTheme: themeController.materialThemeFor(Brightness.dark),
          builder: (context, child) {
            return AnimatedBuilder(
              animation: themeController,
              builder: (context, _) {
                return CypherTheme(
                  data: themeController.theme,
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
          home: onboardingCompleted
              ? const HomeScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}
