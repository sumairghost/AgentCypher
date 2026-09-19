import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/memory_record.dart';

/// Persistent memory for user preferences, facts, and instructions
/// Per spec section 17: Support remembering user preferences and facts
class UserMemoryService {
  static const String _memoryFile = 'user_memory.json';
  
  Map<String, dynamic> _memory = {
    'preferences': {},
    'facts': [],
    'instructions': [],
    'device_preferences': {},
  };
  
  bool _isLoaded = false;

  Future<File> get _memoryFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_memoryFile');
  }

  /// Load memory from disk
  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final file = await _memoryFilePath;
      if (await file.exists()) {
        final content = await file.readAsString();
        _memory = jsonDecode(content) as Map<String, dynamic>;
      }
      _isLoaded = true;
    } catch (e) {
      print('Error loading memory: $e');
      _isLoaded = true;
    }
  }

  /// Save memory to disk
  Future<void> _save() async {
    try {
      final file = await _memoryFilePath;
      await file.writeAsString(jsonEncode(_memory));
    } catch (e) {
      print('Error saving memory: $e');
    }
  }

  /// Remember a preference
  /// Example: "Remember that I prefer concise answers"
  Future<void> rememberPreference(String key, String value) async {
    await load();
    _memory['preferences'] ??= {};
    _memory['preferences'][key] = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _save();
  }

  /// Remember a fact
  /// Example: "My favorite food is pizza"
  Future<void> rememberFact(String fact) async {
    await load();
    _memory['facts'] ??= [];
    
    // Check for duplicates
    final facts = _memory['facts'] as List;
    if (!facts.any((f) => f['fact'] == fact)) {
      facts.add({
        'fact': fact,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await _save();
    }
  }

  /// Remember a user instruction
  /// Example: "Always ask before making calls"
  Future<void> rememberInstruction(String instruction) async {
    await load();
    _memory['instructions'] ??= [];
    
    // Check for duplicates
    final instructions = _memory['instructions'] as List;
    if (!instructions.any((i) => i['instruction'] == instruction)) {
      instructions.add({
        'instruction': instruction,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await _save();
    }
  }

  /// Remember device preference
  /// Example: {brightness: 50, theme: dark}
  Future<void> rememberDevicePreference(String key, dynamic value) async {
    await load();
    _memory['device_preferences'] ??= {};
    _memory['device_preferences'][key] = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _save();
  }

  /// Get all user preferences
  Future<Map<String, dynamic>> getPreferences() async {
    await load();
    final prefs = _memory['preferences'] as Map? ?? {};
    return prefs.map((k, v) => MapEntry(k, v is Map ? v['value'] : v));
  }

  /// Get a specific preference
  Future<String?> getPreference(String key) async {
    await load();
    final prefs = _memory['preferences'] as Map? ?? {};
    if (prefs.containsKey(key)) {
      final val = prefs[key];
      return val is Map ? val['value'] as String? : val as String?;
    }
    return null;
  }

  /// Get all facts
  Future<List<String>> getFacts() async {
    await load();
    final facts = _memory['facts'] as List? ?? [];
    return facts.map((f) => f is Map ? f['fact'] as String : f as String).toList();
  }

  /// Get all instructions
  Future<List<String>> getInstructions() async {
    await load();
    final instructions = _memory['instructions'] as List? ?? [];
    return instructions.map((i) => i is Map ? i['instruction'] as String : i as String).toList();
  }

  /// Get all device preferences
  Future<Map<String, dynamic>> getDevicePreferences() async {
    await load();
    final prefs = _memory['device_preferences'] as Map? ?? {};
    return prefs.map((k, v) => MapEntry(k, v is Map ? v['value'] : v));
  }

  /// Forget a specific memory
  Future<void> forgetFact(String fact) async {
    await load();
    final facts = _memory['facts'] as List? ?? [];
    facts.removeWhere((f) => f is Map ? f['fact'] == fact : f == fact);
    await _save();
  }

  /// Forget a specific instruction
  Future<void> forgetInstruction(String instruction) async {
    await load();
    final instructions = _memory['instructions'] as List? ?? [];
    instructions.removeWhere((i) => i is Map ? i['instruction'] == instruction : i == instruction);
    await _save();
  }

  /// Clear all user memory
  Future<void> clearAll() async {
    _memory = {
      'preferences': {},
      'facts': [],
      'instructions': [],
      'device_preferences': {},
    };
    await _save();
  }

  /// Whether approved memories may be used by the chat/task pipeline.
  ///
  /// Defaults to true so behavior is unchanged for existing installs; the
  /// flag only ever turns memory *usage* off, it never deletes records.
  Future<bool> getAutomaticMemoryEnabled() async {
    await load();
    return _memory['automatic_enabled'] as bool? ?? true;
  }

  /// Enables/disables automatic memory usage (Phase 13).
  Future<void> setAutomaticMemoryEnabled(bool enabled) async {
    await load();
    _memory['automatic_enabled'] = enabled;
    await _save();
  }

  /// Structured view over every stored memory, newest first per category.
  ///
  /// Derived from the same store as [getMemorySummary]; no parallel storage.
  Future<List<MemoryRecord>> getMemories() async {
    await load();
    final records = <MemoryRecord>[];

    final facts = _memory['facts'] as List? ?? [];
    for (final entry in facts) {
      if (entry is Map) {
        final value = (entry['fact'] ?? '').toString();
        if (value.isEmpty) continue;
        records.add(
          MemoryRecord(
            category: 'fact',
            id: 'fact:$value',
            value: value,
            reason: 'Stored as a user fact',
            timestamp: _parseTimestamp(entry['timestamp']),
          ),
        );
      }
    }

    final instructions = _memory['instructions'] as List? ?? [];
    for (final entry in instructions) {
      if (entry is Map) {
        final value = (entry['instruction'] ?? '').toString();
        if (value.isEmpty) continue;
        records.add(
          MemoryRecord(
            category: 'instruction',
            id: 'instruction:$value',
            value: value,
            reason: 'Stored as a standing instruction',
            timestamp: _parseTimestamp(entry['timestamp']),
          ),
        );
      }
    }

    final preferences = _memory['preferences'] as Map? ?? {};
    preferences.forEach((key, entry) {
      final value = entry is Map ? (entry['value'] ?? '').toString() : '$entry';
      records.add(
        MemoryRecord(
          category: 'preference',
          id: 'preference:$key',
          value: '$key: $value',
          reason: 'Stored as a user preference',
          timestamp: _parseTimestamp(entry is Map ? entry['timestamp'] : null),
        ),
      );
    });

    final devicePreferences = _memory['device_preferences'] as Map? ?? {};
    devicePreferences.forEach((key, entry) {
      final value = entry is Map ? (entry['value'] ?? '').toString() : '$entry';
      records.add(
        MemoryRecord(
          category: 'device',
          id: 'device:$key',
          value: '$key: $value',
          reason: 'Learned device preference',
          timestamp: _parseTimestamp(entry is Map ? entry['timestamp'] : null),
        ),
      );
    });

    return records;
  }

  /// Deletes exactly the record identified by [id] (see [MemoryRecord.id]).
  Future<void> deleteMemory(String id) async {
    await load();
    final separator = id.indexOf(':');
    if (separator <= 0) return;
    final category = id.substring(0, separator);
    final key = id.substring(separator + 1);

    switch (category) {
      case 'fact':
        await forgetFact(key);
      case 'instruction':
        await forgetInstruction(key);
      case 'preference':
        final preferences = _memory['preferences'] as Map?;
        preferences?.remove(key);
        await _save();
      case 'device':
        final devicePreferences = _memory['device_preferences'] as Map?;
        devicePreferences?.remove(key);
        await _save();
    }
  }

  static DateTime _parseTimestamp(dynamic raw) =>
      DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();

  /// Get memory summary for context
  /// Returns a formatted string of all memory to include in AI context
  Future<String> getMemorySummary() async {
    await load();
    final buffer = StringBuffer();
    
    final prefs = await getPreferences();
    if (prefs.isNotEmpty) {
      buffer.writeln('User Preferences:');
      prefs.forEach((k, v) {
        buffer.writeln('  - $k: $v');
      });
    }
    
    final facts = await getFacts();
    if (facts.isNotEmpty) {
      buffer.writeln('User Facts:');
      facts.forEach((f) {
        buffer.writeln('  - $f');
      });
    }
    
    final instructions = await getInstructions();
    if (instructions.isNotEmpty) {
      buffer.writeln('User Instructions:');
      instructions.forEach((i) {
        buffer.writeln('  - $i');
      });
    }
    
    return buffer.toString();
  }
}
