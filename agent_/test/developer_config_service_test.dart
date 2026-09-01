import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/core/ui/orb_config.dart';
import 'package:agent_cypher/services/developer_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CypherDeveloperConfig persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('developer mode flag persists and notifies', () async {
      final config = CypherDeveloperConfig.instance;
      config.resetForTesting(await SharedPreferences.getInstance());
      expect(config.developerModeEnabled, isFalse);

      var notified = 0;
      config.addListener(() => notified++);
      await config.setDeveloperModeEnabled(true);
      expect(config.developerModeEnabled, isTrue);
      expect(notified, 1);

      // A second instance reads the same persisted flag (the legacy
      // settings screen uses the identical preference key).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('developer_mode_enabled'), isTrue);
    });

    test('orb profiles round-trip: save, duplicate, restore, delete', () async {
      final config = CypherDeveloperConfig.instance;
      config.resetForTesting(await SharedPreferences.getInstance());

      const profileConfig = CypherOrbConfig(deformation: 0.5, glow: 0.4);
      final profile = CypherOrbProfile(
        id: 'orb_1',
        name: 'Calm',
        config: profileConfig,
        updatedAt: DateTime(2026, 1, 1),
      );
      await config.saveOrbProfile(profile);
      expect(config.orbProfiles.length, 1);
      expect(config.orbProfiles.first.config, profileConfig);

      // Saving with the same id updates instead of duplicating.
      await config.saveOrbProfile(profile.renamed('Calm v2'));
      expect(config.orbProfiles.length, 1);
      expect(config.orbProfiles.first.name, 'Calm v2');

      // Duplicate id gets its own entry.
      await config.saveOrbProfile(
        profile.copyWithIdForTest('orb_2'),
      );
      expect(config.orbProfiles.length, 2);

      await config.deleteOrbProfile('orb_1');
      expect(config.orbProfiles.length, 1);
      expect(config.orbProfiles.first.id, 'orb_2');

      await config.deleteOrbProfile('does-not-exist');
      expect(config.orbProfiles.length, 1);
    });

    test('orb lab config persists and can be cleared', () async {
      final config = CypherDeveloperConfig.instance;
      config.resetForTesting(await SharedPreferences.getInstance());
      expect(config.orbLabConfig, isNull);

      const lab = CypherOrbConfig(motionScale: 1.25);
      await config.setOrbLabConfig(lab);
      expect(config.orbLabConfig, lab);

      await config.setOrbLabConfig(null);
      expect(config.orbLabConfig, isNull);
    });

    test('code agent sessions persist with bounded history', () async {
      final config = CypherDeveloperConfig.instance;
      config.resetForTesting(await SharedPreferences.getInstance());

      for (var i = 0; i < 25; i++) {
        await config.saveCodeAgentSession({
          'id': 'code_$i',
          'request': 'request $i',
          'result': 'unverified',
        });
      }
      expect(config.codeAgentSessions.length, 20);
      // Most recent first.
      expect(config.codeAgentSessions.first['id'], 'code_24');

      await config.saveCodeAgentSession({
        'id': 'code_24',
        'request': 'updated',
        'result': 'success',
      });
      expect(config.codeAgentSessions.first['request'], 'updated');
      expect(config.codeAgentSessions.length, 20);

      await config.deleteCodeAgentSession('code_24');
      expect(config.codeAgentSessions.first['id'], 'code_23');
    });

    test('resetDeveloperConfiguration clears only developer state', () async {
      final config = CypherDeveloperConfig.instance;
      config.resetForTesting(await SharedPreferences.getInstance());
      await config.setDeveloperModeEnabled(true);
      await config.saveOrbProfile(
        CypherOrbProfile(
          id: 'orb_1',
          name: 'x',
          config: const CypherOrbConfig(),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      await config.setExpensiveDiagnosticsEnabled(true);
      await config.saveCodeAgentSession({'id': 'code_1'});

      await config.resetDeveloperConfiguration();

      expect(config.developerModeEnabled, isFalse);
      expect(config.orbProfiles, isEmpty);
      expect(config.orbLabConfig, isNull);
      expect(config.codeAgentSessions, isEmpty);
      expect(config.expensiveDiagnosticsEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('developer_mode_enabled'), isNull);
      expect(prefs.getString('dev_orb_profiles'), isNull);
    });
  });
}

extension on CypherOrbProfile {
  CypherOrbProfile copyWithIdForTest(String id) => CypherOrbProfile(
        id: id,
        name: name,
        config: config,
        updatedAt: updatedAt,
      );
}
