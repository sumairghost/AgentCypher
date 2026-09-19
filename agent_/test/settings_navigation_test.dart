import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/core/theme/color_tokens.dart';
import 'package:agent_cypher/core/theme/cypher_theme.dart';
import 'package:agent_cypher/screens/settings/settings_main.dart';
import 'package:agent_cypher/services/ai_service.dart';
import 'package:agent_cypher/services/developer_config_service.dart';
import 'package:agent_cypher/services/screen_automation_service.dart';
import 'package:agent_cypher/services/shizuku_service.dart';
import 'package:agent_cypher/services/voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return CypherTheme(
    data: CypherThemeData(
      isDark: true,
      accentFamily: AccentFamily.crimson,
      preset: CypherThemePreset.crimsonNight,
    ),
    child: MaterialApp(home: child),
  );
}

SettingsMainPage _page() {
  return SettingsMainPage(
    aiService: AiService(),
    shizukuService: ShizukuService(),
    screenAutomationService: ScreenAutomationService(),
    voiceService: VoiceService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> resetDevConfig() async {
    final prefs = await SharedPreferences.getInstance();
    developerConfig.resetForTesting(prefs);
  }

  testWidgets('settings hub shows real categories and hides Developer '
      'when developer mode is off', (tester) async {
    await resetDevConfig();
    await tester.pumpWidget(_wrap(_page()));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Models & AI'), findsOneWidget);
    // Hub entries below the default 600px test viewport live in a lazily-built ListView and are not built until scrolled into view.
    await tester.scrollUntilVisible(find.text('About'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    // Honest unavailability: no fake "Coming soon" for existing features.
    expect(find.textContaining('Coming soon'), findsNothing);
    expect(find.text('Developer'), findsNothing);
  });

  testWidgets('Developer tile appears and navigates to the console when '
      'developer mode is enabled', (tester) async {
    await resetDevConfig();
    await developerConfig.setDeveloperModeEnabled(true);

    await tester.pumpWidget(_wrap(_page()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Developer'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Developer'), findsOneWidget);
    await tester.tap(find.text('Developer'));
    // The console embeds a continuously animating orb, so pumpAndSettle never completes; pump a fixed duration instead.
    await tester.pump(const Duration(seconds: 1));

    // The real console dashboard is pushed, with its real sections.
    expect(find.text('Developer Console'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('Appearance tile navigates to the real appearance page',
      (tester) async {
    await resetDevConfig();
    await tester.pumpWidget(_wrap(_page()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    // 'Theme mode' sits below the fold in the appearance page.
    await tester.scrollUntilVisible(find.text('Theme mode'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Theme mode'), findsOneWidget);
  });
}
