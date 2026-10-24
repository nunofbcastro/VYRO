import 'package:flutter/material.dart';

/// Circular progress ring with content in the middle (daily calories).
///
/// ```dart
/// VyroRing(value: 0.62, size: 120, child: Text('1450'))
/// ```
class VyroRing extends StatelessWidget {
  const VyroRing({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 9,
    this.color,
    this.child,
  });

  /// 0–1; values outside are clamped.
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) => CircularProgressIndicator(
                value: animated,
                strokeWidth: stroke,
                strokeCap: StrokeCap.round,
                color: color ?? scheme.primary,
                backgroundColor: scheme.outline.withValues(alpha: 0.55),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// Labelled thin bar for one macronutrient: "Proteína 82 / 140 g".
class VyroMacroBar extends StatelessWidget {
  const VyroMacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    this.unit = 'g',
  });

  final String label;
  final double value;
  final double goal;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label ${value.round()} / ${goal.round()} $unit',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: value.round().toString(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    children: [
                      TextSpan(
                        text: ' / ${goal.round()} $unit',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  end: goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0),
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, animated, _) => LinearProgressIndicator(
                  value: animated,
                  minHeight: 5,
                  color: color,
                  backgroundColor: theme.colorScheme.outline.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
