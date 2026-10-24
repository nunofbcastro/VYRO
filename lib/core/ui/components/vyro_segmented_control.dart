import 'package:flutter/material.dart';

/// iOS-style segmented control: a recessed track with a sliding thumb.
///
/// ```dart
/// VyroSegmentedControl<int>(
///   value: days,
///   segments: const {7: '7D', 30: '30D', 90: '90D'},
///   onChanged: (value) => setState(() => days = value),
/// )
/// ```
class VyroSegmentedControl<T> extends StatelessWidget {
  const VyroSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;

  /// Ordered map of value → label.
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final keys = segments.keys.toList();
    final index = keys.indexOf(value).clamp(0, keys.length - 1);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1D23) : const Color(0xFFE9EDE4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / keys.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF2C313A) : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.3 : 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final key in keys)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: key == value,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => onChanged(key),
                          child: Center(
                            child: Text(
                              segments[key]!,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: key == value
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
