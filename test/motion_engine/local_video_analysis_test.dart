import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/features/motion_engine/video/local_video_analysis.dart';
import 'package:vyro/features/motion_engine/movement_patterns/pattern_library.dart';
import 'package:vyro/features/motion_engine/pose_detection/pose_models.dart';
import 'synthetic_poses.dart';

class _Source implements VideoFrameSource {
  final requests = <Duration>[];
  bool fail = false;
  @override
  Future<LocalVideoInfo> open(String path) async =>
      const LocalVideoInfo(Duration(seconds: 30));
  @override
  Future<LocalVideoFrame> frame(Duration time) async {
    requests.add(time);
    if (fail) throw StateError('decode failed');
    return LocalVideoFrame(Uint8List(0), time, approximate: true);
  }

  @override
  Future<void> close() async {}
}

class _Detector implements VideoPoseDetector {
  _Detector({this.offset = Duration.zero});
  final Duration offset;
  bool closed = false;
  int calls = 0;
  @override
  Future<BodyPose?> detect(LocalVideoFrame frame) async {
    calls++;
    final seconds = (frame.time - offset).inMilliseconds / 1000;
    final knee = 170 - 80 * (1 - math.cos(2 * math.pi * seconds / 2)) / 2;
    return syntheticPose(at: frame.time, kneeAngle: knee);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _LostDetector extends _Detector {
  _LostDetector(this.from, this.to);
  final Duration from, to;
  @override
  Future<BodyPose?> detect(LocalVideoFrame frame) async {
    if (frame.time >= from && frame.time < to) return null;
    return super.detect(frame);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'video analysis uses clip positions rather than processing time',
    () async {
      final source = _Source(),
          detector = _Detector(offset: const Duration(seconds: 10));
      final result = await LocalVideoAnalysis().run(
        source: source,
        detector: detector,
        pattern: PatternLibrary.squat,
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 16),
        cancelled: () => false,
      );
      expect(source.requests.first, const Duration(seconds: 10));
      // Knee cycle is 2 s: tops at 0, 2, 4 s and the third return (~5.8 s) falls
      // inside the 6 s clip, so three complete reps are expected.
      expect(result.summary.fullReps, 3);
      expect(result.frames, 60);
      expect(result.approximate, true);
      expect(detector.closed, true);
      expect(result.summary.duration, lessThan(const Duration(seconds: 6)));
    },
  );
  test(
    'lost body visibility is flagged once per stretch and rep moments are clip-relative',
    () async {
      final source = _Source(),
          detector = _LostDetector(
            const Duration(seconds: 12),
            const Duration(seconds: 14),
          );
      final result = await LocalVideoAnalysis().run(
        source: source,
        detector: detector,
        pattern: PatternLibrary.squat,
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 16),
        cancelled: () => false,
      );
      final lost = result.moments
          .where((m) => m.messageKey == 'mfNoPerson')
          .toList();
      expect(lost.length, 1);
      expect(lost.single.at, const Duration(seconds: 12));
      for (final moment in result.moments) {
        expect(moment.at, greaterThanOrEqualTo(const Duration(seconds: 10)));
        expect(moment.at, lessThan(const Duration(seconds: 16)));
      }
    },
  );
  test(
    'cancellation releases the detector and stops requesting frames',
    () async {
      final source = _Source(), detector = _Detector();
      var cancelled = false;
      await expectLater(
        LocalVideoAnalysis().run(
          source: source,
          detector: detector,
          pattern: PatternLibrary.squat,
          start: Duration.zero,
          end: const Duration(seconds: 10),
          cancelled: () => cancelled,
          onProgress: (value) {
            if (value > .02) cancelled = true;
          },
        ),
        throwsA(isA<VideoAnalysisCancelled>()),
      );
      expect(detector.closed, true);
      expect(source.requests.length, lessThan(10));
    },
  );
  test('decoder failure releases the detector', () async {
    final source = _Source()..fail = true, detector = _Detector();
    await expectLater(
      LocalVideoAnalysis().run(
        source: source,
        detector: detector,
        pattern: PatternLibrary.squat,
        start: Duration.zero,
        end: const Duration(seconds: 10),
        cancelled: () => false,
      ),
      throwsStateError,
    );
    expect(detector.closed, true);
  });
  test('raw pixel conversion has correct NV21 and BGRA layouts', () {
    final image = img.Image(width: 4, height: 2)..clear(img.ColorRgb8(0, 0, 0));
    final bytes = Uint8List.fromList(img.encodeJpg(image));
    final android = decodePoseFrame((bytes, false)),
        ios = decodePoseFrame((bytes, true));
    expect(android.$1.length, 12);
    expect(android.$1.take(8), everyElement(16));
    expect(android.$1.skip(8), everyElement(128));
    expect(ios.$1.length, 32);
    expect(ios.$1[3], 255);
  });
  test(
    'platform decoder closes the same session and keeps media in memory',
    () async {
      const channel = MethodChannel('test/local_video');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'open') return {'id': 7, 'durationMs': 1000};
        if (call.method == 'frame')
          return {
            'jpeg': Uint8List.fromList([1, 2]),
            'timeMs': 200,
            'approximate': true,
          };
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final source = PlatformVideoFrameSource(channel: channel);
      expect(
        (await source.open('/local/cache/clip.mp4')).duration,
        const Duration(seconds: 1),
      );
      expect(
        (await source.frame(const Duration(milliseconds: 200))).approximate,
        true,
      );
      await source.close();
      expect(calls.last.arguments, {'id': 7});
      await expectLater(source.frame(Duration.zero), throwsStateError);
    },
  );
}
