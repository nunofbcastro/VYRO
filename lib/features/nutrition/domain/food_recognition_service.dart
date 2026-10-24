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
    final resized = img.copyResizeCropSquare(
      upright,
      size: 224,
      interpolation: img.Interpolation.linear,
      antialias: true,
    );
    final interpreter = await Interpreter.fromAsset(modelAsset);
    IsolateInterpreter? isolate;
    try {
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      if (inputTensor.shape.join(',') != '1,224,224,3' ||
          inputTensor.type != TensorType.float32 ||
          outputTensor.shape.length != 2 ||
          outputTensor.shape.first != 1 ||
          outputTensor.type != TensorType.float32) {
        throw StateError('unsupported_model_tensor');
      }

      final input = <List<List<List<double>>>>[
        List.generate(
          224,
          (y) => List.generate(224, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r.toDouble() / 255,
              pixel.g.toDouble() / 255,
              pixel.b.toDouble() / 255,
            ];
          }),
        ),
      ];
      final scores = <List<double>>[
        List<double>.filled(outputTensor.shape.last, 0),
      ];

      isolate = await IsolateInterpreter.create(address: interpreter.address);
      await isolate.run(input, scores);
      final labels = await _loadLabels();
      final probabilities = _looksLikeProbabilities(scores.single)
          ? scores.single
          : _softmax(scores.single);
      final ranked = probabilities.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (ranked.isEmpty || ranked.first.key == 0 || ranked.first.value < .05) {
        return const [];
      }
      return ranked
          .take(6)
          .where((entry) => entry.key != 0)
          .map(
            (entry) => FoodCandidate(
              label: labels[entry.key] ?? 'Food ${entry.key}',
              confidence: probabilities[entry.key],
            ),
          )
          .where((candidate) => candidate.confidence > .01)
          .toList(growable: false);
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
