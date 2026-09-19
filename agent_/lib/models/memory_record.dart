/// One retrievable unit of persistent user memory (Phase 13).
///
/// Records are derived views over the existing `UserMemoryService` store —
/// there is no second database. [id] is stable and encodes the category so
/// deletion can target exactly one entry.
class MemoryRecord {
  /// Category tag: `fact`, `instruction`, `preference`, or `device`.
  final String category;

  /// Stable id, e.g. `fact:My favourite food is pizza`.
  final String id;

  /// The remembered text (or `key: value` for preferences).
  final String value;

  /// Why this record is being surfaced, so the UI never has to guess.
  final String reason;

  final DateTime timestamp;

  const MemoryRecord({
    required this.category,
    required this.id,
    required this.value,
    required this.reason,
    required this.timestamp,
  });
}