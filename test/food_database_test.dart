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

    test('prompts ask for JSON with a checklist and a second look', () {
      final prompt = buildFoodPhotoPrompt();
      expect(prompt, contains('"items"'));
      expect(prompt, contains('legumes'));
      expect(prompt, contains('drinks'));
      final rice = db.byKey('rice_white_cooked')!;
      final found = [
        DetectedFood(
          food: rice,
          label: rice.namePt,
          grams: 150,
          source: VisionSource.systemAi,
        ),
      ];
      expect(buildFoodReviewPrompt(found), contains(rice.namePt));
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
      expect(result.note, 'systemFailed');
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
      expect(result.note, isNull);
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
