import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/region_food_vision.dart';

void main() {
  final original = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  final rice = original.byKey('rice_white_cooked')!;
  final labels = {1: rice.visionLabels[0], 2: rice.visionLabels[1]};
  final db = FoodDatabase([rice]);

  test('two labels from one region cannot count as two regions', () {
    final result = RegionFoodVision.interpretRegions(db, [
      [(1, 0.5), (2, 0.3)],
    ], labels);
    expect(result.foods, isEmpty);
  });

  test('independent regions retain one food and one typical portion', () {
    final result = RegionFoodVision.interpretRegions(db, [
      [(1, 0.5), (2, 0.3)],
      [(2, 0.2)],
    ], labels);
    expect(result.foods, hasLength(1));
    expect(result.foods.single.food?.key, rice.key);
    expect(result.foods.single.grams, rice.portionG);
    expect(result.foods.single.confidence, 0.5);
    expect(result.foods.single.count, isNull);
  });

  test('a chicken sandwich drops the weaker hamburger and offers McCrispy', () {
    const labels = {714: 'Chicken sandwich', 1621: 'Hamburger'};
    final result = RegionFoodVision.interpretRegions(original, [
      [(714, 0.4), (1621, 0.2)],
      [(714, 0.3), (1621, 0.16)],
    ], labels);
    final keys = result.foods.map((f) => f.food?.key).toList();
    expect(keys.first, 'chicken_sandwich');
    expect(keys, isNot(contains('cheeseburger_whole')));
    expect(keys, contains('mccrispy_hot_honey'));
    expect(
      result.foods.firstWhere((f) => f.food?.key == 'mccrispy_hot_honey').grams,
      294,
    );
  });
}
