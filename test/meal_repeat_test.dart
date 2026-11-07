import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/nutrition/domain/meal_repeat.dart';

FoodEntryRecord _food({
  required int id,
  required String day,
  required String meal,
  required String name,
  double grams = 100,
  DateTime? createdAt,
}) => FoodEntryRecord(
  id: id,
  day: day,
  mealType: meal,
  name: name,
  quantityGrams: grams,
  source: 'manual',
  createdAt: createdAt ?? DateTime(2026, 11, 7),
);

void main() {
  test('repeat skips a food already logged the same way', () {
    final yesterday = [
      _food(id: 1, day: '2026-11-06', meal: 'breakfast', name: 'Aveia'),
      _food(id: 2, day: '2026-11-06', meal: 'lunch', name: 'Arroz', grams: 180),
    ];
    final today = [
      _food(id: 3, day: '2026-11-07', meal: 'breakfast', name: 'aveia'),
    ];
    final copies = foodsToRepeat(source: yesterday, destination: today);
    expect(copies.single.name, 'Arroz');
    expect(copyEntryToDay(copies.single, '2026-11-07').day.value, '2026-11-07');
  });

  test('a meal filter copies only that meal', () {
    final yesterday = [
      _food(id: 1, day: '2026-11-06', meal: 'breakfast', name: 'Aveia'),
      _food(id: 2, day: '2026-11-06', meal: 'lunch', name: 'Arroz'),
    ];
    final copies = foodsToRepeat(
      source: yesterday,
      destination: const [],
      meal: 'breakfast',
    );
    expect(copies.single.mealType, 'breakfast');
  });

  test('recent foods keep the newest entry of each name', () {
    final foods = recentDistinctFoods([
      _food(
        id: 2,
        day: '2026-11-07',
        meal: 'lunch',
        name: 'Arroz',
        grams: 200,
        createdAt: DateTime(2026, 11, 7, 13),
      ),
      _food(
        id: 1,
        day: '2026-11-06',
        meal: 'lunch',
        name: 'arroz',
        grams: 150,
        createdAt: DateTime(2026, 11, 6),
      ),
      _food(id: 3, day: '2026-11-07', meal: 'breakfast', name: 'Aveia'),
    ]);
    expect(foods.map((food) => food.id), [2, 3]);
    expect(foods.first.quantityGrams, 200);
  });
}
