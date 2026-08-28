import 'provider_configuration.dart';

/// Abstract base class for AI providers.
abstract class AIProvider {
  String get name;
  String get baseUrl;
  String get apiKey;
  String get model;

  Future<bool> testConnection();
  Future<String> sendMessage(String message, {bool isAgentMode = false});
  Future<Stream<String>> streamMessage(String message, {bool isAgentMode = false});
  Future<List<String>> fetchAvailableModels();
  Future<ImageGenerationResult> generateImage(String prompt, {String? size});
  bool supportsCapability(String capability);
  bool supportsVision();
  bool supportsTools();
  bool supportsStructuredOutput();
  Future<Map<String, dynamic>> validateConfiguration();
}
