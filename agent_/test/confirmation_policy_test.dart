import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/services/confirmation_policy.dart';

void main() {
  group('ConfirmationPolicy.requiresFreshConfirmation', () {
    test('post/share/send require fresh confirmation', () {
      expect(
        ConfirmationPolicy.requiresFreshConfirmation(
          action: 'press_enter',
          intent: 'Final share / post',
        ),
        true,
      );
      expect(
        ConfirmationPolicy.requiresFreshConfirmation(
          action: 'press_enter',
          intent: 'Send message',
        ),
        true,
      );
    });

    test('safe action does not require fresh confirmation', () {
      expect(
        ConfirmationPolicy.requiresFreshConfirmation(
          action: 'click_text',
          intent: 'Open YouTube',
        ),
        false,
      );
    });
  });

  group('ConfirmationPolicy.invalidateIfStale', () {
    final base = DateTime(2026, 1, 1, 12, 0, 0);

    test('user cancelled invalidates immediately', () {
      final reason = ConfirmationPolicy.invalidateIfStale(
        approvedAt: base,
        now: base,
        currentScreenFingerprint: 'a',
        approvedScreenFingerprint: 'a',
        currentAccountContext: 'me',
        approvedAccountContext: 'me',
        contentEdited: false,
        userCancelled: true,
      );
      expect(reason, ConfirmationInvalidationReason.userCancelled);
    });

    test('content edited invalidates', () {
      final reason = ConfirmationPolicy.invalidateIfStale(
        approvedAt: base,
        now: base,
        currentScreenFingerprint: 'a',
        approvedScreenFingerprint: 'a',
        currentAccountContext: 'me',
        approvedAccountContext: 'me',
        contentEdited: true,
        userCancelled: false,
      );
      expect(reason, ConfirmationInvalidationReason.contentEdited);
    });

    test('screen changed invalidates', () {
      final reason = ConfirmationPolicy.invalidateIfStale(
        approvedAt: base,
        now: base,
        currentScreenFingerprint: 'b',
        approvedScreenFingerprint: 'a',
        currentAccountContext: 'me',
        approvedAccountContext: 'me',
        contentEdited: false,
        userCancelled: false,
      );
      expect(reason, ConfirmationInvalidationReason.screenChanged);
    });

    test('age over confirmationMaxAge invalidates', () {
      final reason = ConfirmationPolicy.invalidateIfStale(
        approvedAt: base,
        now: base.add(const Duration(seconds: 61)),
        currentScreenFingerprint: 'a',
        approvedScreenFingerprint: 'a',
        currentAccountContext: 'me',
        approvedAccountContext: 'me',
        contentEdited: false,
        userCancelled: false,
      );
      expect(reason, ConfirmationInvalidationReason.approvalExpired);
    });

    test('identical state within window returns null', () {
      final reason = ConfirmationPolicy.invalidateIfStale(
        approvedAt: base,
        now: base.add(const Duration(seconds: 5)),
        currentScreenFingerprint: 'a',
        approvedScreenFingerprint: 'a',
        currentAccountContext: 'me',
        approvedAccountContext: 'me',
        contentEdited: false,
        userCancelled: false,
      );
      expect(reason, isNull);
    });
  });

  test('confirmationMaxAge is 60s', () {
    expect(ConfirmationPolicy.confirmationMaxAge, const Duration(seconds: 60));
  });

  test('buildFinalPrompt includes media, caption, account', () {
    final prompt = ConfirmationPolicy.buildFinalPrompt(
      action: 'press_enter',
      targetApp: 'Instagram',
      mediaLabel: 'photo.jpg',
      caption: 'Hey Japan.',
      observedAccount: 'me',
    );
    expect(prompt.contains('Instagram'), true);
    expect(prompt.contains('photo.jpg'), true);
    expect(prompt.contains('Hey Japan.'), true);
    expect(prompt.contains('me'), true);
  });
}
