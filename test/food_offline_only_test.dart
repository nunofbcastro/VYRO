import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/region_food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

/// Offline results must never reach the main list when the phone's model gave
/// no usable answer. Reason (offline eval, 50 Nutrition5k photos, regions only):
/// precision 0.28, recall 0.06, 21 false positives. Real device: a photo of a
/// wooden ball came back as "Alface" (50 g) in the main list.
void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  final photo = Uint8List.fromList(
    img.encodePng(img.Image(width: 64, height: 64)),
  );
  // AIY label indices used below (the real CSV has "__background__" at 0).
  const labels = {
    0: '__background__',
    1: 'Greek salad', // lettuce_raw
    2: 'White rice', // rice_white_cooked
  };
  final lettuce = db.byKey('lettuce_raw')!;
  final espresso = db.byKey('espresso')!;
  // "Greek salad" maps to four foods in the full database (lettuce, cucumber,
  // green salad, tomato). A two-food database isolates the lettuce case.
  final small = FoodDatabase([lettuce, db.byKey('rice_white_cooked')!]);

  /// Offline result for a photo where lettuce shows in all 26 regions.
  FoodVisionResult lettuceOffline() =>
      RegionFoodVision.interpretRegions(small, [
        for (var i = 0; i < 26; i++) [(1, 0.3)],
      ], labels);

  /// Offline result for a photo where background wins in every region.
  FoodVisionResult backgroundOffline() =>
      RegionFoodVision.interpretRegions(small, [
        for (var i = 0; i < 26; i++) [(0, 0.6), (1, 0.3)],
      ], labels);

  double kcal(List<DetectedFood> foods) =>
      foods.fold(0, (sum, f) => sum + (f.kcal ?? 0));

  group('interpretRegions non-food gate and suggestion floor', () {
    test('the Alface regression: lettuce in every region is a hypothesis', () {
      final result = lettuceOffline();
      expect(result.foods.single.food?.key, lettuce.key);
      expect(result.foods.single.grams, lettuce.portionG);
      expect(result.notes, isEmpty);
    });

    test('background winning on most regions returns no food at all', () {
      final result = backgroundOffline();
      expect(result.foods, isEmpty);
      expect(result.suggestions, isEmpty);
      expect(result.notes, contains(offlineNoFoodNote));
      expect(result.detail, contains('background wins in 26 of 26'));
    });

    test('background on exactly half the regions still keeps the food', () {
      // 13 of 26 is not "most": the gate needs more than half.
      final perCrop = [
        for (var i = 0; i < 13; i++) [(0, 0.6), (1, 0.3)],
        for (var i = 0; i < 13; i++) [(1, 0.3)],
      ];
      final result = RegionFoodVision.interpretRegions(small, perCrop, labels);
      expect(result.foods.single.food?.key, lettuce.key);
      expect(result.notes, isEmpty);
    });

    test('a food below the minimum peak is not even a suggestion', () {
      final result = RegionFoodVision.interpretRegions(small, [
        for (var i = 0; i < 26; i++) [(1, 0.12)],
      ], labels);
      expect(result.foods, isEmpty);
      expect(result.notes, isEmpty);
    });

    test('a food seen in only one region is not kept (minimum regions)', () {
      final result = RegionFoodVision.interpretRegions(small, [
        [(1, 0.5)],
        for (var i = 0; i < 25; i++) [(0, 0.01), (2, 0.5)],
      ], labels);
      expect(result.foods.map((f) => f.food?.key), ['rice_white_cooked']);
    });
  });

  group('pipeline: system model failed or unavailable', () {
    FoodVisionPipeline pipeline({
      required LlmStatus status,
      required FoodVisionService system,
      required FoodVisionService regions,
    }) =>
        FoodVisionPipeline(llm: _Llm(status), system: system, regions: regions);

    test(
      '(a) system fails, offline returns Alface: foods empty, Alface is a suggestion',
      () async {
        final result = await pipeline(
          status: LlmStatus.available,
          system: _Fixed(error: const LlmException('generation_failed: boom')),
          regions: _Fixed(value: lettuceOffline()),
        ).analyse(photo);
        expect(result.foods, isEmpty);
        expect(result.suggestions.map((s) => s.food?.key), [lettuce.key]);
        expect(result.failure, VisionFailure.other);
        expect(result.notes, contains('systemFailed'));
        expect(result.source, VisionSource.regionClassifier);
        expect(result.confirmedEmpty, isFalse);
        // Nothing in the totals: the CTA stays at zero.
        expect(kcal(result.foods), 0);
      },
    );

    test(
      '(b) system unavailable on the device: same, failure unavailable',
      () async {
        final result = await pipeline(
          status: LlmStatus.unavailable,
          system: _Fixed(value: lettuceOffline()),
          regions: _Fixed(value: lettuceOffline()),
        ).analyse(photo);
        expect(result.foods, isEmpty);
        expect(result.suggestions.map((s) => s.food?.key), [lettuce.key]);
        expect(result.failure, VisionFailure.unavailable);
        expect(result.notes, isNot(contains('systemFailed')));
        expect(kcal(result.foods), 0);
      },
    );

    test(
      'system still downloading: failure busy, offline only as suggestions',
      () async {
        final result = await pipeline(
          status: LlmStatus.downloading,
          system: _Fixed(value: lettuceOffline()),
          regions: _Fixed(value: lettuceOffline()),
        ).analyse(photo);
        expect(result.foods, isEmpty);
        expect(result.suggestions, hasLength(1));
        expect(result.failure, VisionFailure.busy);
      },
    );

    test(
      'text-only system bridge (MissingPluginException) is unavailable',
      () async {
        final result = await pipeline(
          status: LlmStatus.available,
          system: _Fixed(error: MissingPluginException()),
          regions: _Fixed(value: lettuceOffline()),
        ).analyse(photo);
        expect(result.foods, isEmpty);
        expect(result.suggestions, hasLength(1));
        expect(result.failure, VisionFailure.unavailable);
        expect(result.notes, isNot(contains('systemFailed')));
      },
    );

    test(
      '(c) background wins offline and the system failed: no suggestions, says no food',
      () async {
        final result = await pipeline(
          status: LlmStatus.available,
          system: _Fixed(error: const LlmException('generation_failed: boom')),
          regions: _Fixed(value: backgroundOffline()),
        ).analyse(photo);
        expect(result.foods, isEmpty);
        expect(result.suggestions, isEmpty);
        expect(result.failure, VisionFailure.other);
        expect(result.notes, containsAll(['systemFailed', offlineNoFoodNote]));
      },
    );

    test(
      'two failures still throw, so the page shows the error card',
      () async {
        await expectLater(
          pipeline(
            status: LlmStatus.available,
            system: _Fixed(error: const LlmException('x')),
            regions: _Fixed(error: const LlmException('y')),
          ).analyse(photo),
          throwsA(isA<LlmException>()),
        );
      },
    );
  });

  group('pipeline: system model succeeded (unchanged)', () {
    test(
      '(d) system foods stay in the list, offline foods are suggestions',
      () async {
        final system = FoodVisionResult(
          source: VisionSource.systemAi,
          foods: [
            DetectedFood(
              food: espresso,
              label: espresso.namePt,
              grams: espresso.portionG,
              source: VisionSource.systemAi,
            ),
          ],
        );
        final result = await FoodVisionPipeline(
          llm: _Llm(LlmStatus.available),
          system: _Fixed(value: system),
          regions: _Fixed(value: lettuceOffline()),
        ).analyse(photo);
        // Both sides have foods, so the source is fused (unchanged rule).
        expect(result.source, VisionSource.fused);
        expect(result.failure, isNull);
        expect(result.foods.map((f) => f.food?.key), [espresso.key]);
        expect(result.suggestions.map((s) => s.food?.key), [lettuce.key]);
        expect(result.notes, contains('fusedOffline'));
        expect(result.notes, isNot(contains('systemFailed')));
      },
    );

    test(
      'a confirmed empty system answer keeps offline as suggestions only',
      () async {
        final result = await FoodVisionPipeline(
          llm: _Llm(LlmStatus.available),
          system: _Fixed(
            value: const FoodVisionResult(
              foods: [],
              source: VisionSource.systemAi,
              confirmedEmpty: true,
            ),
          ),
          regions: _Fixed(value: lettuceOffline()),
        ).analyse(photo);
        expect(result.foods, isEmpty);
        expect(result.confirmedEmpty, isTrue);
        expect(result.suggestions.map((s) => s.food?.key), [lettuce.key]);
      },
    );
  });

  group('offlineHypothesesOnly', () {
    test('moves foods to suggestions, de-duplicated, and keeps the detail', () {
      final offline = FoodVisionResult(
        source: VisionSource.regionClassifier,
        foods: [
          DetectedFood(
            food: lettuce,
            label: 'Alface',
            grams: 50,
            source: VisionSource.regionClassifier,
          ),
        ],
        suggestions: [
          DetectedFood(
            food: lettuce,
            label: 'Alface',
            grams: 50,
            source: VisionSource.regionClassifier,
          ),
        ],
        detail: 'offlineDish=Greek salad',
      );
      final result = offlineHypothesesOnly(
        offline,
        failure: VisionFailure.unavailable,
        detail: 'boom',
      );
      expect(result.foods, isEmpty);
      expect(result.suggestions, hasLength(1));
      expect(result.failure, VisionFailure.unavailable);
      expect(result.detail, 'boom\nofflineDish=Greek salad');
      expect(result.notes, isEmpty);
    });
  });
}

class _Llm implements OnDeviceLlm {
  _Llm(this._status);
  final LlmStatus _status;

  @override
  Future<LlmStatus> status() async => _status;

  @override
  Future<LlmStatus> download() async => _status;

  @override
  Future<String> generate(String prompt) async => '';
}

class _Fixed implements FoodVisionService {
  _Fixed({this.value, this.error});
  final FoodVisionResult? value;
  final Object? error;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async {
    if (error != null) throw error!;
    return value!;
  }
}
