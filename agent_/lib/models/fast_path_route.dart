library;

import 'task_plan.dart';

/// Small typed result from deterministic fast-path routing.
/// Never produces an LLM call.
class FastPathRoute {
  final bool matched;
  final String? routeName;
  final TaskPlan? plan;
  final String? reason;

  const FastPathRoute({
    this.matched = false,
    this.routeName,
    this.plan,
    this.reason,
  });
}

/// Minimal companion to hold the extracted YouTube query.
class YouTubeSearchParams {
  final String query;
  const YouTubeSearchParams({required this.query});
}
