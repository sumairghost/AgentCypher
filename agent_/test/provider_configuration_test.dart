import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/services/provider/provider_configuration.dart';

void main() {
  test('provider configuration round-trips capabilities', () {
    const original = ProviderConfiguration(
      id: 'images',
      name: 'Images',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-image-1',
      capabilities: [ProviderCapabilities.imageGeneration, ProviderCapabilities.vision],
    );

    final restored = ProviderConfiguration.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.baseUrl, original.baseUrl);
    expect(restored.model, original.model);
    expect(restored.supports(ProviderCapabilities.imageGeneration), isTrue);
    expect(restored.supports(ProviderCapabilities.chat), isFalse);
  });
}
