import 'dart:isolate';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

import '../data/food_database.dart';
import '../domain/food_recognition_service.dart'
    show dequantize, toProbabilities;
import 'food_vision.dart';

/// Offline multi-food estimate built on the bundled single-label dish
/// classifier (AIY Food V1): it classifies the whole photo plus overlapping
/// regions (3×3 and 4×4 grids) and maps the dish labels each region shows to
/// database foods via `visionLabels` (e.g. "Feijoada" → beans).
///
/// This is an approximation: the model knows dish names, not ingredients,
/// so it can miss foods or suggest wrong ones. Grams are typical portions.
class RegionFoodVision implements FoodVisionService {
  RegionFoodVision(this.database);

  final FoodDatabase database;

  static const modelAsset = 'assets/models/aiy_food_v1.tflite';
  static const labelsAsset = 'assets/models/aiy_food_v1_labels.csv';

  /// Minimum per-region probability for a label to count as evidence.
  static const minRegionProbability = 0.08;

  /// A food is kept when its best region reached this probability…
  static const minFoodPeak = 0.14;

  /// …and it appeared in at least this many distinct regions. These two are
  /// also the minimum for an offline suggestion. The eval on 50 Nutrition5k
  /// photos (regions only) gave precision 0.28 and recall 0.06, so they are a
  /// floor, not a guarantee; offline results are never added to the main list.
  static const minRegions = 2;

  /// Categories where a plate usually has a single food (one main protein,
  /// one kind of beans).
  static const exclusiveCategories = {'carne', 'peixe', 'leguminosas'};

  /// Non-food gate. A region votes "no food" when the background class (index
  /// 0 of the AIY labels) is more probable than the best food label there, or
  /// when no food label reaches [minRegionProbability]. When more than this
  /// share of the regions vote that way, the photo has no recognisable food and
  /// the offline pass returns nothing (not even suggestions).
  static const nonFoodRegionShare = 0.5;

  /// Index of the "__background__" class in `aiy_food_v1_labels.csv`.
  static const backgroundLabel = 0;

  static Uint8List? _modelCache;
  static Future<_RegionWorker>? _worker;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async {
    final model = _modelCache ??= (await rootBundle.load(
      modelAsset,
    )).buffer.asUint8List();
    final labels = await _labels();
    // Decoding, cropping and inferences run off the UI isolate.
    final worker = await (_worker ??= _RegionWorker.start(
      model,
      () => _worker = null,
    ));
    final perCrop = await worker.classify(imageBytes);
    return interpretRegions(database, perCrop, labels);
  }

  /// Multiple labels for one food in the same crop are one observation,
  /// not independent evidence of its presence.
  static FoodVisionResult interpretRegions(
    FoodDatabase database,
    List<List<(int, double)>> perCrop,
    Map<int, String> labels,
  ) {
    // Non-food gate first: background wins on most regions → no food at all.
    var nonFoodRegions = 0;
    for (final ranked in perCrop) {
      var background = 0.0;
      var bestFood = 0.0;
      for (final (k, p) in ranked) {
        if (k == backgroundLabel) {
          background = p;
        } else if (p > bestFood) {
          bestFood = p;
        }
      }
      if (background > bestFood) nonFoodRegions++;
    }
    if (perCrop.isNotEmpty &&
        nonFoodRegions > perCrop.length * nonFoodRegionShare) {
      return FoodVisionResult(
        source: VisionSource.regionClassifier,
        foods: const [],
        note: offlineNoFoodNote,
        detail:
            'offline: background wins in $nonFoodRegions of '
            '${perCrop.length} regions, no food kept',
      );
    }
    final peak = <String, double>{};
    final regions = <String, int>{};
    final score = <String, double>{};
    String? dish;
    for (var i = 0; i < perCrop.length; i++) {
      final ranked = perCrop[i];
      if (i == 0) {
        for (final (k, _) in ranked) {
          if (k == backgroundLabel) continue;
          dish = labels[k];
          break;
        }
      }
      final cropPeak = <String, double>{};
      for (final (k, p) in ranked) {
        if (k == backgroundLabel) continue;
        final label = labels[k];
        if (label == null) continue;
        for (final food in database.forVisionLabel(label)) {
          if (p > (cropPeak[food.key] ?? 0)) cropPeak[food.key] = p;
        }
      }
      for (final entry in cropPeak.entries) {
        final key = entry.key;
        final p = entry.value;
        score[key] = (score[key] ?? 0) + p;
        if (p > (peak[key] ?? 0)) peak[key] = p;
        regions[key] = (regions[key] ?? 0) + 1;
      }
    }
    final keys =
        score.keys
            .where(
              (k) =>
                  (peak[k] ?? 0) >= minFoodPeak &&
                  (regions[k] ?? 0) >= minRegions,
            )
            .toList()
          ..sort((a, b) => score[b]!.compareTo(score[a]!));
    // Dish labels are ambiguous ("Churrasco" → chicken and beef): keep only
    // the strongest food of each main-protein category.
    final proteins = <String>{};
    keys.removeWhere((k) {
      final category = database.byKey(k)!.category;
      if (!exclusiveCategories.contains(category)) return false;
      return !proteins.add(category);
    });
    return FoodVisionResult(
      source: VisionSource.regionClassifier,
      dishGuess: dish,
      foods: [
        for (final k in keys.take(6))
          DetectedFood(
            food: database.byKey(k),
            label: database.byKey(k)!.namePt,
            grams: database.byKey(k)!.portionG,
            confidence: peak[k],
            source: VisionSource.regionClassifier,
          ),
      ],
    );
  }

