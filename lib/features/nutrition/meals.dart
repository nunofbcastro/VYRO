import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../app/theme/vyro_theme.dart';

/// Meal slots in the order they happen during the day.
const mealTypes = ['breakfast', 'lunch', 'snack', 'dinner'];

String mealLabel(VyroStrings t, String meal) => switch (meal) {
  'breakfast' => t.get('breakfast'),
  'lunch' => t.get('lunch'),
  'dinner' => t.get('dinner'),
  _ => t.get('snack'),
};

IconData mealIcon(String meal) => switch (meal) {
  'breakfast' => Icons.free_breakfast_outlined,
  'lunch' => Icons.lunch_dining_outlined,
  'dinner' => Icons.dinner_dining_outlined,
  _ => Icons.cookie_outlined,
};

/// Sensible default meal for the time of day; the user can always change it.
String mealForTime(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 11) return 'breakfast';
  if (hour >= 11 && hour < 15) return 'lunch';
  if (hour >= 19 || hour < 2) return 'dinner';
  return 'snack';
}

/// The four meal slots as an equal-width segmented control: icon above a
/// label. Labels may wrap onto two lines, so all four fit at 360 dp.
class MealSlotPicker extends StatelessWidget {
  const MealSlotPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1D23) : const Color(0xFFE9EDE4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final meal in mealTypes)
            Expanded(
              child: _MealSlot(
                icon: mealIcon(meal),
                label: mealLabel(t, meal),
                selected: value == meal,
                onTap: () => onChanged(meal),
              ),
            ),
        ],
      ),
    );
  }
}

class _MealSlot extends StatelessWidget {
  const _MealSlot({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = scheme.primary;
    final ink = selected
        ? VyroTheme.accentTextOf(context)
        : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: dark ? 0.16 : 0.20)
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: selected ? Border.all(color: accent, width: 1.2) : null,
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: ink),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
