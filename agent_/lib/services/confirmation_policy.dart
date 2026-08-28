library;

/// What invalidates a previously granted approval. Cached approvals are
/// never reused for irreversible or sensitive actions.
enum ConfirmationInvalidationReason {
  screenChanged,
  accountContextChanged,
  contentEdited,
  approvalExpired,
  userCancelled,
  appContextMismatch,
}

/// Single source of truth for "does this action need a fresh user tap?"
///
/// Confirmation is never cached across boundaries. Each irreversible or
/// sensitive action rebuilds a confirmation request that includes the
/// currently-observed media, caption, account, and target app.
class ConfirmationPolicy {
  /// True when the action label is one of the irreversible / sensitive
  /// categories. Used by the planner and the executor to gate execution.
  static bool requiresFreshConfirmation({
    required String action,
    Map<String, dynamic> params = const {},
    String? intent,
  }) {
    final haystack = '${(intent ?? '').toLowerCase()} '
        '${(params['text'] ?? '').toString().toLowerCase()} '
        '${(params['target_description'] ?? '').toString().toLowerCase()} '
        '${(params['app_name'] ?? '').toString().toLowerCase()}';
    const sensitivePhrases = [
      'post',
      'publish',
      'share',
      'tweet',
      'send',
      'message',
      'pay',
      'purchase',
      'buy',
      'subscribe',
      'install',
      'uninstall',
      'delete',
      'remove',
      'logout',
      'sign out',
      'switch account',
      'transfer',
    ];
    if (sensitivePhrases.any(haystack.contains)) return true;
    if (action == 'press_enter' && _looksLikeFinalSubmit(intent)) return true;
    return false;
  }

  static bool _looksLikeFinalSubmit(String? intent) {
    if (intent == null) return false;
    final lower = intent.toLowerCase();
    return lower.contains('post') ||
        lower.contains('share') ||
        lower.contains('submit') ||
        lower.contains('send') ||
        lower.contains('publish');
  }

  /// Maximum age of a confirmation before it must be re-asked. Sixty
  /// seconds is a conservative bound; an external action never reuses
  /// an approval older than this even if the screen didn't change.
  static const Duration confirmationMaxAge = Duration(seconds: 60);

  /// Returns the reason a prior approval is now invalid, or null when the
  /// approval is still valid. Pure function — no I/O, no clock side effects
  /// other than the passed-in timestamp.
  static ConfirmationInvalidationReason? invalidateIfStale({
    required DateTime approvedAt,
    required DateTime now,
    required String currentScreenFingerprint,
    required String approvedScreenFingerprint,
    required String currentAccountContext,
    required String approvedAccountContext,
    required bool contentEdited,
    required bool userCancelled,
  }) {
    if (userCancelled) return ConfirmationInvalidationReason.userCancelled;
    if (contentEdited) return ConfirmationInvalidationReason.contentEdited;
    if (currentScreenFingerprint != approvedScreenFingerprint) {
      return ConfirmationInvalidationReason.screenChanged;
    }
    if (currentAccountContext != approvedAccountContext) {
      return ConfirmationInvalidationReason.accountContextChanged;
    }
    if (now.difference(approvedAt) > confirmationMaxAge) {
      return ConfirmationInvalidationReason.approvalExpired;
    }
    return null;
  }

  /// Human-readable label for a confirmation prompt. Always includes the
  /// current media reference, caption, target app, and observed account
  /// so the user can spot drift before tapping the final action.
  static String buildFinalPrompt({
    required String action,
    required String targetApp,
    required String? mediaLabel,
    required String? caption,
    required String? observedAccount,
  }) {
    final buffer = StringBuffer()
      ..writeln('Final action: $action')
      ..writeln('Target: $targetApp')
      ..writeln('Media: ${mediaLabel ?? "(none selected)"}')
      ..writeln('Caption: ${caption ?? "(empty)"}')
      ..writeln('Account: ${observedAccount ?? "(unknown)"}');
    return buffer.toString().trimRight();
  }
}
