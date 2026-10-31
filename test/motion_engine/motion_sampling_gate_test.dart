import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/exercise_analysis/exercise_analysis_engine.dart';
import 'package:vyro/features/motion_engine/pose_detection/pose_models.dart';
import 'package:vyro/features/motion_engine/workout_camera/motion_coach_page.dart';
import 'package:vyro/features/motion_engine/workout_camera/motion_sampling_policy.dart';

import 'synthetic_poses.dart';

void main() {
  const interval = Duration(milliseconds: 100);

  group('MotionSamplingPolicy.shouldSample', () {
    test('skips frames inside the interval', () {
      expect(
        MotionSamplingPolicy.shouldSample(
          now: const Duration(milliseconds: 1050),
          lastFrame: const Duration(seconds: 1),
          interval: interval,
        ),
        isFalse,
      );
    });

    test('samples once the interval has elapsed', () {
      expect(
        MotionSamplingPolicy.shouldSample(
          now: const Duration(milliseconds: 1100),
          lastFrame: const Duration(seconds: 1),
          interval: interval,
        ),
        isTrue,
      );
    });

    test('resumes immediately after a clock reset (now before lastFrame)', () {
      // The old session ran to 60 s; the clock restarted at 0.2 s. Without the
      // rule, every frame would be skipped until the old timeline caught up.
      expect(
        MotionSamplingPolicy.shouldSample(
          now: const Duration(milliseconds: 200),
          lastFrame: const Duration(seconds: 60),
          interval: interval,
        ),
        isTrue,
      );
    });

    test('a zero lastFrame (fresh session) samples after one interval', () {
      expect(
        MotionSamplingPolicy.shouldSample(
          now: const Duration(milliseconds: 50),
          lastFrame: Duration.zero,
          interval: interval,
        ),
        isFalse,
      );
      expect(
        MotionSamplingPolicy.shouldSample(
          now: const Duration(milliseconds: 150),
          lastFrame: Duration.zero,
          interval: interval,
        ),
        isTrue,
      );
    });
  });

  group('PoseReadinessGate.lastVisible', () {
    const required = [BodyLandmark.leftHip, BodyLandmark.leftKnee];

    test('valid pose inside the stability window: visible, not accepted', () {
      final gate = PoseReadinessGate();
      final pose = syntheticPose(at: Duration.zero);
      expect(gate.accept(pose, required, Duration.zero), isFalse);
      expect(gate.lastVisible, isTrue);
      expect(
        gate.accept(pose, required, const Duration(milliseconds: 200)),
        isFalse,
      );
      expect(gate.lastVisible, isTrue);
    });

    test('stable pose is accepted after the window and stays visible', () {
      final gate = PoseReadinessGate();
      final pose = syntheticPose(at: Duration.zero);
      gate.accept(pose, required, Duration.zero);
      expect(
        gate.accept(pose, required, const Duration(milliseconds: 600)),
        isTrue,
      );
      expect(gate.lastVisible, isTrue);
    });

    test('null pose is not visible', () {
      final gate = PoseReadinessGate();
      expect(gate.accept(null, required, Duration.zero), isFalse);
      expect(gate.lastVisible, isFalse);
    });

    test('a required landmark hidden is not visible', () {
      final gate = PoseReadinessGate();
      final pose = syntheticPose(
        at: Duration.zero,
        hidden: const {BodyLandmark.leftKnee},
      );
      expect(gate.accept(pose, required, Duration.zero), isFalse);
      expect(gate.lastVisible, isFalse);
    });
  });

  group('analysisStatusColor', () {
    const scheme = ColorScheme.dark(
      primary: Color(0xFFB8F000),
      error: Color(0xFFFF5A5A),
    );

    test('good form is primary, issues and unobservable bodies are error', () {
      expect(
        analysisStatusColor(scheme, AnalysisStatus.withinCriteria),
        scheme.primary,
      );
      expect(
        analysisStatusColor(scheme, AnalysisStatus.possibleIssue),
        scheme.error,
      );
      expect(
        analysisStatusColor(scheme, AnalysisStatus.notObservable),
        scheme.error,
      );
    });

    test('waiting and inconclusive stay neutral', () {
      expect(analysisStatusColor(scheme, AnalysisStatus.waiting), isNull);
      expect(analysisStatusColor(scheme, AnalysisStatus.inconclusive), isNull);
    });
  });
}
