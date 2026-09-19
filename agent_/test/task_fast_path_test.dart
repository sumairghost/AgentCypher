import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/services/task_fast_path_router.dart';

void main() {
  group('TaskFastPathRouter - YouTube search', () {
    test('clear YouTube search phrase creates typed plan', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Open YouTube and search for cars');
      expect(route.matched, true);
      expect(route.routeName, 'youtube_search');
      expect(route.plan, isNotNull);
      expect(route.plan!.steps.length, 4);
      final typeStep = route.plan!.steps.firstWhere((s) => s.id == 'yt_type');
      expect(typeStep.params['text'], 'cars');
    });

    test('alternate YouTube phrasing extracts the query', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Search YouTube for MrBeast latest video');
      expect(route.matched, true);
      final typeStep = route.plan!.steps.firstWhere((s) => s.id == 'yt_type');
      expect(typeStep.params['text'], 'MrBeast latest video');
    });
  });

  group('TaskFastPathRouter - device state', () {
    test('set volume to 60 creates device_state plan', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Set volume to 60');
      expect(route.matched, true);
      expect(route.routeName, 'volume');
      expect(route.plan!.steps.first.action, 'set_volume');
      expect(route.plan!.steps.first.expectedValue, 60);
    });

    test('set brightness 70 creates device_state plan', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Set brightness to 70');
      expect(route.matched, true);
      expect(route.routeName, 'brightness');
      expect(route.plan!.steps.first.action, 'set_brightness');
      expect(route.plan!.steps.first.expectedValue, 70);
    });

    test('rejects out-of-range volume', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Set volume to 150');
      expect(route.matched, false);
    });
  });

  group('TaskFastPathRouter - rejects sensitive/unsupported', () {
    test('messaging intent rejected', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Open YouTube and search for cars, then send a message');
      expect(route.matched, false);
    });

    test('video seek rejected', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Open YouTube and search for cats, then seek to 2 minutes');
      expect(route.matched, false);
    });

    test('fullscreen rejected', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Set fullscreen mode for YouTube');
      expect(route.matched, false);
    });

    test('purchase rejected', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Buy a subscription on YouTube');
      expect(route.matched, false);
    });
  });

  group('TaskFastPathRouter - structured plan integrity', () {
    test('uses typed action contract only', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Open YouTube and search for cars');
      final actions = route.plan!.steps.map((s) => s.action).toSet();
      expect(
        {'open_app', 'click_text', 'type_text', 'press_enter'}
            .containsAll(actions),
        isTrue,
      );
    });

    test('dependency chain gates later steps', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Open YouTube and search for cars');
      final ytType = route.plan!.steps.firstWhere((s) => s.id == 'yt_type');
      expect(ytType.dependsOn.contains('yt_search'), true);
      final submit = route.plan!.steps.firstWhere((s) => s.id == 'yt_submit');
      expect(submit.dependsOn.contains('yt_type'), true);
    });

    test('no step requires confirmation by default for safe plan', () {
      final router = TaskFastPathRouter();
      final route = router.tryRoute('Open YouTube and search for cars');
      expect(route.plan!.steps.any((s) => s.requiresConfirmation), false);
    });
  });
}
