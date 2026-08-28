import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/theme/cypher_theme.dart';
import '../core/theme/spacing_tokens.dart';
import '../core/ui/cypher_components.dart';
import '../models/chat_message.dart';

/// Chat message rendering with the Cypher design system.
///
/// Assistant messages render integrated into the page (no floating card);
/// user messages use a compact accent-tinted bubble. Long-press (and the
/// inline copy affordance) expose the available message actions — currently
/// copy only, the one action the chat pipeline supports. Regenerate/edit
/// would require backend support that does not exist yet and is therefore
/// deliberately not shown.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Compact rendering for constrained surfaces (the overlay chat).
  /// Scales padding and type down; keeps the same token-driven materials.
  final bool compact;

  const MessageBubble({
    super.key,
    required this.message,
    this.compact = false,
  });

  ImageProvider? _imageProvider() {
    final value = message.imageUrl;
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        try {
          return MemoryImage(base64Decode(value.substring(comma + 1)));
        } catch (_) {
          return null;
        }
      }
    }
    return NetworkImage(value);
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider();
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width *
              CypherDimensions.chatBubbleMaxWidth,
        ),
        margin: EdgeInsets.only(
          left: isUser ? CypherSpacing.space12 : 0,
          right: isUser ? 0 : CypherSpacing.space12,
          top: CypherSpacing.space2,
          bottom: CypherSpacing.space2,
        ),
        child: GestureDetector(
          onLongPress: () => _showMessageActions(context),
          child: isUser
              ? _buildUserBody(context, image)
              : _buildAssistantBody(context, image),
        ),
      ),
    );
  }

  Widget _buildUserBody(BuildContext context, ImageProvider? image) {
    final c = context.cypher;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? CypherSpacing.space4 : CypherSpacing.space5,
        vertical: compact ? CypherSpacing.space3 : CypherSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: c.colors.accent.withOpacity(0.16),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(CypherSpacing.radiusLg),
          topRight: Radius.circular(CypherSpacing.radiusLg),
          bottomLeft: Radius.circular(CypherSpacing.radiusLg),
          bottomRight: Radius.circular(CypherSpacing.radiusSm),
        ),
        border: Border.all(color: c.colors.accent.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.content,
            style: compact ? c.typography.bodyMedium : c.typography.chatMessage,
          ),
          if (image != null) ...[
            const SizedBox(height: CypherSpacing.space3),
            _MessageImage(image: image),
          ],
          const SizedBox(height: CypherSpacing.space1),
          Text(_formatTime(message.timestamp), style: c.typography.chatMeta),
        ],
      ),
    );
  }

  Widget _buildAssistantBody(BuildContext context, ImageProvider? image) {
    final c = context.cypher;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CypherSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.actionResult != null)
            _ActionResultBadge(result: message.actionResult!),
          MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet:
                MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: compact ? c.typography.bodyMedium : c.typography.chatMessage,
              listBullet:
                  compact ? c.typography.bodyMedium : c.typography.chatMessage,
              h1: c.typography.headlineSmall,
              h2: c.typography.titleLarge,
              h3: c.typography.titleMedium,
              code: c.typography.chatCodeInline,
              codeblockDecoration: BoxDecoration(
                color: c.colors.surfaceContainer,
                borderRadius: BorderRadius.circular(CypherSpacing.radiusSm),
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.colors.accent, width: 3),
                ),
              ),
            ),
          ),
          if (image != null) ...[
            const SizedBox(height: CypherSpacing.space3),
            _MessageImage(image: image),
          ],
          const SizedBox(height: CypherSpacing.space1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.timestamp),
                style: c.typography.chatMeta,
              ),
              const SizedBox(width: CypherSpacing.space2),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  tooltip: 'Copy message',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  color: c.colors.textTertiary,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => _copyMessage(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    showCypherSheet(
      context: context,
      title: 'Message actions',
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _copyMessage(context);
                },
              ),
              const SizedBox(height: CypherSpacing.space2),
            ],
          ),
        );
      },
    );
  }

  void _copyMessage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.cypher.colors.surfaceContainerHigh,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Bounded, rounded message image with a token error fallback.
class _MessageImage extends StatelessWidget {
  final ImageProvider image;

  const _MessageImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    return ClipRRect(
      borderRadius: BorderRadius.circular(CypherSpacing.radiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: Image(
          image: image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Padding(
            padding: const EdgeInsets.all(CypherSpacing.space3),
            child: Text(
              'Image could not be displayed.',
              style: c.typography.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}

/// Token-colored success/failure badge for agent action results.
class _ActionResultBadge extends StatelessWidget {
  final AgentActionResult result;

  const _ActionResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    final color = result.success ? c.colors.success : c.colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CypherSpacing.space3,
        vertical: CypherSpacing.space1,
      ),
      margin: const EdgeInsets.only(bottom: CypherSpacing.space2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(CypherSpacing.radiusSm),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            result.success
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: CypherSpacing.space2),
          Text(
            result.actionType.toUpperCase().replaceAll('_', ' '),
            style: c.typography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

