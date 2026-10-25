import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import 'pose_models.dart';

/// Replaceable body-pose detector. Implementations run on the device and
/// return null when no person is found (or the frame cannot be read).
abstract interface class PoseDetectionService {
  Future<BodyPose?> detect(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
    Duration timestamp,
  );

  /// Image format the camera stream must use for this detector.
  ImageFormatGroup get imageFormat;

  Future<void> close();
}

/// Google ML Kit Pose Detection (BlazePose, 33 landmarks), base model in
/// stream mode. Fully on-device; frames are never stored or sent.
class MlKitPoseDetectionService implements PoseDetectionService {
  MlKitPoseDetectionService({bool accurate = false})
    : _detector = mlkit.PoseDetector(
        options: mlkit.PoseDetectorOptions(
          model: accurate
              ? mlkit.PoseDetectionModel.accurate
              : mlkit.PoseDetectionModel.base,
          mode: mlkit.PoseDetectionMode.stream,
        ),
      );

  final mlkit.PoseDetector _detector;

  static const _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  ImageFormatGroup get imageFormat =>
      Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21;

  @override
  Future<BodyPose?> detect(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
    Duration timestamp,
  ) async {
    final rotation = _rotation(camera, deviceOrientation);
    final input = _toInputImage(image, rotation);
    if (input == null || rotation == null) return null;
    final poses = await _detector.processImage(input);
    if (poses.isEmpty) return null;

    // ML Kit reports coordinates in the upright (rotated) image.
    final quarter =
        rotation == mlkit.InputImageRotation.rotation90deg ||
        rotation == mlkit.InputImageRotation.rotation270deg;
    final width = (quarter ? image.height : image.width).toDouble();
    final height = (quarter ? image.width : image.height).toDouble();
    final landmarks = <BodyLandmark, PoseLandmark>{};
    for (final entry in poses.first.landmarks.entries) {
      final type = BodyLandmark.values.asNameMap()[entry.key.name];
      if (type == null) continue;
      final p = entry.value;
      landmarks[type] = PoseLandmark(
        x: p.x / width,
        y: p.y / height,
        z: p.z / width,
        likelihood: p.likelihood,
      );
    }
    return BodyPose(
      landmarks: landmarks,
      timestamp: timestamp,
      aspectRatio: width / height,
    );
  }

  mlkit.InputImageRotation? _rotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensor = camera.sensorOrientation;
    if (Platform.isIOS)
      return mlkit.InputImageRotationValue.fromRawValue(sensor);
    final device = _orientationDegrees[deviceOrientation] ?? 0;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
    return mlkit.InputImageRotationValue.fromRawValue(degrees);
  }

  mlkit.InputImage? _toInputImage(
    CameraImage image,
    mlkit.InputImageRotation? rotation,
  ) {
    if (rotation == null) return null;
    final format = mlkit.InputImageFormatValue.fromRawValue(image.format.raw);
    final expected = Platform.isIOS
        ? mlkit.InputImageFormat.bgra8888
        : mlkit.InputImageFormat.nv21;
    if (format != expected || image.planes.length != 1) return null;
    final plane = image.planes.first;
    return mlkit.InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> close() => _detector.close();
}
