import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;
import 'package:image/image.dart' as img;
import '../exercise_analysis/exercise_analysis_engine.dart';
import '../movement_patterns/movement_pattern.dart';
import '../pose_detection/pose_models.dart';
import '../repetition_counter/rep_counter_engine.dart';

class LocalVideoInfo {
  const LocalVideoInfo(this.duration);
  final Duration duration;
}

class LocalVideoFrame {
  const LocalVideoFrame(this.jpeg, this.time, {this.approximate = false});
  final Uint8List jpeg;
  final Duration time;
  final bool approximate;
}

abstract interface class VideoFrameSource {
  Future<LocalVideoInfo> open(String path);
  Future<LocalVideoFrame> frame(Duration time);
  Future<void> close();
}

class PlatformVideoFrameSource implements VideoFrameSource {
  PlatformVideoFrameSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('vyro/local_video');
  final MethodChannel _channel;
  int? _id;
  @override
  Future<LocalVideoInfo> open(String path) async {
    final value = await _channel.invokeMapMethod<String, dynamic>('open', {
      'path': path,
    });
    if (value == null ||
        value['id'] is! int ||
        value['durationMs'] is! num ||
        (value['durationMs'] as num) <= 0)
      throw const FormatException('Invalid video metadata');
    _id = value['id'] as int;
    return LocalVideoInfo(
      Duration(milliseconds: (value['durationMs'] as num).toInt()),
    );
  }

  @override
  Future<LocalVideoFrame> frame(Duration time) async {
    if (_id == null) throw StateError('Video is closed');
    final value = await _channel.invokeMapMethod<String, dynamic>('frame', {
      'id': _id,
      'timeMs': time.inMilliseconds,
    });
    if (value == null || value['jpeg'] is! Uint8List || value['timeMs'] is! num)
      throw const FormatException('Invalid frame');
    return LocalVideoFrame(
      value['jpeg'] as Uint8List,
      Duration(milliseconds: (value['timeMs'] as num).toInt()),
      approximate: value['approximate'] == true,
    );
  }

  @override
  Future<void> close() async {
    final id = _id;
    _id = null;
    if (id != null) await _channel.invokeMethod<void>('close', {'id': id});
  }
}

abstract interface class VideoPoseDetector {
  Future<BodyPose?> detect(LocalVideoFrame frame);
  Future<void> close();
}

/// Converts one bounded, upright JPEG to the raw format required by ML Kit.
/// Android: NV21; iOS: BGRA. Neither format requires a temporary image file.
(Uint8List, int, int) decodePoseFrame((Uint8List, bool) input) {
  final decoded = img.decodeImage(input.$1);
  if (decoded == null) throw const FormatException('Invalid video frame');
  var image = img.bakeOrientation(decoded);
  final width = (image.width ~/ 2) * 2, height = (image.height ~/ 2) * 2;
  if (width < 2 || height < 2) throw const FormatException('Frame too small');
  if (width != image.width || height != image.height)
    image = img.copyResize(image, width: width, height: height);
  if (input.$2)
    return (
      Uint8List.fromList(image.getBytes(order: img.ChannelOrder.bgra)),
      width,
      height,
    );
  final bytes = Uint8List(width * height * 3 ~/ 2);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      bytes[y * width + x] = (((66 * r + 129 * g + 25 * b + 128) >> 8) + 16)
          .clamp(0, 255);
      if (y.isEven && x.isEven) {
        final index = width * height + (y ~/ 2) * width + x;
        bytes[index] = (((112 * r - 94 * g - 18 * b + 128) >> 8) + 128).clamp(
          0,
          255,
        );
        bytes[index + 1] = (((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128)
            .clamp(0, 255);
      }
    }
  }
  return (bytes, width, height);
}

