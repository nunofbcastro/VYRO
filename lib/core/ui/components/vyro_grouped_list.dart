import 'package:flutter/material.dart';

import '../../../app/theme/vyro_theme.dart';

/// iOS-style inset grouped list: an optional small header, one rounded
/// container with hairline separators, and an optional footnote.
///
/// ```dart
/// VyroGroupedSection(
///   header: 'Definições',
///   children: [
///     VyroListRow(icon: Icons.palette_outlined, title: 'Aspeto', value: 'Escuro', onTap: openAppearance),
///     VyroListRow(icon: Icons.language, title: 'Idioma', value: 'Português', onTap: openLanguage),
///   ],
/// )
/// ```
class VyroGroupedSection extends StatelessWidget {
  const VyroGroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              header!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF13161B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outline.withValues(alpha: dark ? 0.8 : 0.6),
              width: 0.8,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.8,
                      thickness: 0.8,
                      indent: 60,
                      color: scheme.outline.withValues(alpha: 0.8),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(footer!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// One row of a [VyroGroupedSection]: tinted icon squircle, title, optional
/// subtitle, trailing value and a chevron when tappable.
///
/// Set [destructive] for irreversible actions (red title and icon).
class VyroListRow extends StatelessWidget {
  const VyroListRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final IconData? icon;

  /// Squircle tint; defaults to the brand accent.
  final Color? iconColor;
  final String? subtitle;

  /// Short current value shown before the chevron ("Escuro", "PT").
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = destructive
        ? scheme.error
        : (iconColor ?? VyroTheme.accentTextOf(context));
    final muted = theme.textTheme.bodySmall?.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 18, color: tint),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: destructive ? scheme.error : scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 20, color: muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
