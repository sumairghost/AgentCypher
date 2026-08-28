import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/capability_registry.dart';

void main() {
  group('CapabilityRegistry', () {
    test('instagramCreatePost is irreversibleExternal with fresh confirmation', () {
      final c = CapabilityRegistry.instagramCreatePost;
      expect(c.id, 'instagram.create_post');
      expect(c.safety, SafetyClass.irreversibleExternal);
      expect(c.requiresFreshConfirmation, true);
      expect(c.apps, contains('Instagram'));
    });

    test('youtubeSearch is reversible without fresh confirmation', () {
      final c = CapabilityRegistry.youtubeSearch;
      expect(c.safety, SafetyClass.reversible);
      expect(c.requiresFreshConfirmation, false);
    });

    test('isExternalPublishingIntent detects post + instagram', () {
      expect(CapabilityRegistry.isExternalPublishingIntent('Post my photo to Instagram'), true);
    });

    test('isExternalPublishingIntent rejects unrelated', () {
      expect(CapabilityRegistry.isExternalPublishingIntent('Open YouTube'), false);
    });

    test('byId returns null for unknown', () {
      expect(CapabilityRegistry.byId('unknown'), isNull);
    });
  });
}
