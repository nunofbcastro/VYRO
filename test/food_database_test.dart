import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/assistant/domain/meal_proposal.dart'
    show foodTokens;
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_companions.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  group('bundled database', () {
    test('has Portuguese, European and Brazilian foods with sources', () {
      expect(db.foods.length, greaterThan(100));
      expect(
        db.foods.map((f) => f.source).toSet(),
        containsAll(['usda', 'ciqual', 'taco']),
      );
      expect(
        db.foods.map((f) => f.region).toSet(),
        containsAll(['pt', 'eu', 'br', 'int']),
      );
      for (final f in db.foods) {
        expect(f.kcal, inInclusiveRange(0, 900), reason: f.key);
        expect(f.portionG, greaterThan(0), reason: f.key);
        expect(f.sourceRef, isNotEmpty, reason: f.key);
        // Energy roughly consistent with macros (Atwater), skipping drinks
        // with alcohol and near-zero foods.
        final atwater = 4 * f.protein + 4 * f.carbs + 9 * f.fat;
        if (f.kcal > 60 && f.category != 'bebidas') {
          expect(
            (atwater - f.kcal).abs() / f.kcal,
            lessThan(0.3),
            reason: '${f.key}: ${f.kcal} kcal vs Atwater $atwater',
          );
        }
      }
    });

    test('keys are unique and source keys are traceable', () {
      expect(db.foods.map((f) => f.key).toSet().length, db.foods.length);
      expect(db.byKey('chicken_breast_roasted')!.sourceKey, 'usda_171477');
      expect(db.byKey('cod_salted_boiled')!.sourceKey, 'ciqual_26024');
      expect(db.byKey('beans_carioca_cooked')!.sourceKey, 'taco_561');
    });

    test('matches Portuguese names without guessing', () {
      expect(
        db.match('Peito de frango grelhado')?.key,
        'chicken_breast_roasted',
      );
      expect(db.match('Arroz branco cozido')?.key, 'rice_white_cooked');
      expect(db.match('bacalhau')?.key, 'cod_salted_boiled');
      expect(db.match('xyz desconhecido'), isNull);
    });

    test('search finds regional foods', () {
      expect(
        db.search('bacalhau').map((f) => f.key),
        contains('cod_salted_boiled'),
      );
      expect(db.search('pão de queijo').first.key, 'pao_de_queijo');
      expect(
        db.search('feijão').first.category,
        anyOf('leguminosas', 'pratos'),
      );
    });

    test('vision labels point to plate foods', () {
      expect(
        db.forVisionLabel('White rice').map((f) => f.key),
        contains('rice_white_cooked'),
      );
      expect(
        db.forVisionLabel('Garden salad').map((f) => f.key),
        contains('green_salad'),
      );
    });
  });

  group('photo names from real-device tests', () {
    /// Name → expected food key. Accents are optional (beirao = beirão).
    const expected = {
      'morangos': 'strawberries_raw',
      'morango': 'strawberries_raw',
      'atum': 'tuna_canned_water',
      'couve roxa': 'cabbage_red_raw',
      'cenoura ralada': 'carrot_raw',
      'croissant misto': 'croissant_ham_cheese',
      'croissant simples': 'croissant',
      'sanduíche mista': 'sandwich_ham_cheese',
      'água das pedras': 'sparkling_water',
      'água com gás': 'sparkling_water',
      'água das pedras limão': 'sparkling_water',
      'água': 'still_water',
      'água mineral': 'still_water',
      'natas': 'cooking_cream',
      'maionese': 'mayonnaise',
      'molho big mac': 'burger_sauce',
      'molho de hambúrguer': 'burger_sauce',
      'molho especial': 'burger_sauce',
      'molho de cerveja': 'brown_gravy',
      'pão de hambúrguer': 'hamburger_bun',
      'hambúrguer no pão': 'cheeseburger_whole',
      'hambúrguer': 'beef_ground_patty',
      'carne picada': 'beef_ground_raw',
      'carne moída': 'beef_ground_raw',
      'carne picada de porco': 'pork_ground_raw',
      'bife': 'beef_sirloin_broiled',
      'bife de vaca grelhado': 'beef_sirloin_broiled',
      'bife de vaca frito': 'beef_steak_fried',
      'ovo estrelado': 'egg_fried',
      'nuggets': 'chicken_nuggets',
      'nuggets de frango': 'chicken_nuggets',
      'croquetes': 'croquete_meat_fried',
      'doritos': 'tortilla_chips',
      'nachos': 'tortilla_chips',
      'somersby': 'cider',
      'sidra': 'cider',
      'super bock': 'beer',
      'sagres': 'beer',
      'beirao': 'liqueur',
      'beirão': 'liqueur',
      'coca-cola': 'cola_coca',
      'sumol': 'orange_soft_drink',
      'guaraná': 'guarana_soda',
      'refrigerante de guaraná': 'guarana_soda',
      'presunto': 'cured_ham',
      'pizza pepperoni': 'pizza_pepperoni_whole',
      'pizza': 'pizza_cheese_whole',
      'pizza inteira': 'pizza_cheese_whole',
      'pizza de pepperoni': 'pizza_pepperoni_whole',
      'fatia de pizza': 'pizza_cheese',
      'fatia de pizza de pepperoni': 'pizza_pepperoni',
      'massa com carne': 'pasta_bolognese',
      'ketchup': 'ketchup',
      'catsup': 'ketchup',
      'molho de tomate': 'pasta_tomato_sauce',
      'molho de tomate para massa': 'pasta_tomato_sauce',
      'queijo ralado': 'parmesan_grated',
      'parmesão ralado': 'parmesan_grated',
      'mostarda': 'mustard',
      'molho de soja': 'soy_sauce',
      'shoyu': 'soy_sauce',
      'molho de iogurte': 'yogurt_sauce',
      'fio de azeite': 'olive_oil',
      'azeite': 'olive_oil',
    };

    test('the photo-model names resolve to the expected foods', () {
      for (final entry in expected.entries) {
        expect(
          db.match(entry.key)?.key,
          entry.value,
          reason: '"${entry.key}" should match ${entry.value}',
        );
      }
    });

    test('a generic "refrigerante" does not match a specific soda', () {
      expect(db.match('refrigerante'), isNull);
    });

    test('new rows keep their source references', () {
      expect(db.byKey('cabbage_red_raw')!.sourceKey, 'usda_169977');
      expect(db.byKey('beef_ground_raw')!.sourceKey, 'ciqual_6254');
      expect(db.byKey('croquete_meat_fried')!.sourceKey, 'taco_388');
      expect(db.byKey('sparkling_water')!.kcal, closeTo(0, 0.1));
    });
  });

  group('English names, singular and plural', () {
    /// English names a model or a US/UK user types → expected key.
    const expected = {
      'almond': 'almonds',
      'almonds': 'almonds',
      'lemon': 'lemon_raw',
      'lemons': 'lemon_raw',
      'lemon wedge': 'lemon_raw',
      'lemon juice': 'lemon_juice',
      'white sauce': 'white_sauce_bechamel',
      'bechamel sauce': 'white_sauce_bechamel',
      'bacon': 'bacon_cooked',
      'bacon slice': 'bacon_cooked',
      'bacon slices': 'bacon_cooked',
      'mashed potato': 'mashed_potato',
      'mashed potatoes': 'mashed_potato',
      'arugula': 'arugula_raw',
      'rocket': 'arugula_raw',
      'fish': 'cod_cooked',
      'fish fillet': 'cod_cooked',
      'white fish': 'cod_cooked',
      'kale': 'kale_raw',
      'kale raw': 'kale_raw',
      'cooked kale': 'kale_cooked',
      'pomelo': 'pomelo_raw',
      'pomelos': 'pomelo_raw',
      'dried fruit': 'dried_fruit_raisins',
      'dried fruits': 'dried_fruit_raisins',
      'dried cranberries': 'cranberries_dried',
      'brussels sprouts': 'brussels_cooked',
      'brussels sprout': 'brussels_cooked',
      'plantain': 'plantain_cooked',
      'plantains': 'plantain_cooked',
      'pecan': 'pecan_nuts',
      'pecans': 'pecan_nuts',
      'eggplant': 'eggplant_cooked',
      'eggplants': 'eggplant_cooked',
      'aubergine': 'eggplant_cooked',
      'aubergines': 'eggplant_cooked',
      'egg white': 'egg_white',
      'egg whites': 'egg_white',
      'scrambled egg': 'egg_scrambled',
      'scrambled eggs': 'egg_scrambled',
      'boiled egg': 'egg_boiled',
      'boiled eggs': 'egg_boiled',
      'fried egg': 'egg_fried',
      'fried eggs': 'egg_fried',
      'corn on the cob': 'corn_canned',
      'sweet corn': 'corn_canned',
      'blueberry': 'blueberries_raw',
      'blueberries': 'blueberries_raw',
      'honeydew melon': 'honeydew_raw',
      'green bell pepper': 'green_pepper_raw',
      'green peppers': 'green_pepper_raw',
      'raw spinach': 'spinach_raw',
      'spinach': 'spinach_cooked',
      'spring onion': 'spring_onion_raw',
      'spring onions': 'spring_onion_raw',
      'scallion': 'spring_onion_raw',
      'scallions': 'spring_onion_raw',
      'green onion': 'spring_onion_raw',
      'onion': 'onion_raw',
      'onions': 'onion_raw',
      'eggplant cooked': 'eggplant_cooked',
      'chickpea': 'chickpeas_cooked',
      'chickpeas': 'chickpeas_cooked',
      'garbanzo': 'chickpeas_cooked',
      'garbanzos': 'chickpeas_cooked',
      'zucchini': 'zucchini_cooked',
      'zucchinis': 'zucchini_cooked',
      'courgette': 'zucchini_cooked',
      'courgettes': 'zucchini_cooked',
      'ground beef': 'beef_ground_raw',
      'minced beef': 'beef_ground_raw',
      'french fries': 'potato_fries_oven',
      'fries': 'potato_fries_oven',
      'soda': 'cola_coca',
      'soft drink': 'cola_coca',
      'chicken breast': 'chicken_breast_roasted',
      'chicken breasts': 'chicken_breast_roasted',
      'grilled chicken': 'chicken_breast_roasted',
      'white rice': 'rice_white_cooked',
      'steamed rice': 'rice_white_cooked',
      'tomato': 'tomato_raw',
      'tomatoes': 'tomato_raw',
      'cherry tomatoes': 'tomato_raw',
      'carrot': 'carrot_raw',
      'carrots': 'carrot_raw',
      'cooked carrots': 'carrot_cooked',
      'grape': 'grapes_raw',
      'grapes': 'grapes_raw',
      'strawberries': 'strawberries_raw',
      'peaches': 'peach_raw',
      'mushrooms': 'mushrooms_raw',
      'pork chop': 'pork_loin_broiled',
      'pork chops': 'pork_loin_broiled',
      'beef steak': 'beef_sirloin_broiled',
      'beef steaks': 'beef_sirloin_broiled',
      'sweet potatoes': 'sweet_potato_baked',
      'mozzarella': 'cheese_mozzarella',
      'cheese slice': 'cheese_gouda',
      'olive oil': 'olive_oil',
      'extra virgin olive oil': 'olive_oil',
      'sardines': 'sardines_canned_oil',
      'shrimps': 'shrimp_cooked',
      'prawns': 'shrimp_cooked',
      'pizza slices': 'pizza_cheese',
      'pepperoni slices': 'pizza_pepperoni',
      'hamburger patty': 'beef_ground_patty',
      'hamburger buns': 'hamburger_bun',
      'cheeseburgers': 'cheeseburger_whole',
      'ham slices': 'ham_cooked',
      'cooked ham': 'ham_cooked',
      'lentils': 'lentils_cooked',
      'lentil': 'lentils_cooked',
      'green beans': 'green_beans_cooked',
      'peas': 'peas_cooked',
      'pea': 'peas_cooked',
    };

    test('each English name maps to its food', () {
      for (final entry in expected.entries) {
        expect(
          db.match(entry.key)?.key,
          entry.value,
          reason: '"${entry.key}" should match ${entry.value}',
        );
      }
    });

    test('new rows match their English names and keep their refs', () {
      expect(db.byKey('almonds')!.sourceKey, 'usda_170567');
      expect(db.byKey('bacon_cooked')!.sourceKey, 'usda_168322');
      expect(db.byKey('kale_raw')!.sourceKey, 'usda_168421');
      expect(db.byKey('kale_cooked')!.sourceKey, 'usda_169238');
      expect(db.byKey('eggplant_cooked')!.sourceKey, 'ciqual_20002');
      expect(db.byKey('mashed_potato')!.sourceKey, 'ciqual_4047');
      expect(db.byKey('lemon_raw')!.sourceKey, 'ciqual_13009');
      expect(db.byKey('lemon_juice')!.sourceKey, 'ciqual_2028');
      expect(db.byKey('brussels_cooked')!.sourceKey, 'usda_169971');
      expect(db.byKey('arugula_raw')!.sourceKey, 'ciqual_20217');
      expect(db.byKey('pecan_nuts')!.sourceKey, 'usda_170182');
      expect(db.byKey('plantain_cooked')!.sourceKey, 'ciqual_53101');
      expect(db.byKey('dried_fruit_raisins')!.sourceKey, 'usda_168165');
      expect(db.byKey('cranberries_dried')!.sourceKey, 'usda_171723');
      expect(db.byKey('white_sauce_bechamel')!.sourceKey, 'ciqual_11143');
      expect(db.byKey('egg_white')!.sourceKey, 'usda_172183');
      expect(db.byKey('egg_scrambled')!.sourceKey, 'usda_172187');
      expect(db.byKey('blueberries_raw')!.sourceKey, 'usda_171711');
      expect(db.byKey('pomelo_raw')!.sourceKey, 'usda_173033');
      expect(db.byKey('honeydew_raw')!.sourceKey, 'usda_169911');
      expect(db.byKey('green_pepper_raw')!.sourceKey, 'usda_170427');
      expect(db.byKey('spinach_raw')!.sourceKey, 'usda_168462');
      expect(db.byKey('spring_onion_raw')!.sourceKey, 'usda_170005');
    });

    test('the photo-model names that were unmatched now resolve', () {
      // Names from the on-device English-name evaluation (training subset).
      for (final name in [
        'almond',
        'lemon',
        'white sauce',
        'bacon',
        'mashed potatoes',
        'arugula',
        'fish',
        'kale',
        'pomelo',
        'dried fruit',
        'brussels sprouts',
        'plantain',
        'pecan',
        'eggplant',
        'egg whites',
      ]) {
        expect(db.match(name), isNotNull, reason: name);
      }
    });
  });

  group('alias hygiene', () {
    test('no name or alias maps to two different foods', () {
      final owners = <String, Set<String>>{};
      for (final f in db.foods) {
        for (final text in [f.namePt, f.nameEn, ...f.aliases]) {
          final tokens = foodTokens(text);
          if (tokens.isEmpty) continue;
          final signature = (tokens.toList()..sort()).join(' ');
          owners.putIfAbsent(signature, () => <String>{}).add(f.key);
        }
      }
      final clashes = {
        for (final e in owners.entries)
          if (e.value.length > 1) e.key: e.value,
      };
      expect(clashes, isEmpty);
    });

    test('bare generic words do not pick one food', () {
      // "bean" and "nuts" are too generic: a row with that word must not win.
      expect(db.match('bean'), isNull);
      expect(db.match('nuts'), isNull);
      expect(db.match('almond milk')?.key, 'almond_drink');
      expect(db.match('corn chips')?.key, 'tortilla_chips');
    });
  });

  group('companion foods', () {
    DetectedFood food(String name) => DetectedFood(
      label: name,
      grams: 100,
      source: VisionSource.systemAi,
      food: db.match(name),
    );

    test('new companion rows have their exact source references', () {
      expect(db.byKey('ketchup')!.sourceKey, 'ciqual_11008');
      expect(db.byKey('pasta_tomato_sauce')!.sourceKey, 'usda_171192');
      expect(db.byKey('parmesan_grated')!.sourceKey, 'usda_171247');
      expect(db.byKey('mustard')!.sourceKey, 'usda_172234');
      expect(db.byKey('soy_sauce')!.sourceKey, 'ciqual_11104');
      expect(db.byKey('yogurt_sauce')!.sourceKey, 'ciqual_11166');
    });

    test('new companion rows use the portions agreed for them', () {
      expect(db.byKey('ketchup')!.portionG, 15);
      expect(db.byKey('pasta_tomato_sauce')!.portionG, 60);
      expect(db.byKey('parmesan_grated')!.portionG, 10);
      expect(db.byKey('mustard')!.portionG, 5);
      expect(db.byKey('soy_sauce')!.portionG, 10);
      expect(db.byKey('yogurt_sauce')!.portionG, 30);
    });

    test('the names the companion rules look up exist as foods', () {
      for (final name in ['ketchup', 'molho de tomate', 'queijo ralado']) {
        expect(db.match(name), isNotNull, reason: name);
      }
    });

    test('steak suggests ketchup; pasta suggests tomato sauce and cheese', () {
      expect([
        for (final c in mealCompanions([food('Bife')], db)) c.food?.key,
      ], contains('ketchup'));
      final pasta = [
        for (final c in mealCompanions([food('Massa')], db)) c.food?.key,
      ];
      expect(pasta, containsAll(['pasta_tomato_sauce', 'parmesan_grated']));
    });

    test('kcal for a companion portion follows grams x kcal/100 g', () {
      final ketchup = db.byKey('ketchup')!;
      expect(ketchup.kcal * ketchup.portionG / 100, closeTo(16.2, 0.05));
    });
  });

  group('portion maths', () {
    test('kcal = grams × kcal/100 g ÷ 100', () {
      final rice = db.byKey('rice_white_cooked')!;
      final item = DetectedFood(
        food: rice,
        label: rice.namePt,
        grams: 150,
        source: VisionSource.user,
      );
      expect(item.kcal, closeTo(rice.kcal * 1.5, 1e-9));
      expect(item.protein, closeTo(rice.protein * 1.5, 1e-9));
      expect(
        const DetectedFood(
          label: '?',
          grams: 100,
          source: VisionSource.user,
        ).kcal,
        isNull,
      );
    });
  });

  group('system model answer', () {
    test('parses items, merges duplicates and keeps unknown names', () {
      const raw = '''```json
{"items":[
 {"name":"Peito de frango grelhado","count":1,"grams":120},
 {"name":"Peito de frango grelhado","count":1,"grams":110},
 {"name":"Arroz branco cozido","grams":150},
 {"name":"Salada verde","grams":80},
 {"name":"Molho misterioso","grams":9000}
]}
```''';
      final foods = parseFoodPhotoAnswer(raw, db);
      expect(foods, hasLength(4));
      final chicken = foods.first;
      expect(chicken.food?.key, 'chicken_breast_roasted');
      expect(chicken.grams, 120);
      expect(chicken.count, 1);
      expect(foods[1].food?.key, 'rice_white_cooked');
      expect(foods[2].food?.key, 'green_salad');
      expect(foods[3].food, isNull);
      expect(foods[3].grams, 1500); // clamped
    });

    test('invalid answers give no foods', () {
      expect(parseFoodPhotoAnswer('não sei', db), isEmpty);
      expect(parseFoodPhotoAnswer('{"items": "x"}', db), isEmpty);
    });

    test('photo prompt asks for JSON with a location and no checklist', () {
      final prompt = buildFoodPhotoPrompt();
      expect(prompt, contains('"items"'));
      expect(prompt, contains('"where"'));
      expect(prompt, contains('pan, pot, tray, box, packaging or hand'));
      expect(prompt, isNot(contains('Fewer items')));
      expect(prompt, isNot(contains('1 to 4')));
      expect(prompt, isNot(contains('Check protein')));
      final rice = db.byKey('rice_white_cooked')!;
      final found = [
        DetectedFood(
          food: rice,
          label: rice.namePt,
          grams: 150,
          source: VisionSource.systemAi,
        ),
      ];
      expect(buildFoodVerifyPrompt(found), contains(rice.namePt));
    });

    test('a repeated coffee row does not double its cup or nutrients', () {
      final foods = parseFoodPhotoAnswer(
        '{"items":[{"name":"Café expresso","count":1,"grams":30},'
        '{"name":"Café","count":1,"grams":30}]}',
        db,
      );
      expect(foods, hasLength(1));
      expect(foods.single.food?.key, 'espresso');
      expect(foods.single.count, 1);
      expect(foods.single.grams, 30);
    });

    test('two explicit pieces use total grams without multiplying again', () {
      final foods = parseFoodPhotoAnswer(
        '{"items":[{"name":"Peito de frango grelhado","count":2,"grams":240}]}',
        db,
      );
      expect(foods.single.count, 2);
      expect(foods.single.grams, 240);
    });

    test('wrong field types do not discard otherwise usable foods', () {
      final foods = parseFoodPhotoAnswer(
        '{"items":[{"name":42},{"name":"Café","count":"2","grams":{}},'
        '{"name":"Manteiga","grams":5}]}',
        db,
      );
      expect(foods, hasLength(2));
      expect(foods.first.grams, db.byKey('espresso')!.portionG);
      expect(foods.first.count, isNull);
    });

    test('breakfast names match the new drinks and spreads', () {
      expect(db.match('Café expresso')?.key, 'espresso');
      expect(db.match('Café com leite')?.key, 'coffee_with_milk');
      expect(db.match('Manteiga')?.key, 'butter_salted');
      expect(db.match('Pão torrado')?.key, 'bread_white_toasted');
    });
  });

  group('pipeline', () {
    final regions = _FakeVision(VisionSource.regionClassifier);

    test('uses the system model when available', () async {
      final result = await FoodVisionPipeline(
        llm: _FakeLlm(LlmStatus.available),
        system: _FakeVision(VisionSource.systemAi),
        regions: regions,
      ).analyse(Uint8List(0));
      expect(result.source, VisionSource.systemAi);
    });

    test('falls back to regions when the system model fails', () async {
      final result = await FoodVisionPipeline(
        llm: _FakeLlm(LlmStatus.available),
        system: _FakeVision(VisionSource.systemAi, error: Exception('x')),
        regions: regions,
      ).analyse(Uint8List(0));
      expect(result.source, VisionSource.regionClassifier);
      expect(result.notes, contains('systemFailed'));
      // Offline guesses never enter the main list after a system failure.
      expect(result.foods, isEmpty);
    });

    test('text-only system model falls back silently', () async {
      final result = await FoodVisionPipeline(
        llm: _FakeLlm(LlmStatus.available),
        system: _FakeVision(
          VisionSource.systemAi,
          error: MissingPluginException(),
        ),
        regions: regions,
      ).analyse(Uint8List(0));
      expect(result.source, VisionSource.regionClassifier);
      expect(result.notes, isNot(contains('systemFailed')));
    });

    test('uses regions when no system model exists', () async {
      final result = await FoodVisionPipeline(
        llm: _FakeLlm(LlmStatus.unavailable),
        system: _FakeVision(VisionSource.systemAi),
        regions: regions,
      ).analyse(Uint8List(0));
      expect(result.source, VisionSource.regionClassifier);
    });
  });
}

class _FakeLlm implements OnDeviceLlm {
  _FakeLlm(this._status);
  final LlmStatus _status;
  @override
  Future<LlmStatus> status() async => _status;
  @override
  Future<LlmStatus> download() async => _status;
  @override
  Future<String> generate(String prompt) async => '';
}

class _FakeVision implements FoodVisionService {
  _FakeVision(this.source, {this.error});
  final VisionSource source;
  final Object? error;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async {
    if (error != null) throw error!;
    return FoodVisionResult(foods: const [], source: source);
  }
}
