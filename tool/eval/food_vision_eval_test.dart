/// Offline food-vision evaluation on the host (no device needed).
///
/// Runs the app's REAL food-vision code (`SystemFoodVision`,
/// `FoodVisionPipeline`, `RegionFoodVision`) on the photos in `eval/photos/`,
/// with the `vyro/on_device_llm` channel answered by a local Ollama model, and
/// scores the predicted foods against `eval/labels.json`.
///
/// Skipped unless VYRO_EVAL=1. See eval/README.md for the full commands.
///
///   VYRO_EVAL=1 VYRO_EVAL_MODEL=gemma3n:e4b VYRO_EVAL_STRATEGY=pipeline,no_verify \
///     flutter test tool/eval/food_vision_eval_test.dart
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/region_food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

import 'ollama_client.dart';
import 'report.dart';
import 'scoring.dart';
import 'variants.dart';

const _channelName = 'vyro/on_device_llm';

/// Temperature of the self-consistency samples (the app uses 0.1 for one answer).
const _samplingTemperature = 0.7;

class EvalConfig {
  const EvalConfig({
    required this.dir,
    required this.model,
    required this.temperature,
    required this.maxSide,
    required this.numCtx,
    required this.strategies,
    required this.ollamaUrl,
  });

  /// Folder with `labels.json`, `photos/` and `results/`.
  final String dir;
  final String model;
  final double temperature;

  /// Longest side sent to the model. Null keeps the app's own downscale.
  final int? maxSide;
  final int numCtx;
  final List<String> strategies;
  final String ollamaUrl;

