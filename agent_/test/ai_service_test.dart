import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/services/ai_service.dart';
import 'package:agent_cypher/services/recovery_engine.dart';
import 'package:agent_cypher/services/screen_automation_service.dart';
import 'package:agent_cypher/services/secure_credential_manager.dart';

void main() {
  test('recognizes only the NVIDIA hosted API URL', () {
    expect(
      AiService.isNvidiaBaseUrl('https://integrate.api.nvidia.com/v1'),
      isTrue,
    );
    expect(AiService.isNvidiaBaseUrl('https://api.deepseek.com'), isFalse);
  });

  test('NVIDIA model picker keeps only verified free chat models', () {
    final models = AiService.filterNvidiaFreeModels([
      'paid/partner-model',
      'nvidia/nemotron-3-super-120b-a12b',
      'nvidia/embed-qa-4',
      'openai/gpt-oss-20b',
    ]);

    expect(models, ['nvidia/nemotron-3-super-120b-a12b', 'openai/gpt-oss-20b']);
  });

  test('Nemotron is the default NVIDIA model', () {
    expect(
      AiService.nvidiaDefaultModel,
      'nvidia/nemotron-3-nano-30b-a3b',
    );
    expect(
      AiService.nvidiaFreeChatModels.first,
      'nvidia/nemotron-3-nano-30b-a3b',
    );
  });

  test('normalizes bearer tokens without exposing or changing their value', () {
    expect(
      SecureCredentialManager.normalizeApiKey('  Bearer test-token  '),
      'test-token',
    );
    expect(
      SecureCredentialManager.normalizeApiKey('"test-token"'),
      'test-token',
    );
    expect(
      () => SecureCredentialManager.normalizeApiKey('test\n-token'),
      throwsArgumentError,
    );
  });

  test('NVIDIA headers use bearer auth and omit unrelated referral headers', () {
    final headers = AiService.buildRequestHeaders(
      baseUrl: AiService.nvidiaBaseUrl,
      apiKey: 'Bearer test-token',
    );

    expect(headers['Authorization'], 'Bearer test-token');
    expect(headers['Content-Type'], 'application/json');
    expect(headers['Accept'], 'application/json');
    expect(headers.containsKey('HTTP-Referer'), isFalse);
    expect(headers.containsKey('X-Title'), isFalse);
  });

  test('non-NVIDIA headers preserve existing compatibility metadata', () {
    final headers = AiService.buildRequestHeaders(
      baseUrl: 'https://example.test/v1',
      apiKey: 'test-token',
    );

    expect(headers['HTTP-Referer'], contains('cypherghost'));
    expect(headers['X-Title'], 'Agent Cypher');
  });

  test('compact screen state keeps browser fields readable', () {
    final screenState = ScreenAutomationService.formatCompactScreenState(
      nodes: [
        {
          'index': 0,
          'text': 'Search or type web address',
          'contentDescription': '',
          'className': 'android.widget.EditText',
          'isClickable': false,
          'isEditable': true,
          'isScrollable': false,
          'isChecked': false,
          'isEnabled': true,
          'bounds': {'left': 50, 'top': 200, 'right': 700, 'bottom': 280},
        },
      ],
      packageName: 'com.android.chrome',
      task: 'open Chrome and search for Python 3.14',
    );

    expect(screenState, contains('SCREEN:'));
    expect(screenState, contains('package=com.android.chrome'));
    expect(screenState, contains('text="Search or type web address"'));
    expect(screenState, contains('type=EditText'));
  });

  test('recovery engine recommends human intervention for CAPTCHA blocks', () async {
    final engine = RecoveryEngine();
    final actions = await engine.diagnoseWithAlternatives(
      'click_text',
      'Verify you are human before continuing',
      lastAttemptedValue: 'Google',
    );

    expect(actions, isNotEmpty);
    expect(actions.first.action, 'wait_for_user');
  });
}
