import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/services/verification_service.dart';

void main() {
  group('ScreenSnapshot verification', () {
    const readable = ScreenSnapshot(
      packageName: 'com.example.app',
      summary: 'SCREEN: Submit',
      fingerprint: 'before',
      readable: true,
    );
    const changed = ScreenSnapshot(
      packageName: 'com.example.app',
      summary: 'SCREEN: Results',
      fingerprint: 'after',
      readable: true,
    );
    const unreadable = ScreenSnapshot.unreadable;

    test('accepts a readable state transition', () {
      expect(VerificationService.hasChanged(readable, changed), isTrue);
    });

    test('rejects an unreadable before or after state', () {
      expect(VerificationService.hasChanged(unreadable, changed), isFalse);
      expect(VerificationService.hasChanged(readable, unreadable), isFalse);
    });

    test('rejects identical readable states', () {
      expect(VerificationService.hasChanged(readable, readable), isFalse);
    });
  });
}
