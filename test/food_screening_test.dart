import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_screening.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/portion_estimate.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

DetectedFood item(String label, {String? where, FoodRef? food}) => DetectedFood(
  label: label,
  grams: 100,
  source: VisionSource.systemAi,
  food: food,
  where: where,
  needsChoice: food == null && genericKindOf(label) != null,
);

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  group('normalisation', () {
    test('lower case, no accents, punctuation as spaces', () {
      expect(normaliseFoodName('Chávena de café!'), 'chavena de cafe');
      expect(normaliseFoodName('  Sanduíche  '), 'sanduiche');
      expect(normaliseFoodName('Taça'), 'taca');
    });
  });

  group('non-food filter', () {
    test('every listed Portuguese and English object is dropped', () {
      const words = [
        'toalha',
        'guardanapo',
        'prato',
        'copo',
        'chavena',
        'garrafa',
        'lata',
        'talher',
        'garfo',
        'faca',
        'colher',
        'mesa',
        'toalhete',
        'papel',
        'lenco',
        'caixa',
        'menu',
        'ementa',
        'recibo',
        'talao',
        'saco',
        'embalagem',
        'tabuleiro',
        'frigideira',
        'panela',
        'tacho',
        'tabua',
        'base',
        'individual',
        'napkin',
        'towel',
        'plate',
        'glass',
        'cup',
        'bottle',
        'can',
        'fork',
        'knife',
        'spoon',
        'table',
        'paper',
        'box',
        'menu',
        'receipt',
        'bag',
        'pan',
      ];
      for (final word in words) {
        expect(isNonFoodName(word), isTrue, reason: word);
      }
    });

    test('accents and articles do not matter', () {
      expect(isNonFoodName('Toalha de mesa'), isTrue);
      expect(isNonFoodName('Guardanapo de papel'), isTrue);
      expect(isNonFoodName('Chávena'), isTrue);
    });

    test('a container with contents or a food is kept', () {
      expect(isNonFoodName('Copo de água'), isFalse);
      expect(isNonFoodName('Garrafa de vinho'), isFalse);
      expect(isNonFoodName('Base de tomate'), isFalse);
      expect(isNonFoodName('Tábua de queijos'), isFalse);
      expect(isNonFoodName('Pão torrado'), isFalse);
      expect(isNonFoodName('Café expresso'), isFalse);
    });

    test('dropped names are returned for diagnostics', () {
      final split = dropNonFood([
        item('Sanduíche'),
        item('Toalha'),
        item('Guardanapo'),
      ]);
      expect(split.kept.map((f) => f.label), ['Sanduíche']);
      expect(split.dropped, ['Toalha', 'Guardanapo']);
    });
  });

  group('generic names', () {
    test('generic words need a choice and have no database match', () {
      for (final name in [
        'Bebida',
        'Comida',
        'Refeição',
        'Sanduíche',
        'Sandes',
        'Molho',
        'Carne',
        'Peixe',
        'Fruta',
        'Sobremesa',
        'Drink',
        'Food',
        'Sauce',
        'Meat',
      ]) {
        expect(genericKindOf(name), isNotNull, reason: name);
      }
      expect(genericKindOf('uma bebida'), GenericKind.drink);
      expect(genericKindOf('Carne picada'), isNull);
      expect(genericKindOf('Sanduíche de atum'), isNull);
    });

    test('a generic name is kept in the review even without a where', () {
      final decision = decideDraft([item('Bebida')], verdicts: [true]);
      expect(decision.foods.single.needsChoice, isTrue);
      expect(decision.suggestions, isEmpty);
    });
  });

  group('drinks need container evidence', () {
    test('container words in the where text', () {
      for (final where in [
        'cup top-left',
        'copo no canto',
        'chávena à direita',
        'caneca',
        'garrafa',
        'lata',
        'taça',
        'jarro',
        'mug',
        'glass',
        'bottles',
      ]) {
        expect(mentionsContainer(where), isTrue, reason: where);
      }
    });

    test('no container word, or a word that only contains one', () {
      expect(mentionsContainer(null), isFalse);
      expect(mentionsContainer('top right'), isFalse);
      expect(mentionsContainer('canto da mesa'), isFalse);
      expect(mentionsContainer('cantina'), isFalse);
    });

    test('a beer without a container is a suggestion, with one it stays', () {
      final beerNoContainer = item('Cerveja', where: 'top right');
      final beerInGlass = item('Cerveja', where: 'glass, centre');
      final decision = decideDraft([beerNoContainer, beerInGlass]);
      expect(decision.foods.single.where, 'glass, centre');
      expect(decision.suggestions.single.where, 'top right');
    });

    test('the drink rule also uses the database category', () {
      final juice =
          db.byKey('orange_juice') ??
          db.foods.firstWhere((f) => f.category == 'bebidas');
      final drinkByCategory = DetectedFood(
        label: 'Sumo',
        grams: 200,
        source: VisionSource.systemAi,
        food: juice,
        where: 'on the table',
      );
      expect(isDrinkItem(drinkByCategory), isTrue);
      expect(decideDraft([drinkByCategory]).suggestions, hasLength(1));
    });
  });

  group('verification trust', () {
    test('an omitted verdict goes to suggestions; a false one is dropped', () {
      final decision = decideDraft(
        [
          item('Pão', where: 'plate'),
          item('Queijo', where: 'plate'),
          item('X', where: 'plate'),
        ],
        verdicts: [true, null, false],
      );
      expect(decision.foods.map((f) => f.label), ['Pão']);
      expect(decision.suggestions.map((f) => f.label), ['Queijo']);
      expect(decision.confirmedEmpty, isFalse);
    });

    test('every item explicitly rejected is a confirmed empty meal', () {
      final decision = decideDraft(
        [item('Pão', where: 'plate')],
        verdicts: [false],
      );
      expect(decision.foods, isEmpty);
      expect(decision.suggestions, isEmpty);
      expect(decision.confirmedEmpty, isTrue);
    });

    test('unparsed verification keeps the first list', () {
      final decision = decideDraft([item('Pão', where: 'plate')]);
      expect(decision.foods, hasLength(1));
      expect(decision.confirmedEmpty, isFalse);
    });
  });

  group('whole dishes', () {
    test('a whole pizza is never shrunk below one serving', () {
      final pizza = db.byKey('pizza_cheese')!;
      final units = pizza.portionUnits ?? 1;
      expect(
        estimatedGrams(
          food: pizza,
          count: units.round(),
          size: PortionSize.small,
        ),
        estimatedGrams(food: pizza, count: units.round()),
      );
      expect(
        estimatedGrams(food: pizza, size: PortionSize.large),
        closeTo(pizza.portionG * 1.5, 1),
      );
      expect(
        estimatedGrams(food: pizza, size: PortionSize.large),
        isNot(closeTo(pizza.portionG, 1)),
      );
    });

    test('a burger is a whole dish; a side is still scaled down', () {
      final burger = db.byKey('beef_ground_patty');
      if (burger != null) {
        expect(isWholeDish(burger), isTrue);
        expect(
          estimatedGrams(food: burger, size: PortionSize.small),
          closeTo(burger.portionG, 1),
        );
      }
      final rice = db.byKey('rice_white_cooked')!;
      expect(isWholeDish(rice), isFalse);
      expect(
        estimatedGrams(food: rice, size: PortionSize.small),
        closeTo(rice.portionG * 0.6, 1),
      );
    });
  });

  group('failure kind from model errors', () {
    test('busy and quota errors', () {
      expect(
        VisionFailure.fromError(
          'LlmException(generation_failed: quota exceeded)',
        ),
        VisionFailure.busy,
      );
      expect(
        VisionFailure.fromError(Exception('Service is busy')),
        VisionFailure.busy,
      );
    });

    test('unsupported or unavailable', () {
      expect(
        VisionFailure.fromError('feature unsupported on this device'),
        VisionFailure.unavailable,
      );
      expect(
        VisionFailure.fromError('LlmException(unavailable)'),
        VisionFailure.unavailable,
      );
    });

    test('anything else is other', () {
      expect(VisionFailure.fromError('boom'), VisionFailure.other);
      expect(VisionFailure.fromError(null), VisionFailure.other);
    });
  });

  group('pipeline keeps the offline result and says why the system failed', () {
    final photo = Uint8List.fromList(
      img.encodePng(img.Image(width: 64, height: 64)),
    );

    test(
      'system busy, offline empty: failure busy, not confirmed empty',
      () async {
        final pipeline = FoodVisionPipeline(
          llm: const _Llm(LlmStatus.available),
          system: const _Fails(
            LlmException('generation_failed: quota exceeded'),
          ),
          regions: const _Fixed(
            const FoodVisionResult(
              foods: [],
              source: VisionSource.regionClassifier,
            ),
          ),
        );
        final result = await pipeline.analyse(photo);
        expect(result.foods, isEmpty);
        expect(result.confirmedEmpty, isFalse);
        expect(result.failure, VisionFailure.busy);
        expect(result.notes, contains('systemFailed'));
      },
    );

    test(
      'model unavailable: failure unavailable with offline foods kept',
      () async {
        final pipeline = FoodVisionPipeline(
          llm: const _Llm(LlmStatus.unavailable),
          system: const _Fails(LlmException('unavailable')),
          regions: _Fixed(
            FoodVisionResult(
              foods: [
                DetectedFood(
                  label: 'Arroz',
                  grams: 100,
                  source: VisionSource.regionClassifier,
                  food: db.byKey('rice_white_cooked'),
                ),
              ],
              source: VisionSource.regionClassifier,
            ),
          ),
        );
        final result = await pipeline.analyse(photo);
        expect(result.foods, hasLength(1));
        expect(result.failure, VisionFailure.unavailable);
      },
    );
  });
}

class _Llm implements OnDeviceLlm {
  const _Llm(this._status);
  final LlmStatus _status;

  @override
  Future<LlmStatus> status() async => _status;

  @override
  Future<LlmStatus> download() async => _status;

  @override
  Future<String> generate(String prompt) async => '';
}

class _Fails implements FoodVisionService {
  const _Fails(this.error);
  final Object error;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async => throw error;
}

class _Fixed implements FoodVisionService {
  const _Fixed(this.result);
  final FoodVisionResult result;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async => result;
}
