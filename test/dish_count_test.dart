import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/dish_count.dart';
import 'package:vyro/features/nutrition/food_vision/region_food_vision.dart';

/// A 4×4 grid from rows of "x" (marked) and "." (not marked).
List<List<bool>> _grid(List<String> rows) => [
  for (final row in rows) [for (final ch in row.split('')) ch == 'x'],
];

void main() {
  group('separatePlateCount (pure clustering)', () {
    test('minBlobCells is 3', () {
      expect(minBlobCells, 3);
    });

    test('two separate blobs of three cells each give 2', () {
      expect(separatePlateCount(_grid(['xxx.', '....', '....', '.xxx'])), 2);
    });

    test('blobs of 3 and 2 cells give 1 (the 2-cell blob is noise)', () {
      expect(separatePlateCount(_grid(['xxx.', '....', '....', '..xx'])), 1);
      expect(separatePlateCount(_grid(['xx..', '....', '....', '.xxx'])), 1);
    });

    test('two separate blobs of two cells each give 1', () {
      expect(separatePlateCount(_grid(['xx..', '....', '....', '..xx'])), 1);
    });

    test('three separate blobs of three cells give 3', () {
      expect(separatePlateCount(_grid(['xxx.', '...x', 'x..x', 'xx.x'])), 3);
    });

    test('four blobs of three cells are not proposed (cap at 3)', () {
      expect(
        separatePlateCount(_grid(['xxx.xxx', '.......', 'xxx.xxx', '.......'])),
        1,
      );
    });

    test('one blob gives 1', () {
      expect(separatePlateCount(_grid(['xxxx', 'xxxx', '....', '....'])), 1);
    });

    test('touching blobs (shared edge) are one blob', () {
      expect(separatePlateCount(_grid(['xxx.', '.xxx', '..xx', '....'])), 1);
    });

    test('blobs touching only at a corner are two blobs', () {
      expect(separatePlateCount(_grid(['xx..', 'x...', '.xx.', '..x.'])), 2);
    });

    test('single-cell and two-cell noise is ignored', () {
      expect(separatePlateCount(_grid(['x...', '....', '..xx', '..xx'])), 1);
      expect(separatePlateCount(_grid(['x..x', '....', '....', '....'])), 1);
      expect(separatePlateCount(_grid(['xxx.', '....', '....', '.xxx'])), 2);
    });

    test('an empty grid gives 1', () {
      expect(separatePlateCount(_grid(['....', '....', '....', '....'])), 1);
      expect(separatePlateCount(const []), 1);
    });
  });

  group('markCellsForFood', () {
    const labels = {1: 'Francesinha', 2: 'Pastel de nata'};
    const background = 0;

    test('marks cells whose top food label is the dish label', () {
      final cells = [
        [(background, 0.02), (1, 0.6), (2, 0.1)],
        [(background, 0.02), (2, 0.6), (1, 0.1)],
        [(background, 0.9)],
        [(background, 0.1), (1, 0.05)],
      ];
      final marks = markCellsForFood(
        cells: cells,
        labels: labels,
        foodLabels: {'Francesinha'},
        backgroundLabel: background,
        minProbability: 0.08,
        side: 2,
      );
      expect(marks, [
        [true, false],
        [false, false],
      ]);
    });

    test('a cell the background wins is never marked', () {
      final marks = markCellsForFood(
        cells: [
          [(background, 0.7), (1, 0.2)],
        ],
        labels: labels,
        foodLabels: {'Francesinha'},
        backgroundLabel: background,
        minProbability: 0.08,
        side: 1,
      );
      expect(marks, [
        [false],
      ]);
    });
  });

  group('region classifier proposes separate plates for a whole dish', () {
    final db = FoodDatabase.parse(
      File('assets/nutrition/foods.json').readAsStringSync(),
    );
    const labels = {1: 'Francesinha', 2: 'Pastel de nata'};

    /// Eleven whole-image crops see the dish; the 4×4 grid marks [marked].
    List<List<(int, double)>> perCrop(List<String> rows) {
      final crops = <List<(int, double)>>[
        for (var i = 0; i < 11; i++) [(0, 0.02), (1, 0.5)],
      ];
      for (final row in rows) {
        for (final ch in row.split('')) {
          crops.add(ch == 'x' ? [(0, 0.02), (1, 0.6)] : [(0, 0.9)]);
        }
      }
      return crops;
    }

    test('a 2-cell blob beside a 3-cell blob gives one plate', () {
      final result = RegionFoodVision.interpretRegions(
        db,
        perCrop(['xxx.', '....', '....', '..xx']),
        labels,
      );
      final francesinha = result.foods.firstWhere(
        (f) => f.food?.key == 'francesinha',
      );
      expect(francesinha.count, isNull);
      expect(francesinha.countProposed, isFalse);
    });

    test('two separate blobs of a whole francesinha give two plates', () {
      final result = RegionFoodVision.interpretRegions(
        db,
        perCrop(['xxx.', '....', '....', '.xxx']),
        labels,
      );
      final francesinha = result.foods.firstWhere(
        (f) => f.food?.key == 'francesinha',
      );
      expect(francesinha.count, 2);
      expect(francesinha.countProposed, isTrue);
      expect(francesinha.grams, 1100);
    });

    test('one blob keeps one plate with no proposal', () {
      final result = RegionFoodVision.interpretRegions(
        db,
        perCrop(['xxxx', 'xxxx', '....', '....']),
        labels,
      );
      final francesinha = result.foods.firstWhere(
        (f) => f.food?.key == 'francesinha',
      );
      expect(francesinha.count, isNull);
      expect(francesinha.countProposed, isFalse);
      expect(francesinha.grams, 550);
    });

    test('a dish with no single portion unit never gets a proposal', () {
      // Pastel de nata has portion_units 1 but is not a whole dish.
      final result = RegionFoodVision.interpretRegions(
        db,
        perCrop(['xxx.', '....', '....', '.xxx']).map((crop) {
          return [for (final (k, p) in crop) (k == 1 ? 2 : k, p)];
        }).toList(),
        labels,
      );
      final pastel = result.foods.where((f) => f.food?.key == 'pastel_de_nata');
      expect(pastel.single.countProposed, isFalse);
      expect(pastel.single.count, isNull);
    });
  });
}
