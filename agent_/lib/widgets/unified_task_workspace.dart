import 'package:flutter/material.dart';

/// Placeholder shell for the future unified task workspace.
///
/// The controlled self-upgrade workflow that would drive this widget is not
/// enabled in the current build, so it intentionally renders nothing rather
/// than a fake surface. When the workflow ships, this widget becomes the
/// shared workspace view for task steps, artifacts, and terminal output.
class UnifiedTaskWorkspace extends StatelessWidget {
  const UnifiedTaskWorkspace({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
