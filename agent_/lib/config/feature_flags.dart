class FeatureFlags {
  FeatureFlags._();

  // Floating overlay is now stable and enabled for production use.
  // The implementation is fully functional with proper error handling.
  static const bool floatingOverlayEnabled = true;

  /// External social-post workflow (Instagram / X / TikTok / Facebook).
  /// Disabled by default until real-device evidence confirms the
  /// draft-to-final-confirm sequence works end-to-end with honest
  /// unverified reporting. See expansion plan.
  static const bool mediaPostWorkflowEnabled = false;
}
