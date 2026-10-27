import 'package:flutter/material.dart';

/// One muted line under a model answer, for example when sentences were
/// removed. Never used for raw protocol text.
class AnswerFootnote extends StatelessWidget {
  const AnswerFootnote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6, left: 4, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
