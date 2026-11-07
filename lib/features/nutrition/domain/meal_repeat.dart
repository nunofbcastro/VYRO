import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Same meal, same name and the same grams. Used so "repeat yesterday"
/// does not stack a second copy of a food already on the day.
bool sameLoggedFood(FoodEntryRecord a, FoodEntryRecord b) =>
    a.mealType == b.mealType &&
    a.name.trim().toLowerCase() == b.name.trim().toLowerCase() &&
    (a.quantityGrams - b.quantityGrams).abs() < 0.5;

/// Entries from [source] that are not already on [destination].
/// [meal] limits the copy to one meal (breakfast, lunch, dinner, snack).
List<FoodEntryRecord> foodsToRepeat({
  required List<FoodEntryRecord> source,
  required List<FoodEntryRecord> destination,
  String? meal,
}) => [
  for (final entry in source)
    if (meal == null || entry.mealType == meal)
      if (!destination.any((have) => sameLoggedFood(have, entry))) entry,
];

/// Newest entry per food name. [entries] must already be newest first.
List<FoodEntryRecord> recentDistinctFoods(
  List<FoodEntryRecord> entries, {
  int limit = 8,
}) {
  final seen = <String>{};
  final out = <FoodEntryRecord>[];
  for (final entry in entries) {
    final key = entry.name.trim().toLowerCase();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(entry);
    if (out.length >= limit) break;
  }
  return out;
}

FoodEntriesCompanion copyEntryToDay(FoodEntryRecord entry, String day) =>
    FoodEntriesCompanion.insert(
      day: day,
      mealType: entry.mealType,
      name: entry.name,
      brand: Value(entry.brand),
      quantityGrams: entry.quantityGrams,
      kcalPer100g: Value(entry.kcalPer100g),
      proteinPer100g: Value(entry.proteinPer100g),
      carbsPer100g: Value(entry.carbsPer100g),
      fatPer100g: Value(entry.fatPer100g),
      source: Value(entry.source),
      portionUnit: Value(entry.portionUnit),
      portionCount: Value(entry.portionCount),
    );
