import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Frosted-glass surface (blur + translucent fill + hairline), the material
/// used by the tab bar and the collapsed page header.
///
/// ```dart
/// VyroGlass(
///   borderRadius: BorderRadius.circular(26),
///   child: Padding(padding: EdgeInsets.all(12), child: Text('Olá')),
/// )
/// ```
///
/// [opacity] scales the fill from 0 (fully clear, no blur) to 1; animate it
/// to fade the glass in, e.g. when content scrolls under a header.
class VyroGlass extends StatelessWidget {
  const VyroGlass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.opacity = 1,
    this.border,
    this.blur = 24,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double opacity;

  /// Defaults to a hairline in the outline colour.
  final BoxBorder? border;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF14171C) : const Color(0xFFFFFFFF);
    final o = opacity.clamp(0.0, 1.0);
    if (o == 0) return child;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur * o, sigmaY: blur * o),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill.withValues(alpha: (dark ? 0.72 : 0.78) * o),
            borderRadius: borderRadius,
            border:
                border ??
                Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.7 * o),
                  width: 0.8,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
