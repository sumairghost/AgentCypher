import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';
import 'provider_configuration.dart';
import '../secure_credential_manager.dart';

/// Generic OpenAI-compatible provider.
class OpenAICompatibleProvider implements AIProvider {
  @override
  final String name;
  @override
  final String baseUrl;
  @override
  final String apiKey;
  @override
  String model;
  final List<String> declaredCapabilities;

  OpenAICompatibleProvider({
    required this.name,
    required this.baseUrl,
    required String apiKey,
    required this.model,
    this.declaredCapabilities = const [],
  }) : apiKey = SecureCredentialManager.normalizeApiKey(apiKey);

  String _endpoint(String path) {
    var root = baseUrl.trim();
    if (root.endsWith('/')) root = root.substring(0, root.length - 1);
    if (root.endsWith('/chat/completions')) root = root.substring(0, root.length - '/chat/completions'.length);
    if (root.endsWith('/images/generations')) root = root.substring(0, root.length - '/images/generations'.length);
    return '$root/$path';
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Agent-Cypher/1.0',
      };

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http.post(Uri.parse(_endpoint('chat/completions')), headers: _headers, body: jsonEncode({
        'model': model,
        'messages': [{'role': 'user', 'content': 'test'}],
        'max_tokens': 5,
        'stream': false,
      })).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> sendMessage(String message, {bool isAgentMode = false}) async {
    final response = await http.post(Uri.parse(_endpoint('chat/completions')), headers: _headers, body: jsonEncode({
      'model': model,
      'messages': [{'role': 'user', 'content': message}],
      'max_tokens': 2048,
      'temperature': 0.7,
      'stream': false,
    })).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) throw Exception(_apiError(response));
    final data = jsonDecode(response.body);
    final choices = data is Map ? data['choices'] : null;
    if (choices is! List || choices.isEmpty || choices.first is! Map) throw Exception('Unexpected chat response format.');
    final content = (choices.first['message'] as Map?)?['content'];
    if (content is! String || content.trim().isEmpty) throw Exception('The provider returned an empty response.');
    return content;
  }

  @override
  Future<Stream<String>> streamMessage(String message, {bool isAgentMode = false}) async => Stream.fromFuture(_streamMessageImpl(message));

  Future<String> _streamMessageImpl(String message) async {
    final request = http.Request('POST', Uri.parse(_endpoint('chat/completions')));
    request.headers.addAll(_headers);
    request.body = jsonEncode({'model': model, 'messages': [{'role': 'user', 'content': message}], 'max_tokens': 2048, 'temperature': 0.7, 'stream': true});
    final response = await request.send().timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          baseUrl.toLowerCase().contains('nvidia.com')) {
        throw Exception(_apiError(http.Response('', response.statusCode)));
      }
      throw Exception('API error (${response.statusCode}).');
    }
    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') continue;
        try {
          final data = jsonDecode(payload);
          final delta = data['choices'][0]['delta']['content'];
          if (delta is String) buffer.write(delta);
        } catch (_) {}
      }
    }
    final result = buffer.toString().trim();
    if (result.isEmpty) throw Exception('The provider returned an empty streamed response.');
    return result;
  }

  @override
  Future<ImageGenerationResult> generateImage(String prompt, {String? size}) async {
    if (!supportsCapability(ProviderCapabilities.imageGeneration)) {
      throw Exception('The selected model is not configured for image generation.');
    }
    final response = await http.post(Uri.parse(_endpoint('images/generations')), headers: _headers, body: jsonEncode({
      'model': model,
      'prompt': prompt,
      'n': 1,
      'size': size ?? '1024x1024',
      'response_format': 'url',
    })).timeout(const Duration(minutes: 2));
    if (response.statusCode != 200) throw Exception(_apiError(response));
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List || data.isEmpty || data.first is! Map) throw Exception('Unexpected image response format.');
    final item = data.first as Map;
    final url = item['url'];
    if (url is String && url.isNotEmpty) return ImageGenerationResult(imageUrl: url, revisedPrompt: item['revised_prompt']?.toString());
    final base64 = item['b64_json'];
    if (base64 is String && base64.isNotEmpty) return ImageGenerationResult(imageUrl: 'data:image/png;base64,$base64', revisedPrompt: item['revised_prompt']?.toString());
    throw Exception('Image response did not contain a URL or image data.');
  }

  String _apiError(http.Response response) {
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        baseUrl.toLowerCase().contains('nvidia.com')) {
      return 'NVIDIA authentication failed (HTTP ${response.statusCode}). Verify that the key is current and that its organization has access to NVIDIA public API endpoints.';
    }
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map ? decoded['error'] : null;
      if (error is Map && error['message'] != null) return 'API error (${response.statusCode}): ${error['message']}';
      if (error is String) return 'API error (${response.statusCode}): $error';
    } catch (_) {}
    return 'API error (${response.statusCode}).';
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final response = await http
          .get(Uri.parse(_endpoint('models')), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is Map && data['data'] is List) return (data['data'] as List).map((item) => item is Map ? item['id'].toString() : item.toString()).toList();
    } catch (_) {}
    return [];
  }

  @override
  bool supportsCapability(String capability) => declaredCapabilities.contains(capability);
  @override
  bool supportsVision() => supportsCapability(ProviderCapabilities.vision);
  @override
  bool supportsTools() => supportsCapability(ProviderCapabilities.toolUse);
  @override
  bool supportsStructuredOutput() => supportsCapability(ProviderCapabilities.coding);

  @override
  Future<Map<String, dynamic>> validateConfiguration() async {
    final connected = await testConnection();
    return {'valid': connected, 'provider': name, 'model': model, 'baseUrl': baseUrl, 'capabilities': declaredCapabilities, 'error': connected ? null : 'Connection failed'};
  }
}
