import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/core/ui/orb_config.dart';

void main() {
  group('CypherOrbConfig', () {
    test('standard config equals the default constructor', () {
      expect(const CypherOrbConfig.standard(), const CypherOrbConfig());
    });

    test('copyWith overrides and clears energy values', () {
      const base = CypherOrbConfig();
      final overridden = base.copyWith(idleEnergy: 0.5, glow: 1.6);
      expect(overridden.idleEnergy, 0.5);
      expect(overridden.glow, 1.6);
      expect(overridden.listeningEnergy, isNull);
      final cleared = overridden.copyWith(clearIdleEnergy: true);
      expect(cleared.idleEnergy, isNull);
      expect(cleared.glow, 1.6);
    });

    test('JSON round-trip preserves values', () {
      const config = CypherOrbConfig(
        idleEnergy: 0.2,
        speakingEnergy: 0.8,
        deformation: 1.4,
        deformationSpeed: 2.0,
        fluidSpeed: 0.5,
        jellySoftness: 0.3,
        elasticity: 1.7,
        damping: 0.8,
        audioInfluence: 1.2,
        tapResponse: 0.4,
        touchInfluence: 1.9,
        waveStrength: 0.6,
        glow: 1.1,
        highlight: 0.9,
        internalColorMix: 0.35,
        motionScale: 1.5,
      );
      final decoded = CypherOrbConfig.fromJson(config.toJson());
      expect(decoded, config);
    });

    test('fromJson clamps out-of-range values instead of crashing', () {
      final decoded = CypherOrbConfig.fromJson(const {
        'deformation': 99.0,
        'jellySoftness': -3.0,
        'waveStrength': 42.0,
        'elasticity': 1000.0,
        'motionScale': -1.0,
        'idleEnergy': 7.0,
      });
      expect(decoded.deformation, 2.0);
      expect(decoded.jellySoftness, 0.0);
      expect(decoded.waveStrength, 1.0);
      expect(decoded.elasticity, 2.5);
      expect(decoded.motionScale, 0.0);
      expect(decoded.idleEnergy, 1.0);
    });

    test('fromJson ignores wrong types and falls back to defaults', () {
      final decoded = CypherOrbConfig.fromJson(const {
        'deformation': 'not-a-number',
        'idleEnergy': true,
      });
      expect(decoded.deformation, 1.0);
      expect(decoded.idleEnergy, isNull);
    });
  });

  group('CypherOrbProfile', () {
    test('JSON round-trip preserves identity and config', () {
      final profile = CypherOrbProfile(
        id: 'orb_1',
        name: 'Calm jelly',
        config: const CypherOrbConfig(deformation: 0.6, glow: 0.8),
        updatedAt: DateTime(2026, 1, 2, 3, 4, 5),
      );
      final decoded = CypherOrbProfile.fromJson(profile.toJson());
      expect(decoded.id, profile.id);
      expect(decoded.name, profile.name);
      expect(decoded.config, profile.config);
    });

    test('renamed and withConfig keep identity but refresh timestamp', () {
      final original = CypherOrbProfile(
        id: 'orb_1',
        name: 'A',
        config: const CypherOrbConfig(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final renamed = original.renamed('B');
      expect(renamed.id, 'orb_1');
      expect(renamed.name, 'B');
      expect(renamed.updatedAt.isAfter(original.updatedAt), isTrue);
    });
  });

  group('CypherOrbController', () {
    test('calls are safe no-ops when no orb is attached', () {
      final controller = CypherOrbController();
      expect(controller.isAttached, isFalse);
      expect(() {
        controller
          ..pulse()
          ..swipe(10, -5)
          ..press()
          ..beginTouch(0.2, 0.2)
          ..moveTouch(0.4, 0)
          ..endTouch()
          ..reset();
      }, returnsNormally);
      expect(controller.isAttached, isFalse);
    });
  });
}
