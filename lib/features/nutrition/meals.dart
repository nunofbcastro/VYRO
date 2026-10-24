import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';

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
