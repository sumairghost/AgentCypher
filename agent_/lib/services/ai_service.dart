import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_action.dart';
import 'provider/provider_manager.dart';
import 'provider/provider_configuration.dart';
import 'secure_credential_manager.dart';

class _PermanentAuthenticationException implements Exception {
  final String message;
  const _PermanentAuthenticationException(this.message);

  @override
  String toString() => message;
}

class AiResponse {
  final String content;
  final int totalTokens;
  AiResponse(this.content, this.totalTokens);
}

class AiService {
  static const String _defaultBaseUrl = 'https://api.deepseek.com';
  static const String _defaultModel = 'deepseek-chat';
  static const String nvidiaBaseUrl = 'https://integrate.api.nvidia.com/v1';
  static const String nvidiaDefaultModel = 'nvidia/nemotron-3-nano-30b-a3b';
  static const String _apiKeyStorageKey = 'api_key';

  /// Free, general-purpose chat endpoints verified in NVIDIA's NIM catalog.
  /// The live /models response is intersected with this list so unavailable or
  /// non-chat models never appear in Agent Cypher's NVIDIA model picker.
  static const List<String> nvidiaFreeChatModels = [
    'nvidia/nemotron-3-nano-30b-a3b',
    'nvidia/nemotron-3-super-120b-a12b',
    'nvidia/nemotron-3-ultra-550b-a55b',
    'nvidia/nvidia-nemotron-nano-9b-v2',
    'openai/gpt-oss-20b',
    'openai/gpt-oss-120b',
    'meta/llama-3.3-70b-instruct',
    'meta/llama-3.2-3b-instruct',
    'meta/llama-3.1-8b-instruct',
    'meta/llama-3.1-70b-instruct',
    'mistralai/mistral-nemotron',
    'deepseek-ai/deepseek-v4-flash',
    'deepseek-ai/deepseek-v4-pro',
  ];

