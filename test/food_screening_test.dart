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
      expect(decision.decisions.single.action, ItemAction.kept);
    });
  });

  group('drinks: container words are evidence in the reason, not a gate', () {
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

    // Regression (v0.6.3 removed true positives): a beer without container
    // words used to go to suggestions. Drinks are now kept like food; the
    // reason line says whether the location names a container.
    test('a beer stays in the main list with or without a container', () {
      final beerNoContainer = item('Cerveja', where: 'top right');
      final beerInGlass = item('Cerveja', where: 'glass, centre');
      final decision = decideDraft([beerNoContainer, beerInGlass]);
      expect(decision.foods.map((f) => f.where), [
        'top right',
        'glass, centre',
      ]);
      expect(decision.decisions[0].reason, contains('drink, no container'));
      expect(decision.decisions[1].reason, contains('drink, container'));
    });

    test('a drink by database category is kept with no container', () {
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
      final decision = decideDraft([drinkByCategory]);
      expect(decision.foods, hasLength(1));
      expect(decision.decisions.single.action, ItemAction.kept);
    });
  });

  group('where is evidence, never a gate', () {
    test('items without where stay in the main list', () {
      final decision = decideDraft(
        [item('Hambúrguer'), item('Cerveja'), item('Pão', where: '')],
        verdicts: [true, true, true],
      );
      expect(decision.foods, hasLength(3));
      expect(
        decision.decisions.map((d) => d.reason),
        everyElement(contains('no where')),
      );
    });

    test('a location written as prose does not remove a food', () {
      final decision = decideDraft(
        [item('Cerveja', where: 'on the table, right')],
        verdicts: [true],
      );
      expect(decision.foods.single.label, 'Cerveja');
      expect(decision.decisions.single.reason, contains('verify=true'));
    });
  });

  group('verification trust', () {
    // Regression: an omitted verdict used to send the item to suggestions.
    // It now stays in the main list as uncertain ("Hipótese a confirmar").
    test('an omitted verdict keeps the item as uncertain; false drops it', () {
      final decision = decideDraft(
        [
          item('Pão', where: 'plate'),
          item('Queijo', where: 'plate'),
          item('X', where: 'plate'),
        ],
        verdicts: [true, null, false],
      );
      expect(decision.foods.map((f) => f.label), ['Pão', 'Queijo']);
      expect(
        decision.decisions[1].reason,
        contains('verify omitted, uncertain'),
      );
      expect(decision.decisions[2].action, ItemAction.dropped);
      expect(decision.decisions[2].reason, 'verify=false');
    });

    // (b) One false among several: only that item is dropped.
    test('one false among several drops only that item', () {
      final decision = decideDraft(
        [item('Bife'), item('Ovo'), item('Batata')],
        verdicts: [true, false, true],
      );
      expect(decision.foods.map((f) => f.label), ['Bife', 'Batata']);
      expect(decision.decisions[1].action, ItemAction.dropped);
      expect(decision.decisions[1].reason, 'verify=false');
    });

    // (a) Regression (v0.6.4 real device: a steak in a pan showed an empty
    // review). Verification that rejects every item no longer empties a
    // non-empty draft: all items stay as uncertain.
    test('every item rejected by verification is kept as uncertain', () {
      final decision = decideDraft(
        [item('Bife', where: 'pan centre'), item('Ovo')],
        verdicts: [false, false],
      );
      expect(decision.foods.map((f) => f.label), ['Bife', 'Ovo']);
      expect(
        decision.decisions.map((d) => d.action),
        everyElement(ItemAction.kept),
      );
      expect(
        decision.decisions.map((d) => d.reason),
        everyElement(contains('verify rejected all — kept as uncertain')),
      );
    });

    test('a single rejected item is also kept as uncertain', () {
      final decision = decideDraft([item('Café')], verdicts: [false]);
      expect(decision.foods, hasLength(1));
      expect(
        decision.decisions.single.reason,
        contains('verify rejected all — kept as uncertain'),
      );
    });

    test('unparsed verification keeps the whole first list', () {
      final decision = decideDraft([
        item('Pão', where: 'plate'),
        item('Cerveja'),
      ]);
      expect(decision.foods, hasLength(2));
      expect(decision.decisions.first.reason, contains('verify unparsed'));
    });

    // (e) The non-food filter looks at the item NAME only. A steak whose
    // location says "na frigideira" (in the pan) is food.
    test('a food named bife with a pan in where is not a non-food', () {
      final steak = item('Bife', where: 'na frigideira, centro');
      expect(isNonFoodName('Bife'), isFalse);
      expect(isNonFoodName('Bife de vaca na frigideira'), isFalse);
      final split = dropNonFood([steak, item('Frigideira')]);
      expect(split.kept.map((f) => f.label), ['Bife']);
      expect(split.dropped, ['Frigideira']);
    });

    test(
      'a verdict list shorter than the items treats the rest as omitted',
      () {
        final decision = decideDraft(
          [item('Pão'), item('Manteiga')],
          verdicts: [true],
        );
        expect(decision.foods, hasLength(2));
        expect(decision.decisions[1].reason, contains('verify omitted'));
      },
    );
  });

  group('diagnostic lines', () {
    test('decisionLine names the item, the action and the reason', () {
      expect(
        decisionLine('cerveja', ItemAction.kept, 'verify=true'),
        'cerveja → kept (verify=true)',
      );
      expect(
        decisionLine('toalha', ItemAction.dropped, 'non-food'),
        'toalha → dropped (non-food)',
      );
      expect(
        decisionLine('café', ItemAction.suggestion, 'duplicate coffee'),
        'café → suggestion (duplicate coffee)',
      );
    });
  });

  group('whole dishes', () {
    test('a whole pizza is one item: size does not scale it, count does', () {
      final whole = db.byKey('pizza_cheese_whole')!;
      expect(whole.portionUnits, 1);
      expect(isWholeDish(whole), isTrue);
      // The model's {"name":"pizza","count":1,"size":"large"} -> one pizza.
      expect(
        estimatedGrams(food: whole, count: 1, size: PortionSize.large),
        whole.portionG,
      );
      expect(
        estimatedGrams(food: whole, count: 1, size: PortionSize.small),
        whole.portionG,
      );
      expect(estimatedGrams(food: whole, count: 2), whole.portionG * 2);
      expect(whole.portionG, inInclusiveRange(300, 400));
    });

    test('slices are scaled by count and size, not treated as whole', () {
      final slice = db.match('fatia de pizza')!;
      expect(slice.key, 'pizza_cheese');
      expect(isWholeDish(slice), isFalse);
      // {"name":"fatia de pizza","count":2} -> two slices.
      expect(estimatedGrams(food: slice, count: 2), slice.portionG * 2);
      expect(
        estimatedGrams(food: slice, size: PortionSize.large),
        closeTo(slice.portionG * 1.5, 1),
      );
      expect(
        estimatedGrams(food: slice, size: PortionSize.small),
        closeTo(slice.portionG * 0.6, 1),
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
      // Changed in v0.6.8: offline foods are suggestions only when the phone's
      // model gives no answer; they were in the main list before. Offline
      // precision was 0.28 on 50 photos (see docs/FOOD_VISION.md).
      'model unavailable: failure unavailable, offline foods only as suggestions',
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
        expect(result.foods, isEmpty);
        expect(result.suggestions, hasLength(1));
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
