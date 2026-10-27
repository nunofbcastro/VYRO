import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/burger_rules.dart';
import 'package:vyro/features/nutrition/food_vision/food_companions.dart';
import 'package:vyro/features/nutrition/food_vision/food_names.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

/// One model answer with the given (name, count) items.
String _answer(List<(String, int)> items) => jsonEncode({
  'items': [
    for (final (name, count) in items)
      {
        'name': name,
        'where': 'centro do prato',
        'count': count,
        'size': 'medium',
      },
  ],
});

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  List<DetectedFood> parse(List<(String, int)> items) =>
      parseFoodPhotoAnswer(_answer(items), db);

  group('English burger names mean the sandwich', () {
    for (final name in [
      'hamburger',
      'burger',
      'cheeseburger',
      'cheese burger',
      'big mac',
      'double cheeseburger',
    ]) {
      test('"$name" is cheeseburger_whole (150 g, one item)', () {
        final food = parse([(name, 1)]).single;
        expect(food.food?.key, 'cheeseburger_whole', reason: name);
        expect(food.needsChoice, isFalse);
        expect(food.grams, 150);
      });
    }

    test('English names reach the sandwich through matchFoodName too', () {
      expect(
        matchFoodName(db, foodNameCandidates('hamburger'))?.key,
        'cheeseburger_whole',
      );
      expect(
        matchFoodName(db, foodNameCandidates('burger'))?.key,
        'cheeseburger_whole',
      );
    });

    test('"beef patty" and "burger patty" stay the meat patty (120 g)', () {
      for (final name in ['beef patty', 'burger patty', 'patty']) {
        final food = parse([(name, 1)]).single;
        expect(food.food?.key, 'beef_ground_patty', reason: name);
        expect(food.grams, 120);
      }
    });

    test('the Portuguese bare "hambúrguer" stays the patty', () {
      expect(parse([('hambúrguer', 1)]).single.food?.key, 'beef_ground_patty');
    });

    test('"2 hamburgers" is two sandwiches: 300 g, count 2', () {
      final food = parse([('hamburger', 2)]).single;
      expect(food.food?.key, 'cheeseburger_whole');
      expect(food.count, 2);
      expect(food.grams, 300);
    });
  });

  group('double count: sandwich plus bun', () {
    test('a sandwich with a separate bun becomes the patty (no bun twice)', () {
      final foods = parse([('hamburger', 1), ('hamburger bun', 1)]);
      final keys = [for (final f in foods) f.food?.key];
      expect(keys, ['beef_ground_patty', 'hamburger_bun']);
      expect(foods.first.grams, 120);
      expect(foods.first.label, 'Hambúrguer de vaca');
    });

    test(
      'the patty keeps the count: 2 sandwiches + bun = 2 patties, 240 g',
      () {
        final foods = parse([('hamburger', 2), ('bread', 1)]);
        final patty = foods.singleWhere((f) => isBurgerPatty(f));
        expect(patty.count, 2);
        expect(patty.grams, 240);
        expect(foods.where(isBurgerSandwich), isEmpty);
      },
    );

    test('a sandwich alone stays a sandwich (it has its own bun)', () {
      final foods = parse([('cheeseburger', 1)]);
      expect(foods.single.food?.key, 'cheeseburger_whole');
    });

    test('bread that is not a bun still counts as the bun', () {
      final foods = parse([('burger', 1), ('pão', 1)]);
      expect(foods.map((f) => f.food?.key), contains('beef_ground_patty'));
      expect(
        foods.map((f) => f.food?.key),
        isNot(contains('cheeseburger_whole')),
      );
    });

    test('a patty with an existing patty row collapses into one row', () {
      final foods = parse([
        ('hamburger', 1),
        ('beef patty', 1),
        ('hamburger bun', 1),
      ]);
      expect(foods.where(isBurgerPatty), hasLength(1));
      expect(foods.where(isBurgerSandwich), isEmpty);
    });

    test('reconcileBurgerSandwich leaves unrelated lists alone', () {
      final pizza = parse([('pizza', 1)]);
      expect(reconcileBurgerSandwich(pizza, db), same(pizza));
    });
  });

  group('missing bun: patty without bread', () {
    test(
      'a patty alone suggests the bun first, then bacon, cheese and sauce',
      () {
        final foods = parse([('beef patty', 1)]);
        final companions = mealCompanions(foods, db);
        final keys = [for (final c in companions) c.food?.key];
        expect(keys.take(4).toList(), [
          'hamburger_bun',
          'bacon_cooked',
          'cheese_gouda',
          'burger_sauce',
        ]);
        expect(companions.every((c) => c.food != null), isTrue);
      },
    );

    test('suggestions are never part of the totals', () {
      final foods = parse([('beef patty', 1)]);
      expect(foods, hasLength(1));
      expect(foods.single.food?.key, 'beef_ground_patty');
    });

    test('a burger patty gets no gravy suggestion', () {
      final keys = [
        for (final c in mealCompanions(parse([('beef patty', 1)]), db))
          c.food?.key,
      ];
      expect(keys, isNot(contains('brown_gravy')));
    });

    test('no bun suggestion when bread is already listed', () {
      final foods = parse([('beef patty', 1), ('bread', 1)]);
      final keys = [for (final c in mealCompanions(foods, db)) c.food?.key];
      expect(keys, isNot(contains('hamburger_bun')));
    });

    test('no bun suggestion for a sandwich, which has its own bun', () {
      final keys = [
        for (final c in mealCompanions(parse([('hamburger', 1)]), db))
          c.food?.key,
      ];
      expect(keys, isNot(contains('hamburger_bun')));
    });

    test('cheese is not suggested again when cheese is listed', () {
      final foods = parse([('beef patty', 1), ('cheese slice', 1)]);
      final keys = [for (final c in mealCompanions(foods, db)) c.food?.key];
      expect(keys, isNot(contains('cheese_gouda')));
      expect(keys, containsAll(['hamburger_bun', 'burger_sauce']));
    });

    test('burger sauce is not suggested when it is already listed', () {
      final foods = parse([('beef patty', 1), ('burger sauce', 1)]);
      final keys = [for (final c in mealCompanions(foods, db)) c.food?.key];
      expect(keys, isNot(contains('burger_sauce')));
    });
  });
}
