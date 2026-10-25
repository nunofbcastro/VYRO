import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/ai/on_device_llm.dart';

/// User input remains literal; model replies render selectable Markdown.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.turn});

  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = turn.fromUser;
    final body = theme.textTheme.bodyMedium!.copyWith(
      color: user ? scheme.onPrimary : scheme.onSurface,
      height: 1.45,
    );
    final heading = body.copyWith(fontWeight: FontWeight.w700, height: 1.3);
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: EdgeInsets.only(
          bottom: 10,
          left: user ? 48 : 0,
          right: user ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: user
              ? scheme.primary
              : (theme.brightness == Brightness.dark
                    ? const Color(0xFF181B21)
                    : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 6),
            bottomRight: Radius.circular(user ? 6 : 18),
          ),
          border: user ? null : Border.all(color: scheme.outline, width: 0.8),
        ),
        child: user
            ? SelectableText(turn.text, style: body)
            : MarkdownBody(
                data: turn.text,
                selectable: true,
                softLineBreak: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: body,
                  h1: heading.copyWith(fontSize: 22),
                  h2: heading.copyWith(fontSize: 20),
                  h3: heading.copyWith(fontSize: 18),
                  h4: heading,
                  h5: heading,
                  h6: heading,
                  strong: const TextStyle(fontWeight: FontWeight.w700),
                  em: const TextStyle(fontStyle: FontStyle.italic),
                  listBullet: body,
                  listIndent: 22,
                  blockSpacing: 10,
                  blockquote: body.copyWith(color: scheme.onSurfaceVariant),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: scheme.primary, width: 3),
                    ),
                  ),
                  code: body.copyWith(fontFamily: 'monospace', fontSize: 13),
                  codeblockPadding: const EdgeInsets.all(12),
                  codeblockDecoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tableHead: heading,
                  tableBody: body,
                  tableColumnWidth: const IntrinsicColumnWidth(),
                  tableCellsPadding: const EdgeInsets.all(8),
                  tableBorder: TableBorder.all(
                    color: scheme.outline,
                    width: 0.6,
                  ),
                ),
                // Model output must not trigger image downloads or read
                // local files. Preserve the description as selectable text.
                imageBuilder: (uri, title, alt) =>
                    SelectableText(alt ?? title ?? '', style: body),
              ),
      ),
    );
  }
}