class MlKitVideoPoseDetector implements VideoPoseDetector {
  MlKitVideoPoseDetector()
    : _detector = mlkit.PoseDetector(
        options: mlkit.PoseDetectorOptions(
          model: mlkit.PoseDetectionModel.accurate,
          mode: mlkit.PoseDetectionMode.single,
        ),
      );
  final mlkit.PoseDetector _detector;
  @override
  Future<BodyPose?> detect(LocalVideoFrame frame) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final decoded = await compute(decodePoseFrame, (frame.jpeg, ios));
    final width = decoded.$2.toDouble(), height = decoded.$3.toDouble();
    final poses = await _detector.processImage(
      mlkit.InputImage.fromBytes(
        bytes: decoded.$1,
        metadata: mlkit.InputImageMetadata(
          size: Size(width, height),
          rotation: mlkit.InputImageRotation.rotation0deg,
          format: ios
              ? mlkit.InputImageFormat.bgra8888
              : mlkit.InputImageFormat.nv21,
          bytesPerRow: ios ? decoded.$2 * 4 : decoded.$2,
        ),
      ),
    );
    if (poses.isEmpty) return null;
    final landmarks = <BodyLandmark, PoseLandmark>{};
    final names = BodyLandmark.values.asNameMap();
    for (final e in poses.first.landmarks.entries) {
      final type = names[e.key.name];
      if (type != null)
        landmarks[type] = PoseLandmark(
          x: e.value.x / width,
          y: e.value.y / height,
          z: e.value.z / width,
          likelihood: e.value.likelihood,
        );
    }
    return BodyPose(
      landmarks: landmarks,
      timestamp: frame.time,
      aspectRatio: width / height,
    );
  }

  @override
  Future<void> close() => _detector.close();
}

class VideoAnalysisCancelled implements Exception {
  const VideoAnalysisCancelled();
}

class VideoMoment {
  const VideoMoment(this.at, this.messageKey);
  final Duration at;
  final String messageKey;
}

class VideoAnalysisResult {
  const VideoAnalysisResult({
    required this.summary,
    required this.moments,
    required this.frames,
    required this.inferenceMs,
    required this.approximate,
  });
  final SetSummary summary;
  final List<VideoMoment> moments;
  final int frames;
  final double inferenceMs;
  final bool approximate;
}

/// Streams frames sequentially. Memory usage does not grow with video length.
class LocalVideoAnalysis {
  static const maxClip = Duration(minutes: 2);
  Future<VideoAnalysisResult> run({
    required VideoFrameSource source,
    required VideoPoseDetector detector,
    required MovementPattern pattern,
    required Duration start,
    required Duration end,
    required bool Function() cancelled,
    void Function(double)? onProgress,
  }) async {
    try {
      if (start < Duration.zero || end <= start || end - start > maxClip)
        throw const FormatException('Choose up to two minutes');
      final engine = ExerciseAnalysisEngine(pattern: pattern);
      final moments = <VideoMoment>[];
      var frames = 0, inference = 0.0, approximate = false;
      Duration? lastTime, firstFrame;
      var lostVisibility = false;
      for (
        var time = start;
        time < end;
        time += const Duration(milliseconds: 100)
      ) {
        if (cancelled()) throw const VideoAnalysisCancelled();
        final frame = await source.frame(time);
        if (cancelled()) throw const VideoAnalysisCancelled();
        if (frame.time < start ||
            frame.time >= end ||
            (lastTime != null && frame.time <= lastTime))
          continue;
        lastTime = frame.time;
        approximate |= frame.approximate;
        final clock = Stopwatch()..start();
        final pose = await detector.detect(frame);
        inference += clock.elapsedMicroseconds / 1000;
        if (cancelled()) throw const VideoAnalysisCancelled();
        final update = engine.process(pose, frame.time - start);
        firstFrame ??= frame.time;
        frames++;
        if (update.repEvent?.type == RepEventType.partial)
          moments.add(VideoMoment(frame.time, 'mfPartialRep'));
        // Flag the moment the body (or the counting signal) is lost, once per
        // lost stretch, so the user can review why counting paused.
        final lost = update.status == AnalysisStatus.notObservable;
        if (lost && !lostVisibility)
          moments.add(
            VideoMoment(
              frame.time,
              update.feedback.isEmpty
                  ? 'mfPartlyVisible'
                  : update.feedback.first.key,
            ),
          );
        lostVisibility = lost;
        onProgress?.call(
          (time - start).inMilliseconds / (end - start).inMilliseconds,
        );
      }
      final summary = engine.summary();
      // Technique event times are relative to the first processed frame.
      final origin = firstFrame ?? start;
      moments.addAll([
        for (final event in summary.events)
          VideoMoment(origin + event.at, event.messageKey),
      ]);
      moments.sort((a, b) => a.at.compareTo(b.at));
      onProgress?.call(1);
      return VideoAnalysisResult(
        summary: summary,
        moments: moments,
        frames: frames,
        inferenceMs: inference,
        approximate: approximate,
      );
    } finally {
      await detector.close();
    }
  }
}
