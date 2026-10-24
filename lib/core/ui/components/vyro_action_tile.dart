import 'package:flutter/material.dart';

import '../../../app/theme/vyro_theme.dart';

/// Shortcut tile (icon above label). Use [primary] for the one main action in
/// a row — it gets the lime gradient; the others stay neutral.
///
/// ```dart
/// Row(children: [
///   Expanded(child: VyroActionTile(icon: Icons.barcode_reader, label: 'Código', primary: true, onTap: scan)),
///   const SizedBox(width: 10),
///   Expanded(child: VyroActionTile(icon: Icons.photo_camera_outlined, label: 'Foto', onTap: photo)),
/// ])
/// ```
class VyroActionTile extends StatelessWidget {
  const VyroActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          gradient: primary ? VyroTheme.ctaGradient(darkMode: dark) : null,
          color: primary
              ? null
              : (dark ? const Color(0xFF13161B) : Colors.white),
          borderRadius: radius,
          border: primary
              ? null
              : Border.all(color: scheme.outline, width: 0.8),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: primary
                          ? VyroTheme.ink
                          : VyroTheme.accentTextOf(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: primary ? VyroTheme.ink : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
