import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/biomechanics/biomechanics_engine.dart';
import 'package:vyro/features/motion_engine/movement_patterns/movement_pattern.dart';
import 'package:vyro/features/motion_engine/movement_patterns/pattern_library.dart';
import 'package:vyro/features/motion_engine/pose_detection/pose_models.dart';
import 'package:vyro/features/motion_engine/workout_camera/positioning_guide.dart';
import 'package:vyro/features/motion_engine/workout_camera/positioning_overlay.dart';

/// A pose built from the guide's own template, optionally transformed
/// (scaled, shifted or mirrored) and with some landmarks hidden.
BodyPose poseFrom(
  PositioningGuide guide, {
  Offset Function(Offset p)? map,
  Duration at = Duration.zero,
  double likelihood = 0.95,
  Map<BodyLandmark, double> likelihoodOverride = const {},
  double aspect = 1,
}) {
  final landmarks = <BodyLandmark, PoseLandmark>{};
  guide.joints.forEach((l, p) {
    final q = map == null ? p : map(p);
    landmarks[l] = PoseLandmark(
      x: q.dx,
      y: q.dy,
      likelihood: likelihoodOverride[l] ?? likelihood,
    );
  });
  return BodyPose(landmarks: landmarks, timestamp: at, aspectRatio: aspect);
}

/// Scales about the image centre (x and y by their own factors).
Offset Function(Offset) scale(double sx, double sy) =>
    (p) => Offset(0.5 + (p.dx - 0.5) * sx, 0.5 + (p.dy - 0.5) * sy);

Offset Function(Offset) shift(double dx) =>
    (p) => Offset(p.dx + dx, p.dy);

/// A custom pattern with a chosen camera view, for view-mapping tests.
MovementPattern withView(String id, CameraView view) => MovementPattern(
  id: id,
  signal: const SignalSpec(BioMetric.kneeLeft),
  requiredLandmarks: const [
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
  ],
  cameraView: view,
);

