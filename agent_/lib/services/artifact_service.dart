import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes sanitized text artifacts (for example the privacy-sanitized
/// developer diagnostics report) into the app's temporary directory so the
/// system share sheet can hand them to the user.
///
/// Only caller-supplied content is written; this service never reads keys,
/// prompts, or screen content.
class ArtifactService {
  static final ArtifactService shared = ArtifactService._();

  ArtifactService._();

  /// Writes [content] to a timestamped file derived from [name].
  ///
  /// [kind], [sourceTask], and [validationState] are metadata the caller may
  /// embed inside [content]; they are not written separately.
  ///
  /// Returns the written file path, or an empty string when storage is
  /// unavailable (the caller is expected to fall back to the share sheet).
  Future<String> exportText({
    required String name,
    required String kind,
    required String content,
    String sourceTask = '',
    String validationState = '',
  }) async {
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}$fileName',
      );
      await file.writeAsString(content, flush: true);
      return file.path;
    } catch (_) {
      return '';
    }
  }
}
