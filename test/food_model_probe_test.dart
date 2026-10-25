import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/region_food_vision.dart';

/// Runs the real bundled classifier through [RegionFoodVision] (the offline
/// fallback of the photo flow) on a local image. Only on Windows/macOS/Linux
/// hosts with VYRO_FOOD_IMAGE set, e.g.
/// `VYRO_FOOD_IMAGE=C:\photos\plate.png flutter test test/food_model_probe_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final path = Platform.environment['VYRO_FOOD_IMAGE'];
  test(
    'region classifier maps a sample photo to database foods',
    () async {
      final bytes = await File(path!).readAsBytes();
      final db = FoodDatabase.parse(
        File('assets/nutrition/foods.json').readAsStringSync(),
      );
      final result = await RegionFoodVision(db).analyse(bytes);
      // ignore: avoid_print
      print('dish: ${result.dishGuess}');
      // ignore: avoid_print
      print([
        for (final f in result.foods)
          '${f.label} ${((f.confidence ?? 0) * 100).toStringAsFixed(1)}% '
              '${f.grams.round()} g ${f.kcal?.round()} kcal',
      ]);
      expect(result.dishGuess, isNotNull);
    },
    skip: path == null || !File(path).existsSync()
        ? 'Set VYRO_FOOD_IMAGE to a local photo to run'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
