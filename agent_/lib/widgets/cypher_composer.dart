import 'package:flutter/material.dart';

import '../core/theme/cypher_theme.dart';
import '../core/theme/spacing_tokens.dart';
import '../core/ui/cypher_components.dart';

/// Cypher chat composer.
///
/// Layout: [ microphone ] [ input …………… ] [ send / stop ].
///
/// Progressive disclosure by state:
/// - empty input: send disabled (mic remains the primary voice entry)
/// - text present: send enables
/// - generating: send becomes Stop; the typed input is preserved
/// - listening: the mic highlights in accent color
///
/// No attachment/tools button is shown on purpose: the Dart side has no
/// attachment pipeline yet, and fake controls are prohibited (see
/// `.claude/skills/cypher-ui-design/SKILL.md` and redesign Phase 13).
class CypherComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isListening;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final VoidCallback onToggleVoice;

  const CypherComposer({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.isListening,
    required this.onSend,
    required this.onStop,
    required this.onToggleVoice,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CypherSpacing.space4,
          CypherSpacing.space2,
          CypherSpacing.space4,
          CypherSpacing.space4,
        ),
        child: CypherGlass(
          blur: true,
          borderRadius: BorderRadius.circular(CypherSpacing.radiusModal),
          padding: const EdgeInsets.symmetric(
            horizontal: CypherSpacing.space2,
            vertical: CypherSpacing.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _VoiceButton(
                isListening: isListening,
                isLoading: isLoading,
                onTap: onToggleVoice,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: c.typography.inputText,
                  cursorColor: c.colors.accent,
                  decoration: InputDecoration(
                    hintText: isListening
                        ? 'Listening…'
                        : isLoading
                            ? 'Cypher is working…'
                            : 'Message Cypher',
                    hintStyle: c.typography.helperText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: CypherSpacing.space3,
                      vertical: CypherSpacing.space4,
                    ),
                  ),
                  onSubmitted: isLoading ? null : onSend,
                ),
              ),
              _SendButton(
                controller: controller,
                isLoading: isLoading,
                onSend: () => onSend(controller.text),
                onStop: onStop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  final bool isListening;
  final bool isLoading;
  final VoidCallback onTap;

  const _VoiceButton({
    required this.isListening,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isListening
            ? c.colors.accent.withOpacity(0.18)
            : Colors.transparent,
        border: Border.all(
          color: isListening ? c.colors.accent : c.colors.borderLight,
        ),
      ),
      child: IconButton(
        tooltip: isListening ? 'Stop listening' : 'Voice input',
        splashRadius: 22,
        padding: EdgeInsets.zero,
        iconSize: 20,
        color: isListening ? c.colors.accent : c.colors.textSecondary,
        icon: Icon(isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
        onPressed: isLoading ? null : onTap,
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _SendButton({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;

    if (isLoading) {
      // Stop replaces send during generation; the typed input is preserved.
      return SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          tooltip: 'Stop generating',
          splashRadius: 22,
          padding: EdgeInsets.zero,
          iconSize: 22,
          color: c.colors.error,
          icon: const Icon(Icons.stop_circle_rounded),
          onPressed: onStop,
        ),
      );
    }

    // Listening only to the text field keeps the enabled state in sync
    // without rebuilding the rest of the composer.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSend = value.text.trim().isNotEmpty;
        return SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: 'Send',
            splashRadius: 22,
            padding: EdgeInsets.zero,
            iconSize: 22,
            color: canSend ? c.colors.accent : c.colors.textTertiary,
            icon: const Icon(Icons.arrow_upward_rounded),
            onPressed: canSend ? onSend : null,
          ),
        );
      },
    );
  }
}
