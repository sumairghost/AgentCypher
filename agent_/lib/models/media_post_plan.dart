library;

import 'capability_registry.dart';
import 'task_plan.dart';

/// Reference to a user-confirmed media selection. Never auto-populated.
class MediaReference {
  /// Stable identifier (picker result URI, path, or id). Not interpreted
  /// by the executor; the consuming app reads the file at its own risk.
  final String reference;
  final String? displayLabel;
  final String? mimeType;

  const MediaReference({
    required this.reference,
    this.displayLabel,
    this.mimeType,
  });
}

/// Checkpoint identifier for a media-post plan. Used to support cancel /
/// resume decisions and to gate fresh confirmation.
enum MediaPostCheckpoint {
  pickerConfirmed,
  appOpened,
  draftStarted,
  imageAttached,
  captionEntered,
  previewVerified,
  finalConfirmed,
  finalExecuted,
}

/// Draft of a multi-app social post. The executor never mutates the draft;
/// the user re-approves at each irreversible boundary.
class MediaPostPlan {
  final String rootGoal;
  final MediaReference media;
  final String targetApp;
  final String caption;
  final List<MediaPostCheckpoint> requiredCheckpoints;

  /// True when the final action has been approved and executed at least
  /// once in this run. Resets only on a fresh draft.
  final bool finalActionExecuted;

  const MediaPostPlan({
    required this.rootGoal,
    required this.media,
    required this.targetApp,
    required this.caption,
    this.requiredCheckpoints = const [
      MediaPostCheckpoint.pickerConfirmed,
      MediaPostCheckpoint.appOpened,
      MediaPostCheckpoint.draftStarted,
      MediaPostCheckpoint.imageAttached,
      MediaPostCheckpoint.captionEntered,
      MediaPostCheckpoint.previewVerified,
      MediaPostCheckpoint.finalConfirmed,
    ],
    this.finalActionExecuted = false,
  });

  CapabilityEntry get capability => CapabilityRegistry.instagramCreatePost;

  /// Validation: caption + media + target app must all be present and
  /// non-empty. Image-only or text-only posts are out of scope.
  List<String> validate() {
    final issues = <String>[];
    if (media.reference.trim().isEmpty) issues.add('media reference is empty');
    if (targetApp.trim().isEmpty) issues.add('target app is empty');
    if (caption.trim().isEmpty) issues.add('caption is empty');
    return issues;
  }

  /// Build a typed plan from this draft. The plan is non-executable until
  /// the user has confirmed every checkpoint and the final action gets a
  /// fresh approval.
  TaskPlan toPlan() {
    final issues = validate();
    if (issues.isNotEmpty) {
      throw StateError('Invalid MediaPostPlan: ${issues.join('; ')}');
    }
    return TaskPlan(
      rootGoal: rootGoal,
      steps: [
        PlanStep(
          id: 'mp_open',
          intent: 'Open $targetApp',
          action: 'open_app',
          params: {'app_name': targetApp},
          requiredApp: targetApp,
          verificationMethod: VerificationMethod.appForeground,
          expectedResult: targetApp,
          retryPolicy: const RetryPolicy(maxAttempts: 2),
        ),
        PlanStep(
          id: 'mp_new_post',
          intent: 'Start a new post in $targetApp',
          action: 'click_text',
          params: {'text': 'New'},
          requiredApp: targetApp,
          dependsOn: ['mp_open'],
          verificationMethod: VerificationMethod.screenChanged,
          expectedResult: 'create flow',
          requiresConfirmation: false,
        ),
        PlanStep(
          id: 'mp_attach_image',
          intent: 'Attach selected image',
          action: 'click_text',
          params: {'text': 'Add', 'target_description': 'image attach'},
          requiredApp: targetApp,
          dependsOn: ['mp_new_post'],
          verificationMethod: VerificationMethod.screenChanged,
          expectedResult: 'image attached',
          requiresConfirmation: false,
        ),
        PlanStep(
          id: 'mp_caption',
          intent: 'Enter caption',
          action: 'type_text',
          params: {'text': caption, 'field_hint': 'caption'},
          requiredApp: targetApp,
          dependsOn: ['mp_attach_image'],
          verificationMethod: VerificationMethod.textTyped,
          expectedResult: caption,
          requiresConfirmation: false,
        ),
        PlanStep(
          id: 'mp_preview',
          intent: 'Verify preview shows caption and image',
          action: 'wait',
          requiredApp: targetApp,
          dependsOn: ['mp_caption'],
          verificationMethod: VerificationMethod.contentVisible,
          expectedResult: caption,
          requiresConfirmation: false,
        ),
        PlanStep(
          id: 'mp_final',
          intent: 'Final share / post (requires fresh user confirmation)',
          action: 'press_enter',
          requiredApp: targetApp,
          dependsOn: ['mp_preview'],
          verificationMethod: VerificationMethod.screenChanged,
          expectedResult: 'post submitted',
          requiresConfirmation: true,
        ),
      ],
    );
  }
}
