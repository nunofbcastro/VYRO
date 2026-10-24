import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class PosePoint {
  const PosePoint(this.x, this.y, this.confidence);
  final double x;
  final double y;
  final double confidence;
}

class PoseFrame {
  const PoseFrame(this.points, this.frameWidth, this.frameHeight);
  final List<PosePoint> points;
  final int frameWidth;
  final int frameHeight;
}

/// MoveNet SinglePose Lightning runs only on the phone. It emits landmarks,
/// not form advice, injury risk, or an exercise safety judgement.
class MoveNetService {
  static const modelAsset = 'assets/models/movenet_lightning_fp16.tflite';
  static const inputSize = 192;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;

  Future<void> initialize() async {
    if (_interpreter != null) return;
    final interpreter = await Interpreter.fromAsset(modelAsset);
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    if (input.shape.join(',') != '1,192,192,3' ||
        input.type != TensorType.uint8 ||
        output.shape.join(',') != '1,1,17,3' ||
        output.type != TensorType.float32) {
      interpreter.close();
      throw StateError('unsupported_pose_model');
    }
    _interpreter = interpreter;
    _isolate = await IsolateInterpreter.create(address: interpreter.address);
  }

  Future<PoseFrame> detect(CameraImage cameraImage, int rotationDegrees) async {
    final upright = _toRgbImage(cameraImage);
    final rotated = rotationDegrees == 0
        ? upright
        : img.copyRotate(upright, angle: rotationDegrees);
    final width = rotated.width;
    final height = rotated.height;
    final scale = inputSize / (width > height ? width : height);
    final scaledWidth = width * scale;
    final scaledHeight = height * scale;
    final padX = (inputSize - scaledWidth) / 2;
    final padY = (inputSize - scaledHeight) / 2;
    final resized = img.copyResize(
      rotated,
      width: inputSize,
      height: inputSize,
      maintainAspect: true,
      backgroundColor: img.ColorRgb8(0, 0, 0),
      interpolation: img.Interpolation.linear,
    );
    final input = <List<List<List<int>>>>[
      List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        }),
      ),
    ];
    final output = <List<List<List<double>>>>[
      [List.generate(17, (_) => List<double>.filled(3, 0))],
    ];
    await _isolate!.run(input, output);
    final points = output.single.single
        .map((point) {
          final x = (point[1] * inputSize - padX) / scaledWidth;
          final y = (point[0] * inputSize - padY) / scaledHeight;
          return PosePoint(x, y, point[2]);
        })
        .toList(growable: false);
    return PoseFrame(points, width, height);
  }

  Future<void> dispose() async {
    await _isolate?.close();
    _isolate = null;
    _interpreter?.close();
    _interpreter = null;
  }

  img.Image _toRgbImage(CameraImage frame) {
    final result = img.Image(width: frame.width, height: frame.height);
    if (frame.format.group == ImageFormatGroup.bgra8888) {
      final plane = frame.planes.first;
      final stride = plane.bytesPerPixel ?? 4;
      for (var y = 0; y < frame.height; y++) {
        for (var x = 0; x < frame.width; x++) {
          final index = y * plane.bytesPerRow + x * stride;
          result.setPixelRgb(
            x,
            y,
            plane.bytes[index + 2],
            plane.bytes[index + 1],
            plane.bytes[index],
          );
        }
      }
      return result;
    }

    if (frame.format.group != ImageFormatGroup.yuv420 ||
        frame.planes.length < 3) {
      throw StateError('unsupported_camera_format');
    }
    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    for (var y = 0; y < frame.height; y++) {
      for (var x = 0; x < frame.width; x++) {
        final luminance = yPlane.bytes[y * yPlane.bytesPerRow + x];
        final chromaX = x >> 1;
        final chromaY = y >> 1;
        final u =
            uPlane.bytes[chromaY * uPlane.bytesPerRow + chromaX * uPixelStride];
        final v =
            vPlane.bytes[chromaY * vPlane.bytesPerRow + chromaX * vPixelStride];
        final yy = (luminance - 16).clamp(0, 255).toDouble();
        final uu = (u - 128).toDouble();
        final vv = (v - 128).toDouble();
        result.setPixelRgb(
          x,
          y,
          (1.164 * yy + 1.596 * vv).round().clamp(0, 255),
          (1.164 * yy - .392 * uu - .813 * vv).round().clamp(0, 255),
          (1.164 * yy + 2.017 * uu).round().clamp(0, 255),
        );
      }
    }
    return result;
  }
}

class SquatRepCounter {
  int repetitions = 0;
  bool _reachedBottom = false;
  final Map<int, PosePoint> _smoothed = {};

  SquatUpdate update(PoseFrame frame) {
    for (var index = 0; index < frame.points.length; index++) {
      final point = frame.points[index];
      final previous = _smoothed[index];
      _smoothed[index] = previous == null || point.confidence < .25
          ? point
          : PosePoint(
              previous.x + .4 * (point.x - previous.x),
              previous.y + .4 * (point.y - previous.y),
              point.confidence,
            );
    }

    const required = [5, 6, 11, 12, 13, 14, 15, 16];
    final landmarks = required.map((index) => _smoothed[index]!).toList();
    final visible = landmarks.every((point) => point.confidence >= .3);
    final inFrame = landmarks.every(
      (point) =>
          point.x >= .015 &&
          point.x <= .985 &&
          point.y >= .015 &&
          point.y <= .985,
    );
    if (!visible || !inFrame) {
      return SquatUpdate(
        repetitions,
        null,
        _visibleConfidence(landmarks),
        visible ? 'out_of_frame' : 'low_confidence',
      );
    }

    final leftAngle = _kneeAngle(
      _smoothed[11]!,
      _smoothed[13]!,
      _smoothed[15]!,
    );
    final rightAngle = _kneeAngle(
      _smoothed[12]!,
      _smoothed[14]!,
      _smoothed[16]!,
    );
    final angle = (leftAngle + rightAngle) / 2;
    if (angle < 110) _reachedBottom = true;
    if (_reachedBottom && angle > 155) {
      repetitions++;
      _reachedBottom = false;
    }
    return SquatUpdate(
      repetitions,
      angle,
      _visibleConfidence(landmarks),
      'ready',
    );
  }

  double _visibleConfidence(List<PosePoint> points) =>
      points.fold<double>(0, (sum, point) => sum + point.confidence) /
      points.length;

  double _kneeAngle(PosePoint hip, PosePoint knee, PosePoint ankle) {
    final ax = hip.x - knee.x;
    final ay = hip.y - knee.y;
    final bx = ankle.x - knee.x;
    final by = ankle.y - knee.y;
    final dot = ax * bx + ay * by;
    final denominator = (ax * ax + ay * ay) * (bx * bx + by * by);
    if (denominator <= 0) return 180;
    final cosine = (dot / denominator.sqrt()).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }
}

class SquatUpdate {
  const SquatUpdate(
    this.repetitions,
    this.kneeAngle,
    this.confidence,
    this.state,
  );
  final int repetitions;
  final double? kneeAngle;
  final double confidence;
  final String state;
}

extension on double {
  double sqrt() => math.sqrt(this);
}
