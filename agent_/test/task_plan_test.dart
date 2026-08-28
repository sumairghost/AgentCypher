import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/task_plan.dart';

void main() {
  Map<String, dynamic> validStep({
    String id = 's1',
    String action = 'press_home',
    Map<String, dynamic>? params,
    List<String> dependsOn = const [],
    String verificationMethod = 'screen_changed',
    String expectedResult = '',
  }) {
    return {
      'id': id,
      'intent': 'step $id',
      'action': action,
      if (params != null) 'params': params,
      'verification_method': verificationMethod,
      if (expectedResult.isNotEmpty) 'expected_result': expectedResult,
      'depends_on': dependsOn,
    };
  }

  group('TaskPlan.parse — strict validation', () {
    test('accepts a well-formed plan', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(id: 's1', action: 'open_app', params: {'app_name': 'YouTube'},
                verificationMethod: 'app_foreground'),
            validStep(
              id: 's2',
              action: 'click_text',
              params: {'text': 'Search'},
              dependsOn: ['s1'],
            ),
          ],
        },
        rootGoal: 'test goal',
      );
      expect(result.isValid, isTrue);
      expect(result.plan!.steps, hasLength(2));
    });

    test('rejects unsupported actions', () {
      final result = TaskPlan.parse(
        {'steps': [validStep(action: 'seek_video')]},
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('unsupported action'));
    });

    test('rejects duplicate ids', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(id: 's1'),
            validStep(id: 's1'),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('duplicate id'));
    });

    test('rejects out-of-bounds click_at coordinates and missing reason', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(
              action: 'click_at',
              params: {'x': 9999, 'y': -5},
            ),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      final joined = result.issues.join(' ');
      expect(joined, contains('out of bounds'));
      expect(joined, contains('target_reason'));
    });

    test('rejects volume level outside 0-100', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(
              action: 'set_volume',
              params: {'level': 150},
              verificationMethod: 'device_state',
            ),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('0-100'));
    });

    test('rejects unknown verification methods', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(verificationMethod: 'telepathy'),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('unknown verification_method'));
    });

    test('device_state only applies to volume/brightness', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(verificationMethod: 'device_state'),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('device_state'));
    });

    test('content_visible requires expected_result', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(verificationMethod: 'content_visible'),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('expected_result'));
    });
  });

  group('TaskPlan dependencies', () {
    test('rejects unknown dependency references', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(id: 's1', dependsOn: ['ghost']),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('unknown step'));
    });

    test('rejects self-dependency', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(id: 's1', dependsOn: ['s1']),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('depend on itself'));
    });

    test('rejects dependency cycles', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(id: 's1', dependsOn: ['s2']),
            validStep(id: 's2', dependsOn: ['s1']),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isFalse);
      expect(result.issues.join(' '), contains('cycle'));
    });

    test('orderedSteps places dependencies before dependents', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            // Deliberately out of order in the raw list.
            validStep(id: 's3', action: 'press_enter', dependsOn: ['s2', 's1']),
            validStep(id: 's2', action: 'type_text', params: {'text': 'hi'},
                dependsOn: ['s1']),
            validStep(id: 's1', action: 'click_text', params: {'text': 'Search'}),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isTrue);
      final order = result.plan!.orderedSteps.map((s) => s.id).toList();
      expect(order.indexOf('s1'), lessThan(order.indexOf('s2')));
      expect(order.indexOf('s2'), lessThan(order.indexOf('s3')));
    });
  });

  group('Sensitive action confirmation', () {
    test('flags send/post/purchase text even when planner says no', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(
              id: 's1',
              action: 'click_text',
              params: {'text': 'Send message'},
              verificationMethod: 'content_visible',
              expectedResult: 'message sent',
            ),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isTrue);
      expect(result.plan!.needsConfirmation, isTrue);
      expect(result.plan!.steps.first.requiresConfirmation, isTrue);
    });

    test('ordinary navigation steps do not require confirmation', () {
      final result = TaskPlan.parse(
        {
          'steps': [
            validStep(),
          ],
        },
        rootGoal: 'g',
      );
      expect(result.isValid, isTrue);
      expect(result.plan!.needsConfirmation, isFalse);
    });
  });
}
