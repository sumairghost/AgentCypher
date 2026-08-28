library;

/// Centralized overlay assistant phase derived from real events.
/// Never faked; transitions are centralized and testable.
enum AssistantOverlayPhase {
  idle,
  expanded,
  listening,
  thinking,
  executing,
  success,
  error,
  awaitingApproval, // honest hand-off to main app
}
