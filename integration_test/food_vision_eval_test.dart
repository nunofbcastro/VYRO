/// On-device food vision evaluation: the phone's own model (Gemini Nano via
/// AICore) through the real `vyro/on_device_llm` channel, scored with the same
/// code as the host harness (`tool/eval/scoring.dart`).
///
/// Photos and labels are read from the app's external files folder (push them
/// with adb, see eval/README.md):
///   /sdcard/Android/data/com.nunofbcastro.vyro/files/eval/labels.json
///   /sdcard/Android/data/com.nunofbcastro.vyro/files/eval/photos/<file>
///
/// Strategy (only the ones the phone can run as shipped):
///   flutter test integration_test/food_vision_eval_test.dart -d <device> \
///     --dart-define=VYRO_EVAL_STRATEGY=pipeline
/// `pipeline` (default), `system_only` or `regions_only`.
///
/// The summary is printed to the log (`adb logcat -s flutter`) between
/// `VYRO_EVAL_RESULT_BEGIN` and `VYRO_EVAL_RESULT_END`, and written to
/// `.../eval/results/` on the phone.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/region_food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

import '../tool/eval/report.dart';
import '../tool/eval/scoring.dart';

const _evalDir = '/sdcard/Android/data/com.nunofbcastro.vyro/files/eval';
const _strategy = String.fromEnvironment(
  'VYRO_EVAL_STRATEGY',
  defaultValue: 'pipeline',
);

String _timestamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('on-device food vision evaluation', () async {
    final labelsFile = File('$_evalDir/labels.json');
    expect(
      labelsFile.existsSync(),
      isTrue,
      reason: 'push eval/labels.json to $_evalDir (see eval/README.md)',
    );
    final labels = parseLabels(labelsFile.readAsStringSync());
    final db = FoodDatabase.parse(
      await rootBundle.loadString('assets/nutrition/foods.json'),
    );

    final present = [
      for (final entry in labels)
        if (File('$_evalDir/photos/${entry.file}').existsSync()) entry,
    ];
    for (final entry in labels) {
      if (!present.contains(entry)) {
        debugPrint('VYRO_EVAL skipped (no photo): ${entry.file}');
      }
    }
    expect(present, isNotEmpty, reason: 'no photo in $_evalDir/photos');

    const llm = PlatformOnDeviceLlm();
    final system = SystemFoodVision(db);
    final regions = RegionFoodVision(db);
    final pipeline = FoodVisionPipeline(
      llm: llm,
      system: system,
      regions: regions,
    );
    final status = await llm.status();
    debugPrint('VYRO_EVAL on-device llm status: ${status.name}');

    final scores = <ImageScore>[];
    for (final entry in present) {
      final Uint8List bytes = await File(
        '$_evalDir/photos/${entry.file}',
      ).readAsBytes();
      final watch = Stopwatch()..start();
      FoodVisionResult? result;
      String? error;
      try {
        result = switch (_strategy) {
          'pipeline' => await pipeline.analyse(bytes),
          'system_only' => await system.analyse(bytes),
          'regions_only' => await regions.analyse(bytes),
          _ => throw ArgumentError('unknown on-device strategy $_strategy'),
        };
      } catch (e) {
        error = '$e';
      }
      watch.stop();
      final foods = result?.foods ?? const <DetectedFood>[];
      final score = scoreImage(
        file: entry.file,
        labels: entry.foods,
        predicted: [
          for (final f in foods) Prediction(name: f.label, key: f.food?.key),
        ],
        latencyMs: watch.elapsedMicroseconds / 1000,
        error: error,
        suggestions: [
          for (final f in result?.suggestions ?? const <DetectedFood>[])
            f.label,
        ],
        notes: result == null
            ? ''
            : 'source ${result.source.name}, failure ${result.failure?.name ?? '-'}, '
                  'note ${result.note ?? '-'}',
        appDetail: result?.detail,
      );
      scores.add(score);
      debugPrint(
        'VYRO_EVAL ${entry.file}: ${score.tp} TP, ${score.fp} FP, '
        '${score.fn} FN${error == null ? '' : ' error: $error'}',
      );
    }

    final summary = EvalSummary.of(scores);
    final meta = <String, Object?>{
      'timestamp': _timestamp(DateTime.now()),
      'strategy': 'on_device_$_strategy',
      'model': 'on-device (AICore / Gemini Nano)',
      'llm_status': status.name,
      'photos': present.length,
      'host': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    };
    final json = const JsonEncoder.withIndent('  ').convert({
      'meta': meta,
      'summary': summary.toJson(),
      'images': [for (final s in scores) s.toJson()],
    });
    final md = runMarkdown(meta: meta, images: scores);
    try {
      final dir = Directory('$_evalDir/results')..createSync(recursive: true);
      final base = '${dir.path}/${meta['timestamp']}_on_device_$_strategy';
      File('$base.json').writeAsStringSync(json);
      File('$base.md').writeAsStringSync(md);
      debugPrint('VYRO_EVAL wrote $base.json and $base.md');
    } catch (e) {
      debugPrint('VYRO_EVAL could not write results to the phone: $e');
    }
    debugPrint('VYRO_EVAL_RESULT_BEGIN');
    debugPrint(json);
    debugPrint('VYRO_EVAL_RESULT_END');
    debugPrint(summaryConsoleTable([('on_device_$_strategy', summary)]));
  }, timeout: const Timeout(Duration(hours: 2)));
}
