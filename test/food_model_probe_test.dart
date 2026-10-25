import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/domain/food_recognition_service.dart';

/// Runs the real bundled model through [LiteRtFoodRecognitionService] on a
/// local image. Only on Windows/macOS/Linux hosts with VYRO_FOOD_IMAGE set,
/// e.g. `VYRO_FOOD_IMAGE=C:\photos\plate.png flutter test test/food_model_probe_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final path = Platform.environment['VYRO_FOOD_IMAGE'];
  test(
    'real model returns candidates for a sample photo',
    () async {
      final bytes = await File(path!).readAsBytes();
      final candidates = await LiteRtFoodRecognitionService().recognize(bytes);
      // ignore: avoid_print
      print([
        for (final c in candidates)
          '${c.label} ${(c.confidence * 100).toStringAsFixed(1)}%',
      ]);
      expect(candidates, isNotEmpty);
    },
    skip: path == null || !File(path).existsSync()
        ? 'Set VYRO_FOOD_IMAGE to a local photo to run'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
