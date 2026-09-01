import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/services/developer_config_service.dart';

void main() {
  group('DeveloperTapActivator — seven-tap developer mode', () {
    test('activates on the seventh rapid tap', () {
      final activator = DeveloperTapActivator();
      var t = DateTime(2026, 1, 1, 12, 0, 0);
      for (var i = 1; i < DeveloperTapActivator.requiredTaps; i++) {
        final progress = activator.registerTap(t);
        expect(progress.activated, isFalse, reason: 'tap $i');
        expect(progress.rejected, isFalse);
        t = t.add(const Duration(milliseconds: 200));
      }
      final finalTap = activator.registerTap(t);
      expect(finalTap.activated, isTrue);
      expect(finalTap.count, DeveloperTapActivator.requiredTaps);
    });

    test('inactivity gap longer than maxTapGap resets the counter', () {
      final activator = DeveloperTapActivator();
      var t = DateTime(2026, 1, 1, 12, 0, 0);
      // Six rapid taps.
      for (var i = 0; i < 6; i++) {
        activator.registerTap(t);
        t = t.add(const Duration(milliseconds: 200));
      }
      expect(activator.count, 6);
      // A gap beyond the timeout starts a fresh sequence.
      t = t.add(DeveloperTapActivator.maxTapGap + const Duration(seconds: 1));
      final progress = activator.registerTap(t);
      expect(progress.activated, isFalse);
      expect(activator.count, 1);
    });

    test('taps faster than minTapGap are debounced (rejected)', () {
      final activator = DeveloperTapActivator();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      activator.registerTap(t0);
      final debounced = activator.registerTap(
        t0.add(const Duration(milliseconds: 10)),
      );
      expect(debounced.rejected, isTrue);
      expect(debounced.activated, isFalse);
      expect(activator.count, 1);
    });

    test('remaining and feedback thresholds behave like Android', () {
      final activator = DeveloperTapActivator();
      var t = DateTime(2026, 1, 1, 12, 0, 0);
      expect(activator.remaining, DeveloperTapActivator.requiredTaps);
      for (var i = 1; i <= 2; i++) {
        activator.registerTap(t);
        t = t.add(const Duration(milliseconds: 200));
        expect(activator.shouldGiveFeedback, isFalse,
            reason: 'no hints before the 3rd tap');
      }
      for (var i = 3; i < DeveloperTapActivator.requiredTaps; i++) {
        activator.registerTap(t);
        t = t.add(const Duration(milliseconds: 200));
        expect(activator.shouldGiveFeedback, isTrue, reason: 'tap $i');
        expect(
          activator.remaining,
          DeveloperTapActivator.requiredTaps - i,
        );
      }
      activator.reset();
      expect(activator.count, 0);
      expect(activator.remaining, DeveloperTapActivator.requiredTaps);
    });

    test('counter cannot accidentally activate from slow sparse taps', () {
      final activator = DeveloperTapActivator();
      var t = DateTime(2026, 1, 1, 12, 0, 0);
      for (var i = 0; i < 20; i++) {
        activator.registerTap(t);
        // Each tap is outside the max gap, so every sequence resets.
        t = t.add(DeveloperTapActivator.maxTapGap * 2);
        expect(activator.activatedForTest, isFalse);
      }
    });
  });
}

extension on DeveloperTapActivator {
  bool get activatedForTest =>
      count >= DeveloperTapActivator.requiredTaps;
}