void main() {
  const squat = PatternLibrary.squat; // side, standing
  const verticalPush = PatternLibrary.verticalPush; // front, standing
  const horizontalPush = PatternLibrary.horizontalPush; // side, plank
  const core = PatternLibrary.coreStabilization; // side, plank

  group('PositioningGuide template per camera view', () {
    test('side patterns use a standing side template and portrait', () {
      final g = PositioningGuide.forPattern(squat);
      expect(g.posture, GuidePosture.standing);
      expect(g.view, CameraView.side);
      expect(g.expectedView, CameraView.side);
      expect(g.targetFrame, const Rect.fromLTRB(0.30, 0.08, 0.70, 0.92));
      expect(g.landscape, isFalse);
      expect(g.tips, contains(GuideTip.sideView));
      expect(g.tips, contains(GuideTip.portrait));
    });

    test('front patterns use a standing front template and frame', () {
      final g = PositioningGuide.forPattern(verticalPush);
      expect(g.posture, GuidePosture.standing);
      expect(g.view, CameraView.front);
      expect(g.expectedView, CameraView.front);
      expect(g.targetFrame, const Rect.fromLTRB(0.25, 0.08, 0.75, 0.92));
      expect(g.tips, contains(GuideTip.frontView));
      expect(g.tips, isNot(contains(GuideTip.sideView)));
    });

    test('horizontal side patterns use a side plank in landscape', () {
      for (final p in [horizontalPush, core]) {
        final g = PositioningGuide.forPattern(p);
        expect(g.posture, GuidePosture.plank, reason: p.id);
        expect(g.view, CameraView.side, reason: p.id);
        expect(g.landscape, isTrue, reason: p.id);
        expect(g.tips, containsAll([GuideTip.floor, GuideTip.landscape]));
      }
    });

    test(
      'a horizontal pattern seen from the front falls back to standing front',
      () {
        final g = PositioningGuide.forPattern(
          withView('core_stabilization', CameraView.front),
        );
        expect(g.posture, GuidePosture.standing);
        expect(g.view, CameraView.front);
      },
    );

    test(
      'CameraView.any falls back to standing front and skips the view check',
      () {
        final p = withView('any_view', CameraView.any);
        final g = PositioningGuide.forPattern(p);
        expect(g.posture, GuidePosture.standing);
        expect(g.view, CameraView.front);
        expect(g.expectedView, CameraView.any);
      },
    );

    test('every template joint lies inside the image', () {
      final guides = [
        PositioningGuide.forPattern(squat),
        PositioningGuide.forPattern(verticalPush),
        PositioningGuide.forPattern(horizontalPush),
      ];
      for (final g in guides) {
        for (final p in g.joints.values) {
          expect(p.dx, inInclusiveRange(0, 1));
          expect(p.dy, inInclusiveRange(0, 1));
        }
        expect(g.targetFrame.left, greaterThanOrEqualTo(0));
        expect(g.targetFrame.right, lessThanOrEqualTo(1));
      }
    });

    test(
      'standing templates put the head near 0.12 and the feet near 0.90',
      () {
        final g = PositioningGuide.forPattern(squat);
        expect(g.joints[BodyLandmark.nose]!.dy, closeTo(0.16, 0.05));
        expect(g.joints[BodyLandmark.leftAnkle]!.dy, closeTo(0.88, 0.03));
        expect(g.joints[BodyLandmark.leftFootIndex]!.dy, closeTo(0.90, 0.02));
        expect(g.targetFrame.top, closeTo(0.08, 0.01));
        expect(g.targetFrame.bottom, closeTo(0.92, 0.01));
      },
    );

    test('every built-in pattern has a template for its required joints', () {
      for (final p in PatternLibrary.all) {
        final g = PositioningGuide.forPattern(p);
        for (final l in [BodyLandmark.nose, ...p.requiredLandmarks]) {
          expect(g.joints.containsKey(l), isTrue, reason: '${p.id} needs $l');
        }
        expect(
          g.joints.containsKey(BodyLandmark.leftAnkle),
          isTrue,
          reason: p.id,
        );
        expect(
          g.joints.containsKey(BodyLandmark.rightAnkle),
          isTrue,
          reason: p.id,
        );
      }
    });

    test('the template itself is aligned for each posture', () {
      for (final p in [squat, verticalPush, horizontalPush]) {
        final g = PositioningGuide.forPattern(p);
        final a = assessFraming(poseFrom(g), p);
        expect(a.status, FramingStatus.aligned, reason: '${p.id}: $a');
        expect(a.issues, isEmpty, reason: p.id);
      }
    });
  });

  group('assessFraming issues', () {
    test('no pose is not visible', () {
      final a = assessFraming(null, squat);
      expect(a.status, FramingStatus.adjust);
      expect(a.top, FramingIssue.notVisible);
    });

    test('a required joint below the likelihood threshold is not visible', () {
      final g = PositioningGuide.forPattern(squat);
      final a = assessFraming(
        poseFrom(g, likelihoodOverride: {BodyLandmark.leftKnee: 0.2}),
        squat,
      );
      expect(a.issues, [FramingIssue.notVisible]);
    });

    test('a likelihood of exactly 0.6 counts as visible', () {
      final g = PositioningGuide.forPattern(squat);
      final a = assessFraming(poseFrom(g, likelihood: 0.6), squat);
      expect(a.status, FramingStatus.aligned);
    });

    test('a body much smaller than the frame is too far', () {
      final g = PositioningGuide.forPattern(squat);
      final a = assessFraming(poseFrom(g, map: scale(1, 0.5)), squat);
      expect(a.issues, [FramingIssue.tooFar]);
    });

    test('a head and feet cut off at the image edges is too close', () {
      final g = PositioningGuide.forPattern(squat);
      final a = assessFraming(poseFrom(g, map: scale(1, 1.4)), squat);
      expect(a.issues, [FramingIssue.tooClose]);
    });

    test('hidden ankles (feet out of frame) are too close', () {
      // elbowFlexion does not require the ankles, so only the framing check
      // (full body) reports them.
      const p = PatternLibrary.elbowFlexion;
      final g = PositioningGuide.forPattern(p);
      final a = assessFraming(
        poseFrom(
          g,
          likelihoodOverride: {
            BodyLandmark.leftAnkle: 0.1,
            BodyLandmark.rightAnkle: 0.1,
          },
        ),
        p,
      );
      expect(a.issues, [FramingIssue.tooClose]);
    });

    test('a side pattern seen from the front is a wrong view', () {
      // Front template (shoulders apart) used for a side pattern.
      final front = PositioningGuide.forPattern(verticalPush);
      final a = assessFraming(poseFrom(front), squat);
      expect(a.issues, [FramingIssue.wrongView]);
      expect(
        framingMessageKey(
          FramingIssue.wrongView,
          PositioningGuide.forPattern(squat),
        ),
        'frWrongViewSide',
      );
    });

    test('a front pattern seen side-on is a wrong view', () {
      final side = PositioningGuide.forPattern(squat);
      final a = assessFraming(poseFrom(side), verticalPush);
      expect(a.issues, [FramingIssue.wrongView]);
      expect(
        framingMessageKey(
          FramingIssue.wrongView,
          PositioningGuide.forPattern(verticalPush),
        ),
        'frWrongViewFront',
      );
    });

    test('a body shifted away from the centre is off centre', () {
      final g = PositioningGuide.forPattern(squat);
      final a = assessFraming(poseFrom(g, map: shift(0.25)), squat);
      expect(a.issues, [FramingIssue.offCentre]);
      expect(framingMessageKey(FramingIssue.offCentre, g), 'frOffCentre');
    });

    test(
      'issues are reported in order: too far, wrong view, then off centre',
      () {
        final front = PositioningGuide.forPattern(verticalPush);
        final a = assessFraming(
          poseFrom(
            front,
            map: (p) => Offset(p.dx + 0.25, 0.5 + (p.dy - 0.5) * 0.5),
          ),
          squat,
        );
        expect(a.issues, [
          FramingIssue.tooFar,
          FramingIssue.wrongView,
          FramingIssue.offCentre,
        ]);
        expect(a.top, FramingIssue.tooFar);
      },
    );

    test('a plank too close (head or feet cut along the body axis)', () {
      final g = PositioningGuide.forPattern(horizontalPush);
      final a = assessFraming(poseFrom(g, map: scale(1.2, 1)), horizontalPush);
      expect(a.issues, [FramingIssue.tooClose]);
    });

    test('a plank too far away', () {
      final g = PositioningGuide.forPattern(core);
      final a = assessFraming(poseFrom(g, map: scale(0.5, 1)), core);
      expect(a.issues, [FramingIssue.tooFar]);
    });

    test('CameraView.any never reports a wrong view', () {
      final p = withView('any_view', CameraView.any);
      final side = PositioningGuide.forPattern(squat);
      final a = assessFraming(poseFrom(side), p);
      expect(a.issues, isNot(contains(FramingIssue.wrongView)));
    });

    test('a nearly square aspect ratio does not change the aligned result', () {
      final g = PositioningGuide.forPattern(verticalPush);
      final a = assessFraming(poseFrom(g, aspect: 0.75), verticalPush);
      expect(a.status, FramingStatus.aligned);
    });
  });

  group('FramingTracker stability', () {
    BodyPose at(Duration t, {bool aligned = true}) {
      final g = PositioningGuide.forPattern(squat);
      return aligned
          ? poseFrom(g, at: t)
          : poseFrom(g, at: t, map: scale(1, 0.5));
    }

    Duration ms(int v) => Duration(milliseconds: v);

    test('aligned for less than one second is not ready', () {
      final tracker = FramingTracker(squat);
      expect(tracker.update(at(ms(0))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(500))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(999))).status, FramingStatus.aligned);
    });

    test('aligned for one second is ready', () {
      final tracker = FramingTracker(squat);
      tracker.update(at(ms(0)));
      tracker.update(at(ms(500)));
      expect(tracker.update(at(ms(1000))).status, FramingStatus.ready);
      expect(tracker.update(at(ms(1200))).status, FramingStatus.ready);
    });

    test('an issue restarts the timer', () {
      final tracker = FramingTracker(squat);
      tracker.update(at(ms(0)));
      tracker.update(at(ms(600)));
      final bad = tracker.update(at(ms(700), aligned: false));
      expect(bad.status, FramingStatus.adjust);
      expect(bad.top, FramingIssue.tooFar);
      expect(tracker.update(at(ms(800))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1200))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1600))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1700))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1800))).status, FramingStatus.ready);
    });

    test('a null pose restarts the timer', () {
      final tracker = FramingTracker(squat);
      tracker.update(at(ms(0)));
      expect(tracker.update(null).top, FramingIssue.notVisible);
      expect(tracker.update(at(ms(500))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(900))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1300))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1500))).status, FramingStatus.ready);
    });

    test('a gap longer than 500 ms restarts the timer', () {
      final tracker = FramingTracker(squat);
      tracker.update(at(ms(0)));
      tracker.update(at(ms(400)));
      expect(tracker.update(at(ms(1300))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1700))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(2100))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(2300))).status, FramingStatus.ready);
    });

    test('a gap of exactly 500 ms does not restart the timer', () {
      final tracker = FramingTracker(squat);
      tracker.update(at(ms(0)));
      tracker.update(at(ms(500)));
      expect(tracker.update(at(ms(1000))).status, FramingStatus.ready);
    });

    test('backwards timestamps restart the timer', () {
      final tracker = FramingTracker(squat);
      tracker.update(at(ms(5000)));
      tracker.update(at(ms(5900)));
      expect(tracker.update(at(ms(100))).status, FramingStatus.aligned);
    });

    test('reset clears the timer', () {
      final tracker = FramingTracker(squat);
      tracker.update(at(ms(0)));
      tracker.update(at(ms(400)));
      tracker.reset();
      expect(tracker.update(at(ms(500))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1000))).status, FramingStatus.aligned);
      expect(tracker.update(at(ms(1500))).status, FramingStatus.ready);
    });
  });
}
