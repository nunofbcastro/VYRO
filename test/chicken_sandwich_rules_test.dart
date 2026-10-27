import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/burger_rules.dart';
import 'package:vyro/features/nutrition/food_vision/food_companions.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

/// One model answer item. [where] defaults to a plate position, as the
/// photo prompt asks the model to give one.
Map<String, Object?> _item(String name, {int count = 1, String? where}) => {
  'name': name,
  'where': where ?? 'centro do prato',
  'count': count,
  'size': 'medium',
};

String _answer(List<Map<String, Object?>> items) =>
    jsonEncode({'items': items});

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  List<DetectedFood> parse(List<Map<String, Object?>> items) =>
      parseFoodPhotoAnswer(_answer(items), db);

  List<String?> keysOf(List<DetectedFood> foods) => [
    for (final f in foods) f.food?.key,
  ];

  group('breaded chicken names map to the breaded patty', () {
    for (final name in [
      'fried chicken',
      'crispy chicken',
      'chicken patty',
      'breaded chicken',
      'frango frito',
      'filete de frango panado',
    ]) {
      test('"$name" is chicken_fried_patty (100 g, one piece)', () {
        final food = parse([_item(name)]).single;
        expect(food.food?.key, 'chicken_fried_patty', reason: name);
        expect(food.needsChoice, isFalse);
        expect(food.grams, 100);
      });
    }
  });

  group('chicken sandwich names map to the whole sandwich', () {
    for (final name in [
      'chicken burger',
      'chicken sandwich',
      'crispy chicken sandwich',
      'hambúrguer de frango',
      'sandes de frango panado',
    ]) {
      test('"$name" is chicken_sandwich (150 g, bun included)', () {
        final food = parse([_item(name)]).single;
        expect(food.food?.key, 'chicken_sandwich', reason: name);
        expect(food.grams, 150);
      });
    }
  });

  group('branded chicken sandwiches are the whole sandwich', () {
    test('"McChicken" is the branded row (131 g, one sandwich)', () {
      final food = parse([_item('mcchicken')]).single;
      expect(food.food?.key, 'mcchicken');
      expect(food.grams, 131);
      expect(isChickenSandwich(food), isTrue);
    });

    test('"mc chicken" and "McDonald\'s McChicken" reach the same row', () {
      for (final name in ['mc chicken', 'McDonald\'s McChicken']) {
        expect(
          parse([_item(name)]).single.food?.key,
          'mcchicken',
          reason: name,
        );
      }
    });

    test('"Burger King chicken sandwich" is the BK row (199 g)', () {
      final food = parse([_item('burger king chicken sandwich')]).single;
      expect(food.food?.key, 'bk_chicken_sandwich');
      expect(food.grams, 199);
    });

    test('McChicken plus a separate bun becomes the breaded patty', () {
      final foods = parse([_item('mcchicken'), _item('hamburger bun')]);
      expect(keysOf(foods), ['chicken_fried_patty', 'hamburger_bun']);
    });
  });

  group('grilled chicken stays grilled', () {
    for (final name in [
      'grilled chicken',
      'chicken breast',
      'frango grelhado',
      'peito de frango grelhado',
      'chicken',
    ]) {
      test('"$name" alone is chicken_breast_roasted', () {
        expect(
          parse([_item(name)]).single.food?.key,
          'chicken_breast_roasted',
          reason: name,
        );
      });
    }

    test('an explicit "grilled chicken" stays grilled next to a bun', () {
      final keys = keysOf(
        parse([_item('grilled chicken'), _item('hamburger bun')]),
      );
      expect(keys, contains('chicken_breast_roasted'));
      expect(keys, isNot(contains('chicken_fried_patty')));
    });
  });

  group('bare chicken with bread or a sandwich word', () {
    test('"chicken" next to a bun is the breaded patty, bun kept', () {
      final foods = parse([_item('chicken'), _item('hamburger bun')]);
      expect(keysOf(foods), ['chicken_fried_patty', 'hamburger_bun']);
      expect(foods.first.grams, 100);
    });

    test('"chicken" next to plain bread is the breaded patty', () {
      final keys = keysOf(parse([_item('chicken'), _item('pão')]));
      expect(keys.first, 'chicken_fried_patty');
      expect(keys, hasLength(2));
    });

    test('"chicken" whose where says burger is the whole sandwich', () {
      final foods = parse([_item('chicken', where: 'burger no centro')]);
      expect(keysOf(foods), ['chicken_sandwich']);
    });

    test('"chicken" with no bread and no sandwich word stays grilled', () {
      final foods = parse([_item('chicken', where: 'centro do prato')]);
      expect(keysOf(foods), ['chicken_breast_roasted']);
    });
  });

  group('double count for chicken: sandwich plus bun', () {
    test('a chicken sandwich with a separate bun becomes the patty', () {
      final foods = parse([_item('chicken sandwich'), _item('hamburger bun')]);
      expect(keysOf(foods), ['chicken_fried_patty', 'hamburger_bun']);
      expect(foods.first.grams, 100);
    });

    test('a breaded patty with a bun is not reduced to anything else', () {
      final keys = keysOf(
        parse([_item('fried chicken'), _item('hamburger bun')]),
      );
      expect(keys, ['chicken_fried_patty', 'hamburger_bun']);
    });
  });

  group('companion suggestions: bacon, cheese, sauce, salad', () {
    List<String?> companionKeys(List<Map<String, Object?>> items) => [
      for (final c in mealCompanions(parse(items), db)) c.food?.key,
    ];

    test(
      'a beef patty alone: bun, bacon, cheese, burger sauce, then salad',
      () {
        final keys = companionKeys([_item('beef patty')]);
        expect(keys, [
          'hamburger_bun',
          'bacon_cooked',
          'cheese_gouda',
          'burger_sauce',
          'lettuce_raw',
          'tomato_raw',
        ]);
      },
    );

    test('a breaded chicken patty alone: bun, bacon, cheese, mayonnaise', () {
      final keys = companionKeys([_item('fried chicken')]);
      expect(keys, [
        'hamburger_bun',
        'bacon_cooked',
        'cheese_gouda',
        'mayonnaise',
        'lettuce_raw',
        'tomato_raw',
      ]);
      expect(keys, isNot(contains('burger_sauce')));
    });

    test('a burger sandwich gets bacon, lettuce and tomato, no bun', () {
      final keys = companionKeys([_item('hamburger')]);
      expect(keys, ['bacon_cooked', 'lettuce_raw', 'tomato_raw']);
    });

    test('a chicken sandwich gets bacon, lettuce and tomato, no bun', () {
      final keys = companionKeys([_item('mcchicken')]);
      expect(keys, ['bacon_cooked', 'lettuce_raw', 'tomato_raw']);
    });

    test('bacon already in the list is not suggested again', () {
      final keys = companionKeys([_item('chicken sandwich'), _item('bacon')]);
      expect(keys, isNot(contains('bacon_cooked')));
      expect(keys, containsAll(['lettuce_raw', 'tomato_raw']));
    });

    test('lettuce already listed is not suggested again', () {
      final keys = companionKeys([_item('beef patty'), _item('lettuce')]);
      expect(keys, isNot(contains('lettuce_raw')));
      expect(keys, contains('tomato_raw'));
    });

    test('suggestions stay outside the totals', () {
      final foods = parse([_item('chicken sandwich')]);
      expect(foods, hasLength(1));
      expect(foods.single.food?.key, 'chicken_sandwich');
    });
  });
}
