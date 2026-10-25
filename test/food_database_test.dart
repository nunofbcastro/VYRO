import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
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
      'pizza pepperoni': 'pizza_pepperoni',
      'pizza': 'pizza_cheese',
      'massa com carne': 'pasta_bolognese',
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