  static bool isNvidiaBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    return uri?.host.toLowerCase() == 'integrate.api.nvidia.com';
  }

  static List<String> filterNvidiaFreeModels(Iterable<String> models) {
    final availableModels = models.toSet();
    return nvidiaFreeChatModels
        .where(availableModels.contains)
        .toList(growable: false);
  }

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _apiKey;
  String _baseUrl = _defaultBaseUrl;
  String _model = _defaultModel;
  int _maxSteps = 15;
  bool _disableMaxSteps = false;
  double _temperature = 1.0;
  int _maxTokens = 1024;
  bool _useScreenCompression = true;
  bool _useSystemPrompt = true;
  final List<Map<String, String>> _conversationHistory = [];
  final ProviderManager _providerManager = ProviderManager();

  String _normalizedApiKeyForRequest() {
    final key = _apiKey;
    if (key == null || key.trim().isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }
    return SecureCredentialManager.normalizeApiKey(key);
  }

  static Map<String, String> buildRequestHeaders({
    required String baseUrl,
    required String apiKey,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization':
          'Bearer ${SecureCredentialManager.normalizeApiKey(apiKey)}',
    };
    if (!isNvidiaBaseUrl(baseUrl)) {
      headers['HTTP-Referer'] = 'https://github.com/cypherghost/agent-cypher';
      headers['X-Title'] = 'Agent Cypher';
    }
    return headers;
  }

  Map<String, String> _requestHeaders() {
    return buildRequestHeaders(
      baseUrl: _baseUrl,
      apiKey: _normalizedApiKeyForRequest(),
    );
  }

  String _authenticationError(int statusCode) {
    if (isNvidiaBaseUrl(_baseUrl) && (statusCode == 401 || statusCode == 403)) {
      return 'NVIDIA authentication failed (HTTP $statusCode). Verify that the key is current and that its organization has access to NVIDIA public API endpoints.';
    }
    return 'API error ($statusCode).';
  }

  static const String _systemPrompt = '''
You are Agent Cypher, a helpful personal AI assistant for Sumair. You understand how to control Android devices, execute complex tasks, and provide intelligent assistance. You're calm, intelligent, and concise in your responses.

When the user wants to perform a device action, you MUST respond with ONLY a JSON object (no markdown, no code fences, no extra text) in this exact format:
{"action": "action_name", "params": {"key": "value"}, "response": "What you say to the user"}

Available actions and their params:

SIMPLE ACTIONS (single step only):
- open_app: {"app_name": "YouTube"} - ONLY use this when the user JUST wants to open an app and nothing else
- make_call: {"contact_name": "Mom"} OR {"phone_number": "1234567890"} - Makes a phone call
- send_sms: {"contact_name": "John", "message": "Hello"} OR {"phone_number": "123", "message": "Hi"} - Sends SMS
- search_contact: {"query": "John"} - Searches contacts
- set_alarm: {"hour": 7, "minute": 30, "label": "Wake up"} - Sets an alarm
- set_volume: {"level": 50} - Sets volume (0-100)
- set_brightness: {"level": 50} - Sets brightness (0-100)
- read_screen: {} - Read what's currently on the screen
- press_back: {} - Press the back button

MULTI-STEP TASK (for anything that requires more than one action):
- execute_task: {"goal": "description of the full task"} - Automatically reads screen, taps, scrolls, types step by step

CRITICAL RULES:
1. If the user request contains "and" or involves MULTIPLE steps (open + search, open + send, open + find, etc.), you MUST use execute_task. NEVER use open_app for these.
2. execute_task handles everything: opening apps, finding elements, clicking, typing, scrolling.

Examples of when to use execute_task:
- "Create a new alarm for 7 AM" → execute_task with goal "Create a new alarm for 7 AM"
- "Go to YouTube and search for cats" → execute_task
- "Open WhatsApp and send hello to John" → execute_task
- "Open Settings and turn on WiFi" → execute_task
- "Search for restaurants on Google Maps" → execute_task

Examples of when to use open_app:
- "Open YouTube" → open_app (just opening, no further action)
- "Open Settings" → open_app (just opening)

For normal conversation (questions, chat, info requests), just respond with plain text naturally.
''';

  static const String _chatSystemPrompt = '''
You are Agent Cypher, a personal AI assistant for Sumair. You're intelligent, concise, and respectful in all conversations. 
Provide direct, natural, and friendly text responses. You cannot perform device actions or run tools. 
Answer questions, explain concepts, brainstorm, write emails/messages, and chat with the user in plain text or markdown format.
''';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = await _secureStorage.read(key: _apiKeyStorageKey);
    if ((_apiKey == null || _apiKey!.isEmpty) &&
        prefs.containsKey(_apiKeyStorageKey)) {
      // One-time migration for installs created before secure storage was used.
      final legacyKey = prefs.getString(_apiKeyStorageKey);
      if (legacyKey != null && legacyKey.isNotEmpty) {
        final normalizedLegacyKey =
            SecureCredentialManager.normalizeApiKey(legacyKey);
        await _secureStorage.write(
          key: _apiKeyStorageKey,
          value: normalizedLegacyKey,
        );
        _apiKey = normalizedLegacyKey;
      }
      await prefs.remove(_apiKeyStorageKey);
    }
    _baseUrl = prefs.getString('api_base_url') ?? _defaultBaseUrl;
    _model = prefs.getString('api_model') ?? _defaultModel;
    if (isNvidiaBaseUrl(_baseUrl) && _model == 'z-ai/glm-5.2') {
      _model = nvidiaDefaultModel;
      await prefs.setString('api_model', _model);
    }
    _maxSteps = prefs.getInt('api_max_steps') ?? 15;
    _disableMaxSteps = prefs.getBool('api_disable_max_steps') ?? false;
    _temperature = prefs.getDouble('api_temperature') ?? 1.0;
    _maxTokens = prefs.getInt('api_max_tokens') ?? 1024;
    _useScreenCompression = prefs.getBool('api_use_screen_compression') ?? true;
    _useSystemPrompt = prefs.getBool('api_use_system_prompt') ?? true;
    await _providerManager.init();
  }

  Future<void> saveSettings({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Normalize a user-entered key before secure persistence.
    final trimmedApiKey = apiKey.trim();
    final cleanApiKey = trimmedApiKey.isEmpty
        ? ''
        : SecureCredentialManager.normalizeApiKey(trimmedApiKey);

    _apiKey = cleanApiKey;
    if (cleanApiKey.isEmpty) {
      await _secureStorage.delete(key: _apiKeyStorageKey);
    } else {
      await _secureStorage.write(key: _apiKeyStorageKey, value: cleanApiKey);
    }
    // Remove any legacy plaintext value left by older app versions.
    await prefs.remove(_apiKeyStorageKey);

    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl;
      await prefs.setString('api_base_url', baseUrl);
    }
    if (model != null && model.isNotEmpty) {
      _model = model;
      await prefs.setString('api_model', model);
    }

    // Keep the capability registry synchronized with the legacy single-provider
    // settings path. Existing users retain their declared capabilities.
    await _providerManager.init();
    final providerId = isNvidiaBaseUrl(_baseUrl) ? 'nvidia' : 'custom';
    final existing = _providerManager.getConfiguration(providerId);
    await _providerManager.addOrUpdateProviderConfiguration(
      configuration: ProviderConfiguration(
        id: providerId,
        name: isNvidiaBaseUrl(_baseUrl) ? 'NVIDIA' : 'Custom',
        baseUrl: _baseUrl,
        model: _model,
        capabilities: existing?.capabilities ?? const [
          ProviderCapabilities.chat,
          ProviderCapabilities.agentReasoning,
          ProviderCapabilities.coding,
          ProviderCapabilities.toolUse,
        ],
      ),
      apiKey: cleanApiKey,
    );
  }

  Future<void> saveMaxSteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    _maxSteps = steps;
    await prefs.setInt('api_max_steps', steps);
  }

  Future<void> saveDisableMaxSteps(bool disable) async {
    final prefs = await SharedPreferences.getInstance();
    _disableMaxSteps = disable;
    await prefs.setBool('api_disable_max_steps', disable);
  }

  Future<void> saveAdvancedSettings({
    required double temperature,
    required int maxTokens,
    required bool useScreenCompression,
    required bool useSystemPrompt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _temperature = temperature;
    _maxTokens = maxTokens;
    _useScreenCompression = useScreenCompression;
    _useSystemPrompt = useSystemPrompt;
    await prefs.setDouble('api_temperature', temperature);
    await prefs.setInt('api_max_tokens', maxTokens);
    await prefs.setBool('api_use_screen_compression', useScreenCompression);
    await prefs.setBool('api_use_system_prompt', useSystemPrompt);
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  String get baseUrl => _baseUrl;
  String get model => _model;
  String get apiKey => _apiKey ?? '';
  int get maxSteps => _disableMaxSteps ? 999 : _maxSteps;
  int get rawMaxSteps => _maxSteps; // For the slider UI
  bool get disableMaxSteps => _disableMaxSteps;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  bool get useScreenCompression => _useScreenCompression;
  bool get useSystemPrompt => _useSystemPrompt;

  /// True only when the active provider explicitly declares vision support.
  bool get supportsVision {
    final provider = _providerManager.getProviderForCapability(
      ProviderCapabilities.vision,
    );
    return provider?.supportsCapability(ProviderCapabilities.vision) ?? false;
  }

  int get _effectiveMaxTokens {
    // GLM is a reasoning model. With the app's 1,024-token default it can
    // consume the whole budget reasoning and finish without visible content.
    if (isNvidiaBaseUrl(_baseUrl) &&
        _model == nvidiaDefaultModel &&
        _maxTokens < 4096) {
      return 4096;
    }
    return _maxTokens;
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  bool isImageGenerationRequest(String message) {
    final text = message.toLowerCase();
    final asksToCreate = RegExp(r'\b(generate|create|draw|make|produce|render)\b').hasMatch(text);
    final namesImage = RegExp(r'\b(image|picture|illustration|artwork|photo)\b').hasMatch(text);
    return asksToCreate && namesImage;
  }

  Future<ImageGenerationResult> generateImage(String prompt) async {
    await _providerManager.init();
    final provider = _providerManager.getProviderForCapability(ProviderCapabilities.imageGeneration);
    if (provider == null) {
      throw Exception('Image generation is not configured. In Settings, select a model that supports image generation and enable that capability, or add a compatible fallback provider.');
    }
    return provider.generateImage(prompt);
  }

  void addHistoryMessage(String role, String content) {
    _conversationHistory.add({'role': role, 'content': content});
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }
  }

  /// Send a message to the AI and get a response.
  Future<String> sendMessage(String message, {bool isAgentMode = true}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    // Add ONLY the text to the persistent conversation history to save tokens.
    _conversationHistory.add({'role': 'user', 'content': message});

    // Keep conversation history manageable (last 20 messages)
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }

    try {
      // Build the prompt including system instructions
      final systemPrompt = isAgentMode ? _systemPrompt : _chatSystemPrompt;
      final messages = [
        if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory,
      ];

      String requestUrl = _baseUrl;
      if (requestUrl.endsWith('/chat/completions')) {
        requestUrl = requestUrl; // User already included it
      } else {
        if (requestUrl.endsWith('/')) {
          requestUrl = '${requestUrl}chat/completions';
        } else {
          requestUrl = '$requestUrl/chat/completions';
        }
      }

      final requestBody = jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': _effectiveMaxTokens,
      });

      developer.log(
        'API Request: ${Uri.parse(requestUrl).path} model=$_model',
        name: 'AiService',
      );

      final response = await http
          .post(
            Uri.parse(requestUrl),
            headers: _requestHeaders(),
            body: requestBody,
          )
          .timeout(const Duration(minutes: 30));

      developer.log(
        'API Response status=${response.statusCode} model=$_model',
        name: 'AiService',
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw _PermanentAuthenticationException(
            _authenticationError(response.statusCode),
          );
        }
        throw Exception('API error (${response.statusCode}).');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || !data.containsKey('choices')) {
        throw Exception('Unexpected API response format: $data');
      }

      String assistantMessage =
          data['choices'][0]['message']['content'] as String;

      // Strip <think> blocks commonly produced by reasoning models
      assistantMessage = assistantMessage
          .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
          .trim();

      if (assistantMessage.trim().isEmpty) {
        throw Exception(
          'API returned an empty response. This may be due to rate limits or API instability.',
        );
      }

      _conversationHistory.add({
        'role': 'assistant',
        'content': assistantMessage,
      });

      return assistantMessage;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Send a message and stream the response chunk-by-chunk.
  Stream<String> sendMessageStream(
    String message, {
    bool isAgentMode = true,
  }) async* {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    _conversationHistory.add({'role': 'user', 'content': message});

    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }

    try {
      final systemPrompt = isAgentMode ? _systemPrompt : _chatSystemPrompt;
      final messages = [
        if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory,
      ];

      String requestUrl = _baseUrl;
      if (requestUrl.endsWith('/chat/completions')) {
        requestUrl = requestUrl;
      } else {
        if (requestUrl.endsWith('/')) {
          requestUrl = '${requestUrl}chat/completions';
        } else {
          requestUrl = '$requestUrl/chat/completions';
        }
      }

      final client = http.Client();
      final accumulatedContent = StringBuffer();
      try {
        final request = http.Request('POST', Uri.parse(requestUrl));
        request.headers.addAll(_requestHeaders());

        request.body = jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': _temperature,
          'max_tokens': _effectiveMaxTokens,
          'stream': true,
        });

        final response = await client
            .send(request)
            .timeout(const Duration(minutes: 30));

        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw _PermanentAuthenticationException(
              _authenticationError(response.statusCode),
            );
          }
          throw Exception('API error (${response.statusCode}).');
        }

        bool inThinkBlock = false;

        // Listen to response stream
        final lineStream = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lineStream) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;
          if (trimmedLine.startsWith('data:')) {
            final dataStr = trimmedLine.substring(5).trim();
            if (dataStr == '[DONE]') break;
            try {
              final json = jsonDecode(dataStr);
              if (json is Map && json['choices'] is List) {
                final choices = json['choices'] as List;
                if (choices.isNotEmpty) {
                  final choice = choices[0];
                  if (choice is! Map) continue;
                  final rawDelta = choice['delta'];
                  final delta = rawDelta is Map ? rawDelta : const {};
                  final rawContent = delta['content'];
                  if (rawContent is String && rawContent.isNotEmpty) {
                    final content = rawContent;
                    accumulatedContent.write(content);

                    // Handle <think> block stripping on the fly for better stream styling
                    if (content.contains('<think>')) {
                      inThinkBlock = true;
                      // If there is text before <think>, yield it
                      final parts = content.split('<think>');
                      if (parts[0].isNotEmpty) {
                        yield parts[0];
                      }
                    } else if (content.contains('</think>')) {
                      inThinkBlock = false;
                      // If there is text after </think>, yield it
                      final parts = content.split('</think>');
                      if (parts.length > 1 && parts[1].isNotEmpty) {
                        yield parts[1];
                      }
                    } else if (!inThinkBlock) {
                      yield content;
                    }
                  }
                  if (choice['finish_reason'] != null) break;
                }
              }
            } catch (_) {
              // Ignore incomplete chunks
            }
          }
        }
      } finally {
        // Always release the underlying socket — including when the caller
        // cancels the subscription ("stop generation") mid-stream.
        client.close();
      }

      // Clean up final accumulated response and add to history
      String finalResponse = accumulatedContent.toString().trim();
      finalResponse = finalResponse
          .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
          .trim();

      if (finalResponse.isEmpty) {
        throw Exception(
          'The model finished without a visible answer. Increase Max Tokens '
          'or try another NVIDIA model.',
        );
      }
      _conversationHistory.add({'role': 'assistant', 'content': finalResponse});
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Send a task execution message — no conversation history, low temperature, limited tokens.
  /// This is much faster and cheaper than sendMessage.
  ///
  /// Task JSON must be deterministic, so this path pins temperature low
  /// regardless of the chat-facing setting unless explicitly overridden.
  Future<AiResponse> sendTaskMessage(
    String systemPrompt,
    String prompt, {
    String? imageBase64,
    double? temperature,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    int maxRetries = 2;
    int currentTry = 0;

    while (true) {
      try {
        currentTry++;
        final userContent = imageBase64 == null
            ? prompt
            : [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/png;base64,$imageBase64',
                  },
                },
              ];
        final messages = [
          if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ];

        String requestUrl = _baseUrl;
        if (!requestUrl.endsWith('/chat/completions')) {
          if (requestUrl.endsWith('/')) {
            requestUrl = '${requestUrl}chat/completions';
          } else {
            requestUrl = '$requestUrl/chat/completions';
          }
        }

        final response = await http
            .post(
              Uri.parse(requestUrl),
              headers: _requestHeaders(),
              body: jsonEncode({
                'model': _model,
                'messages': messages,
                'temperature': temperature ?? 0.2,
                'max_tokens': _effectiveMaxTokens,
              }),
            )
            .timeout(const Duration(minutes: 30));

        if (response.statusCode != 200) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw _PermanentAuthenticationException(
              _authenticationError(response.statusCode),
            );
          }
          throw Exception('API error (${response.statusCode}).');
        }

        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic> || !data.containsKey('choices')) {
          throw Exception('Unexpected API response format: $data');
        }
        String content = data['choices'][0]['message']['content'] as String;

        // Strip <think> blocks commonly produced by reasoning models
        content = content
            .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
            .trim();

        if (content.trim().isEmpty) {
          throw Exception(
            'API returned an empty response. This may be due to strict rate limits or safety filters.',
          );
        }

        int tokens = 0;
        if (data.containsKey('usage') &&
            data['usage']['total_tokens'] != null) {
          tokens = data['usage']['total_tokens'] as int;
        }
        return AiResponse(content, tokens);
      } catch (e) {
        if (e is _PermanentAuthenticationException) rethrow;
        if (currentTry > maxRetries) {
          if (e is Exception) rethrow;
          throw Exception('Network error after $maxRetries retries: $e');
        }
        int delaySeconds = 1 * currentTry;
        developer.log(
          'API call failed ($e), retrying $currentTry/$maxRetries in $delaySeconds seconds...',
          name: 'PrivateAgent',
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// Parse the AI response to check if it's an action or plain text
  AgentAction? parseAction(String response) {
    // Try to parse as JSON action
    try {
      final trimmed = response.trim();
      // Handle if the response is wrapped in code fences
      String jsonStr = trimmed;
      if (trimmed.startsWith('```')) {
        final lines = trimmed.split('\n');
        lines.removeAt(0); // Remove opening fence
        if (lines.isNotEmpty && lines.last.trim() == '```') {
          lines.removeLast(); // Remove closing fence
        }
        jsonStr = lines.join('\n').trim();
      }

      // If it looks like JSON but is missing a closing brace (common with some local models)
      if (jsonStr.startsWith('{') && !jsonStr.endsWith('}')) {
        jsonStr += '\n}';
      }

      if (jsonStr.startsWith('{') && jsonStr.contains('"action"')) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (json.containsKey('action')) {
            return AgentAction.fromJson(json);
          }
        } catch (e) {
          // If it still fails, it might be deeply truncated, try adding another brace
          if (e.toString().contains('Unexpected end of input')) {
            jsonStr += '\n}';
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (json.containsKey('action')) {
              return AgentAction.fromJson(json);
            }
          }
        }
      }
    } catch (_) {
      // Not JSON, it's plain text conversation
    }
    return null;
  }

  /// Fetches available models from the provider's /models endpoint
  Future<List<String>> fetchAvailableModels(
    String baseUrl,
    String apiKey,
  ) async {
    try {
      String cleanBaseUrl = baseUrl;
      // Many providers host it at /models, but some require the base URL without /chat/completions logic
      if (cleanBaseUrl.endsWith('/chat/completions')) {
        cleanBaseUrl = cleanBaseUrl.replaceAll('/chat/completions', '');
      }

      final normalizedApiKey = SecureCredentialManager.normalizeApiKey(apiKey);
      final response = await http.get(
        Uri.parse('$cleanBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $normalizedApiKey',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<String> models;
        if (data is Map && data.containsKey('data')) {
          final modelsList = data['data'] as List;
          models = modelsList.map((m) => m['id'].toString()).toList();
        } else if (data is List) {
          models = data.map((m) => m['id'].toString()).toList();
        } else {
          return [];
        }

        if (isNvidiaBaseUrl(cleanBaseUrl)) {
          return filterNvidiaFreeModels(models);
        }
        models.sort();
        return models;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
