import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/photo/review_model.dart';

DetectedFood _line(
  String label, {
  FoodRef? food,
  bool pending = false,
  double grams = 100,
}) => DetectedFood(
  food: food,
  label: label,
  grams: grams,
  source: VisionSource.systemAi,
  pending: pending,
);

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  test('a draft line keeps its identity when the final result confirms it', () {
    final rice = db.byKey('rice_white_cooked')!;
    final draft = mergeReviewItems(null, [
      _line(rice.namePt, food: rice, pending: true),
      _line('Peixe grelhado', pending: true),
    ]);
    final riceLine = draft.first;
    expect(riceLine.pending, isTrue);
    expect(countReview(draft).savable, 0);

    final finalItems = mergeReviewItems(draft, [
      _line(rice.namePt, food: rice, grams: 150),
    ]);
    expect(identical(finalItems.first, riceLine), isTrue);
    expect(riceLine.pending, isFalse);
    expect(riceLine.grams, 150);
    // The unconfirmed line is flagged to collapse, not dropped at once.
    expect(finalItems.last.removing, isTrue);
    expect(finalItems, hasLength(2));
  });

  test('countReview separates savable foods from unresolved lines', () {
    final rice = db.byKey('rice_white_cooked')!;
    final espresso = db.byKey('espresso')!;
    final items = mergeReviewItems(null, [
      _line(rice.namePt, food: rice),
      _line(espresso.namePt, food: espresso, grams: 0),
      _line('Peixe grelhado'),
      _line('Bebida', food: null),
    ]);
    final counts = countReview(items);
    expect(counts.savable, 1);
    expect(counts.unresolved, 2);
    expect(counts.pending, 0);
    expect(counts.hasUnresolved, isTrue);
  });

  test('a removed line is not counted while it collapses', () {
    final rice = db.byKey('rice_white_cooked')!;
    final items = mergeReviewItems(null, [_line(rice.namePt, food: rice)]);
    items.first.removing = true;
    final counts = countReview(items);
    expect(counts.savable, 0);
    expect(counts.unresolved, 0);
  });

  test('new lines from a final result are appended in order', () {
    final rice = db.byKey('rice_white_cooked')!;
    final espresso = db.byKey('espresso')!;
    final first = mergeReviewItems(null, [_line(rice.namePt, food: rice)]);
    final next = mergeReviewItems(first, [
      _line(rice.namePt, food: rice),
      _line(espresso.namePt, food: espresso),
    ]);
    expect(next.map((i) => i.food?.key), ['rice_white_cooked', 'espresso']);
    expect(identical(next.first, first.first), isTrue);
  });
}