  factory EvalConfig.fromEnvironment(Map<String, String> env) {
    String? get(String key) {
      final value = env[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final temperature = get('VYRO_EVAL_TEMP');
    final maxSide = get('VYRO_EVAL_MAXSIDE');
    final numCtx = get('VYRO_EVAL_NUM_CTX');
    return EvalConfig(
      dir: get('VYRO_EVAL_DIR') ?? 'eval',
      model: get('VYRO_EVAL_MODEL') ?? 'gemma3n:e4b',
      temperature: temperature == null ? 0.1 : double.parse(temperature),
      maxSide: maxSide == null ? null : int.parse(maxSide),
      numCtx: numCtx == null ? 4096 : int.parse(numCtx),
      strategies: expandStrategies(
        (get('VYRO_EVAL_STRATEGY') ?? 'pipeline').split(','),
      ),
      ollamaUrl: get('VYRO_EVAL_OLLAMA_URL') ?? 'http://localhost:11434',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['VYRO_EVAL'] == '1';

  test(
    'offline food vision evaluation',
    () async {
      // flutter_test replaces HttpClient with a mock that refuses requests.
      HttpOverrides.global = null;
      // PlatformOnDeviceLlm only talks to the channel on Android/iOS.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final config = EvalConfig.fromEnvironment(Platform.environment);
      final labelsFile = File('${config.dir}/labels.json');
      expect(labelsFile.existsSync(), isTrue, reason: 'missing $labelsFile');
      final labels = parseLabels(labelsFile.readAsStringSync());
      final db = FoodDatabase.parse(
        File('assets/nutrition/foods.json').readAsStringSync(),
      );
      final keyErrors = validateLabelKeys(labels, {
        for (final f in db.foods) f.key,
      });
      expect(keyErrors, isEmpty, reason: keyErrors.join('\n'));

      final present = <LabelEntry>[];
      for (final entry in labels) {
        if (File('${config.dir}/photos/${entry.file}').existsSync()) {
          present.add(entry);
        } else {
          stdout.writeln('skipped (no photo yet): ${entry.file}');
        }
      }
      expect(
        present,
        isNotEmpty,
        reason: 'no photo in ${config.dir}/photos matches labels.json',
      );

      OllamaClient? ollama;
      String? ollamaVersion;
      if (config.strategies.any((s) => s != 'regions_only')) {
        ollama = OllamaClient(
          baseUrl: Uri.parse(config.ollamaUrl),
          model: config.model,
          numCtx: config.numCtx,
        );
        ollamaVersion = await ollama.version();
      }

      final stamp = _timestamp(DateTime.now());
      final resultsDir = Directory('${config.dir}/results')
        ..createSync(recursive: true);
      const channel = MethodChannel(_channelName);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final runs = <(String, EvalSummary)>[];

      for (final strategy in config.strategies) {
        final runner = _Runner(
          strategy: strategy,
          config: config,
          db: db,
          ollama: ollama,
        );
        messenger.setMockMethodCallHandler(channel, runner.handle);
        final scores = <ImageScore>[];
        try {
          for (final entry in present) {
            final bytes = File(
              '${config.dir}/photos/${entry.file}',
            ).readAsBytesSync();
            runner.beginImage();
            final watch = Stopwatch()..start();
            FoodVisionResult? result;
            String? error;
            try {
              result = await runner.analyse(bytes);
            } catch (e) {
              error = '$e';
            }
            watch.stop();
            scores.add(
              scoreImage(
                file: entry.file,
                labels: entry.foods,
                predicted: [
                  for (final f in result?.foods ?? const <DetectedFood>[])
                    Prediction(name: f.label, key: f.food?.key),
                ],
                latencyMs: watch.elapsedMicroseconds / 1000,
                error: error,
                rawAnswers: List.of(runner.log),
                appDetail: result?.detail,
                suggestions: [
                  for (final f in result?.suggestions ?? const <DetectedFood>[])
                    f.label,
                ],
                notes: result == null
                    ? ''
                    : 'source ${result.source.name}, stage ${result.stage.name}, '
                          'failure ${result.failure?.name ?? '-'}, note '
                          '${result.note ?? '-'}, ${result.timings.isEmpty ? 'no timings' : timingLine(result.timings)}',
              ),
            );
            stdout.writeln(
              '[$strategy] ${entry.file}: ${scores.last.tp} TP, '
              '${scores.last.fp} FP, ${scores.last.fn} FN'
              '${error == null ? '' : ' (error: $error)'}',
            );
          }
        } finally {
          messenger.setMockMethodCallHandler(channel, null);
        }

        final summary = EvalSummary.of(scores);
        final base =
            '${resultsDir.path}/${stamp}_${_safe(config.model)}_$strategy';
        final meta = <String, Object?>{
          'timestamp': stamp,
          'strategy': strategy,
          'model': config.model,
          'temperature': config.temperature,
          'max_side_requested': config.maxSide,
          'max_side_note':
              'the app downscales to ${SystemFoodVision.maxSide} px before the '
              'model; a smaller value is applied on top',
          'num_ctx': config.numCtx,
          'ollama_url': strategy == 'regions_only' ? null : config.ollamaUrl,
          'ollama_version': ollamaVersion,
          'labels': '${config.dir}/labels.json',
          'photos': present.length,
          'host': Platform.operatingSystem,
        };
        File('$base.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'meta': meta,
            'summary': summary.toJson(),
            'images': [for (final s in scores) s.toJson()],
          }),
        );
        File(
          '$base.md',
        ).writeAsStringSync(runMarkdown(meta: meta, images: scores));
        stdout.writeln('wrote $base.json and $base.md');
        runs.add((strategy, summary));
      }

      stdout
        ..writeln()
        ..writeln('Summary (model ${config.model}, photos ${present.length}):')
        ..writeln(summaryConsoleTable(runs));
    },
    skip: enabled
        ? false
        : 'Set VYRO_EVAL=1 to run the offline food vision evaluation',
    timeout: const Timeout(Duration(hours: 4)),
  );
}

String _timestamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

String _safe(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

/// Answers the app's channel calls for one strategy and records raw answers.
class _Runner {
  _Runner({
    required this.strategy,
    required this.config,
    required this.db,
    required this.ollama,
  });

  final String strategy;
  final EvalConfig config;
  final FoodDatabase db;
  final OllamaClient? ollama;

  /// Raw answers of the current photo, in call order.
  final List<String> log = [];

  late final SystemFoodVision _system = SystemFoodVision(db);
  late final RegionFoodVision _regions = RegionFoodVision(db);
  late final FoodVisionPipeline _pipeline = FoodVisionPipeline(
    llm: const PlatformOnDeviceLlm(),
    system: _system,
    regions: _regions,
  );

  /// Strategies whose first look is the only model answer: no second chance
  /// and no verification (answered locally, see [_describe]).
  bool get _firstLookOnly =>
      strategy == 'no_verify' || strategy.startsWith('sc_');

  void beginImage() => log.clear();

  Future<FoodVisionResult> analyse(Uint8List bytes) => switch (strategy) {
    'pipeline' || 'legacy_app' => _pipeline.analyse(bytes),
    'regions_only' => _regions.analyse(bytes),
    _ => _system.analyse(bytes),
  };

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'status':
      case 'download':
        return 'available';
      case 'describeImage':
        return _describe(call.arguments as Map<Object?, Object?>);
      default:
        throw MissingPluginException('eval harness: ${call.method}');
    }
  }

  Future<String> _describe(Map<Object?, Object?> args) async {
    final client = ollama;
    if (client == null) {
      throw StateError('no Ollama client for strategy $strategy');
    }
    final image = args['image'] as Uint8List;
    final second = args['secondImage'] as Uint8List?;
    final prompt = args['prompt'] as String;
    final split = splitTwoViewSuffix(prompt);
    final kind = kindOf(split.base);
    final images = [
      await _resize(image),
      if (second != null) await _resize(second),
    ];

    switch (kind) {
      case PromptKind.second when _firstLookOnly:
        return _synthetic('second', '{"items":[]}', 'second chance skipped');
      case PromptKind.verify when _firstLookOnly:
        return _synthetic('verify', '{"checks":[]}', 'verification skipped');
      case PromptKind.first when strategy.startsWith('sc_'):
        final sampleA = await _ask(
          'first sample 1',
          split.base + split.suffix,
          images,
          _samplingTemperature,
        );
        final sampleB = await _ask(
          'first sample 2',
          split.base + split.suffix,
          images,
          _samplingTemperature,
        );
        final combined = _combine(
          sampleA,
          sampleB,
          union: strategy == 'sc_union',
        );
        log.add('combined ($strategy): $combined');
        return combined;
      default:
        return _ask(
          kind.name,
          _variantPrompt(kind, split.base) + split.suffix,
          images,
          config.temperature,
        );
    }
  }

  String _variantPrompt(PromptKind kind, String base) {
    if (strategy == 'checklist' && kind == PromptKind.first) {
      return checklistFirstPrompt();
    }
    if (strategy == 'en_names') return enNamesPrompt(kind, base);
    if (strategy == 'legacy_app') return legacyNamesPrompt(kind, base);
    if (strategy == 'pt_prompt') {
      return switch (kind) {
        PromptKind.first => ptFirstPrompt(),
        PromptKind.second => ptSecondPrompt(),
        PromptKind.verify => ptVerifyPrompt(verifyItemsOf(base)),
        PromptKind.other => base,
      };
    }
    return base;
  }

  Future<String> _ask(
    String label,
    String prompt,
    List<Uint8List> images,
    double temperature,
  ) async {
    final raw = await ollama!.generate(
      prompt: prompt,
      images: images,
      temperature: temperature,
    );
    log.add('$label (temperature $temperature):\n$raw');
    return raw;
  }

  String _synthetic(String label, String answer, String why) {
    log.add('$label (synthetic, $why): $answer');
    return answer;
  }

  /// Union or intersection of two answers, by database key (or name when no
  /// database row), keeping the raw item objects so the app parses them.
  String _combine(String a, String b, {required bool union}) {
    final itemsA = _rawItems(a);
    final itemsB = _rawItems(b);
    final keysA = {for (final item in itemsA) _keyOf(item)}..remove('');
    final keysB = {for (final item in itemsB) _keyOf(item)}..remove('');
    final combined = union
        ? [
            ...itemsA,
            for (final item in itemsB)
              if (_keyOf(item).isNotEmpty && !keysA.contains(_keyOf(item)))
                item,
          ]
        : [
            for (final item in itemsA)
              if (keysB.contains(_keyOf(item))) item,
          ];
    return jsonEncode({'items': combined});
  }

  List<Map<Object?, Object?>> _rawItems(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return const [];
    try {
      final json = jsonDecode(raw.substring(start, end + 1));
      final items = json is Map ? json['items'] : null;
      return items is List
          ? [
              for (final item in items)
                if (item is Map) item.cast<Object?, Object?>(),
            ]
          : const [];
    } catch (_) {
      return const [];
    }
  }

  String _keyOf(Map<Object?, Object?> item) {
    final parsed = parseFoodPhotoAnswer(
      jsonEncode({
        'items': [item],
      }),
      db,
    );
    if (parsed.isEmpty) return '';
    final food = parsed.first;
    return food.food?.key ?? food.label.toLowerCase();
  }

  Future<Uint8List> _resize(Uint8List jpeg) async {
    final max = config.maxSide;
    if (max == null) return jpeg;
    final decoded = img.decodeImage(jpeg);
    if (decoded == null) return jpeg;
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longest <= max) return jpeg;
    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: max)
        : img.copyResize(decoded, height: max);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }
}
