import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_companions.dart';
import 'package:vyro/features/nutrition/food_vision/food_names.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

String _items(List<String> names) => jsonEncode({
  'items': [
    for (final name in names)
      {'name': name, 'where': 'centro do prato', 'count': 1, 'size': 'medium'},
  ],
});

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  group('plural and English name candidates', () {
    test('plural falls back to singular and reaches the egg row', () {
      expect(foodNameCandidates('Ovos').first, 'Ovos');
      expect(foodNameCandidates('Ovos'), contains('ovo'));
      final foods = parseFoodPhotoAnswer(_items(['Ovos']), db);
      expect(foods, hasLength(1));
      expect(foods.single.food?.key, startsWith('egg_'));
      expect(foods.single.needsChoice, isFalse);
    });

    test('singular variants: batatas fritas, tomates, limões, pães', () {
      expect(singularVariants('batatas fritas'), contains('batata frita'));
      expect(singularVariants('tomates'), contains('tomate'));
      expect(singularVariants('limoes'), contains('limao'));
      expect(singularVariants('paes'), contains('pao'));
      expect(singularVariants('atuns'), contains('atum'));
      expect(singularVariants('morangos'), contains('morango'));
      expect(singularVariants('ovo'), isEmpty);
    });

    test('the original name is tried before any fallback', () {
      final candidates = foodNameCandidates('Batata frita');
      expect(candidates.first, 'Batata frita');
    });

    test('English drinks and foods map to Portuguese', () {
      expect(englishFoodName('beer'), 'cerveja');
      expect(englishFoodName('a beer'), 'cerveja');
      expect(englishFoodName('sparkling water'), 'água com gás');
      expect(englishFoodName('steak'), 'bife');
      expect(englishFoodName('fries'), 'batatas fritas');
      expect(englishFoodName('unknown thing'), isNull);
    });

    test('English names resolve in the database', () {
      expect(matchFoodName(db, foodNameCandidates('beer'))?.key, 'beer');
      expect(
        matchFoodName(db, foodNameCandidates('sparkling water'))?.key,
        'sparkling_water',
      );
      expect(
        matchFoodName(db, foodNameCandidates('steak'))?.key,
        startsWith('beef_'),
      );
      expect(
        matchFoodName(db, foodNameCandidates('eggs'))?.key,
        startsWith('egg_'),
      );
    });

    test('a Somersby or cider from the model matches the cider row', () {
      final cider = parseFoodPhotoAnswer(_items(['Sidra']), db).single;
      expect(cider.food?.key, 'cider');
      expect(cider.label, 'Sidra');
      final somersby = parseFoodPhotoAnswer(_items(['Somersby']), db).single;
      expect(somersby.food?.key, 'cider');
      final english = parseFoodPhotoAnswer(_items(['cider']), db).single;
      expect(english.food?.key, 'cider');
    });

    test('plain water matches still water, not sparkling', () {
      final water = parseFoodPhotoAnswer(_items(['water']), db).single;
      expect(water.food?.key, 'still_water');
    });
  });

  group('generic names', () {
    test('"beverage" and "dish" become a question, not a food', () {
      for (final name in ['beverage', 'Beverage', 'dish', 'snack']) {
        final item = parseFoodPhotoAnswer(_items([name]), db).single;
        expect(item.needsChoice, isTrue, reason: name);
        expect(item.food, isNull, reason: name);
      }
    });

    test('a specific food is never treated as generic', () {
      final item = parseFoodPhotoAnswer(_items(['Bife']), db).single;
      expect(item.needsChoice, isFalse);
    });
  });

  group('prompts', () {
    test('ask for European Portuguese names and locations', () {
      final prompt = buildFoodPhotoPrompt();
      expect(prompt, contains('European Portuguese'));
      expect(prompt, contains('centro do prato'));
      expect(prompt, contains('copo em cima à esquerda'));
      expect(buildFoodSecondChancePrompt(), contains('European Portuguese'));
    });
  });

  group('companion suggestions', () {
    DetectedFood food(String name) => DetectedFood(
      label: name,
      grams: 100,
      source: VisionSource.systemAi,
      food: matchFoodName(db, foodNameCandidates(name)),
    );

    test('steak suggests gravy, cream and mayonnaise, never as totals', () {
      final steak = food('Bife de vaca grelhado');
      final companions = mealCompanions([steak], db);
      final keys = [for (final c in companions) c.food?.key];
      expect(keys, containsAll(['brown_gravy', 'cooking_cream', 'mayonnaise']));
      for (final c in companions) {
        expect(c.food, isNotNull);
        expect(db.byKey(c.food!.key), isNotNull);
      }
    });

    test('suggestions skip foods already listed', () {
      final steak = food('Bife');
      final gravy = food('Molho castanho');
      final companions = mealCompanions([steak, gravy], db);
      expect([
        for (final c in companions) c.food?.key,
      ], isNot(contains('brown_gravy')));
    });

    test('fries suggest mayonnaise; salad suggests olive oil', () {
      expect([
        for (final c in mealCompanions([food('Batata frita')], db)) c.food?.key,
      ], contains('mayonnaise'));
      expect([
        for (final c in mealCompanions([food('Salada')], db)) c.food?.key,
      ], contains('olive_oil'));
    });

    test('an unrelated food gets no companions', () {
      expect(mealCompanions([food('Pão torrado')], db), isEmpty);
    });

    test('ketchup is suggested only when the database has it', () {
      final hasKetchup = db.foods.any(
        (f) =>
            f.aliases.contains('ketchup') ||
            f.namePt.toLowerCase() == 'ketchup',
      );
      final keys = [
        for (final c in mealCompanions([food('Bife')], db)) c.food?.key,
      ];
      expect(keys.contains('ketchup'), hasKetchup);
    });
  });
}