  /// Per region: the background probability (index 0, raw) followed by the top
  /// food labels (index, probability ≥ [minRegionProbability], renormalised
  /// over food classes). Runs inside a worker isolate.
  static List<List<(int, double)>> classifyRegions(
    Uint8List model,
    Uint8List imageBytes, {
    Interpreter? existingInterpreter,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw const FormatException('invalid_image');
    final upright = img.bakeOrientation(decoded);
    // Letterbox keeps the whole plate; a centre crop used to cut the edges.
    final full = letterboxSquare(upright);
    final interpreter = existingInterpreter ?? Interpreter.fromBuffer(model);
    try {
      return [
        for (final crop in [
          full,
          ...regionCrops(upright, 3, 0.55),
          ...regionCrops(upright, 4, 0.42),
        ])
          _top(_classify(interpreter, crop)),
      ];
    } finally {
      if (existingInterpreter == null) interpreter.close();
    }
  }

  /// Pads to a square so the classifier sees the full frame.
  static img.Image letterboxSquare(img.Image source) {
    final side = source.width > source.height ? source.width : source.height;
    if (source.width == side && source.height == side) return source;
    final canvas = img.Image(width: side, height: side);
    canvas.clear(img.ColorRgb8(0, 0, 0));
    img.compositeImage(
      canvas,
      source,
      dstX: (side - source.width) ~/ 2,
      dstY: (side - source.height) ~/ 2,
    );
    return canvas;
  }

  /// Overlapping windows on the original rectangle (not a cropped square).
  static Iterable<img.Image> regionCrops(
    img.Image image,
    int n,
    double fraction,
  ) sync* {
    final width = (image.width * fraction).round().clamp(16, image.width);
    final height = (image.height * fraction).round().clamp(16, image.height);
    final stepX = n == 1 ? 0.0 : (image.width - width) / (n - 1);
    final stepY = n == 1 ? 0.0 : (image.height - height) / (n - 1);
    for (var gy = 0; gy < n; gy++) {
      for (var gx = 0; gx < n; gx++) {
        yield img.copyCrop(
          image,
          x: (gx * stepX).round(),
          y: (gy * stepY).round(),
          width: width,
          height: height,
        );
      }
    }
  }

  static List<(int, double)> _top(List<double> p) {
    final ranked = [for (var k = 1; k < p.length; k++) k]
      ..sort((a, b) => p[b].compareTo(p[a]));
    return [
      (backgroundLabel, p[backgroundLabel]),
      for (final k in ranked.take(5))
        if (p[k] >= minRegionProbability) (k, p[k]),
    ];
  }

  static List<double> _classify(Interpreter interpreter, img.Image crop) {
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    final size = input.shape[1];
    final quantizedIn = input.type == TensorType.uint8;
    final resized = img.copyResize(
      letterboxSquare(crop),
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );
    final data = [
      List.generate(
        size,
        (y) => List.generate(size, (x) {
          final px = resized.getPixel(x, y);
          return quantizedIn
              ? [px.r.toInt(), px.g.toInt(), px.b.toInt()]
              : [px.r / 255.0, px.g / 255.0, px.b / 255.0];
        }),
      ),
    ];
    final classes = output.shape.last;
    final quantizedOut = output.type == TensorType.uint8;
    final Object out = quantizedOut
        ? [List<int>.filled(classes, 0)]
        : [List<double>.filled(classes, 0)];
    interpreter.run(data, out);
    final raw = (out as List).single as List;
    final values = quantizedOut
        ? dequantize(
            raw.cast<int>(),
            scale: output.params.scale == 0 ? 1 / 256 : output.params.scale,
            zeroPoint: output.params.zeroPoint,
          )
        : raw.cast<double>();
    // Food probabilities are renormalised without "background" (as before);
    // the raw background probability is kept at index 0 for the non-food gate.
    final foods = List<double>.of(values)..[backgroundLabel] = 0;
    final probabilities = toProbabilities(foods);
    probabilities[backgroundLabel] = values[backgroundLabel];
    return probabilities;
  }

  static Map<int, String>? _labelCache;

  Future<Map<int, String>> _labels() async {
    if (_labelCache != null) return _labelCache!;
    final csv = await rootBundle.loadString(labelsAsset);
    final labels = <int, String>{};
    for (final line in csv.split(RegExp(r'\r?\n')).skip(1)) {
      final comma = line.indexOf(',');
      if (comma < 0) continue;
      final id = int.tryParse(line.substring(0, comma).trim());
      if (id == null) continue;
      var label = line.substring(comma + 1).trim();
      if (label.startsWith('"') && label.endsWith('"')) {
        label = label.substring(1, label.length - 1).replaceAll('""', '"');
      }
      labels[id] = label;
    }
    return _labelCache = labels;
  }
}

/// One reusable interpreter on its own isolate; idle workers release memory.
class _RegionWorker {
  _RegionWorker(this.isolate, this.port, this.onClose);
  final Isolate isolate;
  final SendPort port;
  final void Function() onClose;
  Timer? _idle;
  int _pending = 0;
  static Future<_RegionWorker> start(
    Uint8List model,
    void Function() onClose,
  ) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_regionWorkerMain, [
      ready.sendPort,
      model,
    ]);
    try {
      final response = await ready.first.timeout(const Duration(seconds: 30));
      if (response is! SendPort) throw StateError('$response');
      return _RegionWorker(isolate, response, onClose);
    } catch (_) {
      isolate.kill();
      onClose();
      rethrow;
    } finally {
      ready.close();
    }
  }

  Future<List<List<(int, double)>>> classify(Uint8List bytes) async {
    _idle?.cancel();
    _pending++;
    final reply = ReceivePort();
    try {
      port.send([bytes, reply.sendPort]);
      final message =
          await reply.first.timeout(const Duration(seconds: 45)) as List;
      if (message[0] == null) throw StateError('${message[1]}');
      return (message[0] as List)
          .map((row) => (row as List).cast<(int, double)>())
          .toList();
    } finally {
      reply.close();
      _pending--;
      if (_pending == 0)
        _idle = Timer(const Duration(minutes: 2), () {
          isolate.kill();
          onClose();
        });
    }
  }
}

void _regionWorkerMain(List<Object> args) {
  final ready = args[0] as SendPort;
  try {
    final interpreter = Interpreter.fromBuffer(args[1] as Uint8List);
    final requests = ReceivePort();
    ready.send(requests.sendPort);
    requests.listen((dynamic message) {
      final data = message as List;
      final reply = data[1] as SendPort;
      try {
        reply.send([
          RegionFoodVision.classifyRegions(
            Uint8List(0),
            data[0] as Uint8List,
            existingInterpreter: interpreter,
          ),
          null,
        ]);
      } catch (error) {
        reply.send([null, error.toString()]);
      }
    });
  } catch (error) {
    ready.send(error.toString());
  }
}
