import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/photo_quality.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';
import 'package:vyro/features/nutrition/widgets/photo_region_sheet.dart';

class _Llm implements OnDeviceLlm {
  @override
  Future<LlmStatus> status() async => LlmStatus.available;
  @override
  Future<LlmStatus> download() => status();
  @override
  Future<String> generate(String prompt) async => '';
}

class _Vision implements FoodVisionService {
  _Vision(this.value, {this.fail = false});
  final FoodVisionResult value;
  final bool fail;
  @override
  Future<FoodVisionResult> analyse(Uint8List bytes) async {
    if (fail) throw StateError('classifier failed');
    return value;
  }
}

void main() {
  test(
    'selected region uses original image coordinates and preserves the source',
    () {
      final image = img.Image(width: 200, height: 100);
      final bytes = Uint8List.fromList(img.encodePng(image));
      final cropped = img.decodeImage(cropPhotoRegion((bytes, [.5, 0, 1, 1])))!;
      expect(cropped.width, 100);
      expect(cropped.height, 100);
      expect(img.decodeImage(bytes)!.width, 200);
    },
  );
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  final photo = Uint8List.fromList(
    img.encodePng(img.Image(width: 128, height: 128)),
  );
  final coffee = DetectedFood(
    food: db.byKey('espresso'),
    label: 'Café',
    grams: 30,
    source: VisionSource.regionClassifier,
  );
  final regions = FoodVisionResult(
    foods: [coffee],
    source: VisionSource.regionClassifier,
  );
  test('piece counts use the units in a typical portion', () {
    final result = parseFoodPhotoAnswer(
      '{"items":[{"name":"Sardinha assada","count":3,"size":"medium"}]}',
      db,
    );
    expect(result.single.grams, 120);
    final rice = parseFoodPhotoAnswer(
      '{"items":[{"name":"Arroz branco cozido","count":3}]}',
      db,
    );
    expect(rice.single.grams, db.byKey('rice_white_cooked')!.portionG);
  });
  // Changed in v0.6.5: a confirmed empty photo still shows offline hypotheses,
  // but only as suggestions ("Outras hipóteses"), never in the main list.
  test(
    'a confirmed empty review keeps offline hypotheses as suggestions',
    () async {
      final result = await FoodVisionPipeline(
        llm: _Llm(),
        system: _Vision(
          const FoodVisionResult(
            foods: [],
            source: VisionSource.systemAi,
            confirmedEmpty: true,
            detail: 'draft\n---\nreview',
          ),
        ),
        regions: _Vision(regions),
      ).analyse(photo);
      expect(result.foods, isEmpty);
      expect(result.confirmedEmpty, isTrue);
      expect(result.suggestions.single, coffee);
      expect(result.notes, contains('fusedOffline'));
    },
  );
  test(
    'fast offline failure preserves a valid system answer without unhandled errors',
    () async {
      final result = await FoodVisionPipeline(
        llm: _Llm(),
        system: _Vision(regions),
        regions: _Vision(regions, fail: true),
      ).analyse(photo);
      expect(result.foods.single, coffee);
    },
  );
  test('two failures report total failure', () async {
    await expectLater(
      FoodVisionPipeline(
        llm: _Llm(),
        system: _Vision(regions, fail: true),
        regions: _Vision(regions, fail: true),
      ).analyse(photo),
      throwsA(isA<LlmException>()),
    );
  });
  test('offline-only hypotheses stay outside meal totals', () {
    final fused = fuseVisionResults(
      const FoodVisionResult(foods: [], source: VisionSource.systemAi),
      regions,
    );
    expect(fused.foods, isEmpty);
    expect(fused.suggestions.single, coffee);
  });
  test(
    'agreement records provenance without treating scores as probabilities',
    () {
      final fused = fuseVisionResults(regions, regions);
      expect(fused.foods.single.corroborated, true);
      expect(fused.source, VisionSource.fused);
    },
  );
  test('smooth gradient warns of low detail', () {
    final image = img.Image(width: 128, height: 128);
    for (var y = 0; y < 128; y++) {
      for (var x = 0; x < 128; x++) {
        image.setPixelRgb(x, y, x * 2, x * 2, x * 2);
      }
    }
    expect(assessPhoto(image).tooBlurry, true);
  });
}
