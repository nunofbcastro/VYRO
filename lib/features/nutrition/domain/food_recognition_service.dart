import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class FoodCandidate {
  const FoodCandidate({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

abstract interface class FoodRecognitionService {
  Future<List<FoodCandidate>> recognize(Uint8List imageBytes);
}

/// Local single-image classifier. It predicts a dish label, never ingredients
/// or portion mass. All image tensors and model inference stay on device.
class LiteRtFoodRecognitionService implements FoodRecognitionService {
  static const modelAsset = 'assets/models/aiy_food_v1.tflite';
  static const labelsAsset = 'assets/models/aiy_food_v1_labels.csv';

  @override
  Future<List<FoodCandidate>> recognize(Uint8List imageBytes) async {
    final source = img.decodeImage(imageBytes);
    if (source == null) throw const FormatException('invalid_image');
    final upright = img.bakeOrientation(source);
    final interpreter = await Interpreter.fromAsset(modelAsset);
    IsolateInterpreter? isolate;
    try {
      // The bundled AIY Food V1 model is quantized: uint8 input of
      // 1×192×192×3 and a uint8 softmax over 2024 classes. Read everything
      // from the tensors so float models of other sizes also work.
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      final shape = inputTensor.shape;
      final quantizedIn = inputTensor.type == TensorType.uint8;
      final quantizedOut = outputTensor.type == TensorType.uint8;
      if (shape.length != 4 ||
          shape[0] != 1 ||
          shape[3] != 3 ||
          shape[1] != shape[2] ||
          (!quantizedIn && inputTensor.type != TensorType.float32) ||
          outputTensor.shape.length != 2 ||
          (!quantizedOut && outputTensor.type != TensorType.float32)) {
        throw StateError('unsupported_model_tensor');
      }
      final size = shape[1];
      final resized = img.copyResizeCropSquare(
        upright,
        size: size,
        interpolation: img.Interpolation.linear,
        antialias: true,
      );

      final Object input = [
        List.generate(
          size,
          (y) => List.generate(size, (x) {
            final pixel = resized.getPixel(x, y);
            return quantizedIn
                ? [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()]
                : [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      ];
      final classes = outputTensor.shape.last;
      final Object output = quantizedOut
          ? [List<int>.filled(classes, 0)]
          : [List<double>.filled(classes, 0)];

      isolate = await IsolateInterpreter.create(address: interpreter.address);
      await isolate.run(input, output);

      final raw = (output as List).single as List;
      final params = outputTensor.params;
      final values = quantizedOut
          ? dequantize(
              raw.cast<int>(),
              scale: params.scale == 0 ? 1 / 256 : params.scale,
              zeroPoint: params.zeroPoint,
            )
          : raw.cast<double>();
      final labels = await _loadLabels();
      return rankCandidates(
        _looksLikeProbabilities(values) ? values : _softmax(values),
        labels,
      );
    } finally {
      await isolate?.close();
      interpreter.close();
    }
  }

  Future<Map<int, String>> _loadLabels() async {
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
    return labels;
  }

  bool _looksLikeProbabilities(List<double> values) =>
      values.every((value) => value >= 0 && value <= 1) &&
      (values.fold<double>(0, (sum, value) => sum + value) - 1).abs() < .05;

  List<double> _softmax(List<double> values) {
    final maxValue = values.reduce(math.max);
    final exps = values.map((value) => math.exp(value - maxValue)).toList();
    final total = exps.fold<double>(0, (sum, value) => sum + value);
    return exps.map((value) => value / total).toList(growable: false);
  }
}

/// Converts quantized scores to real values: (q − zeroPoint) × scale.
List<double> dequantize(
  List<int> values, {
  required double scale,
  required int zeroPoint,
}) => [for (final q in values) (q - zeroPoint) * scale];

/// Top hypotheses (index 0 is "background" and never returned).
List<FoodCandidate> rankCandidates(
  List<double> probabilities,
  Map<int, String> labels, {
  int limit = 6,
  double minTop = .05,
  double minEach = .01,
}) {
  final ranked = probabilities.asMap().entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final foods = ranked.where((entry) => entry.key != 0).toList();
  if (foods.isEmpty || foods.first.value < minTop) return const [];
  return foods
      .take(limit)
      .where((entry) => entry.value > minEach)
      .map(
        (entry) => FoodCandidate(
          label: labels[entry.key] ?? 'Food ${entry.key}',
          confidence: entry.value,
        ),
      )
      .toList(growable: false);
}
