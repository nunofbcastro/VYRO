import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/motion_engine/exercise_analysis/exercise_analysis_engine.dart';
import 'package:vyro/features/motion_engine/biomechanics/biomechanics_engine.dart';
import 'package:vyro/features/motion_engine/movement_patterns/movement_pattern.dart';
import 'package:vyro/features/motion_engine/pose_detection/pose_models.dart';
import 'package:vyro/features/motion_engine/repetition_counter/rep_counter_engine.dart';
import 'package:vyro/features/motion_engine/workout_camera/motion_sampling_policy.dart';
import 'package:vyro/features/motion_engine/workout_analysis_history/motion_history_repository.dart';
import 'synthetic_poses.dart';

void main() {
  test('a late return to rest cannot accept an overlong repetition', () {
    final counter = RepCounterEngine(const RepThresholds(rest: 170, peak: 90));
    counter.update(170, Duration.zero);
    counter.update(140, const Duration(milliseconds: 100));
    counter.update(90, const Duration(milliseconds: 500));
    expect(counter.update(170, const Duration(seconds: 11)).fullReps, 0);
  });
  test('hold time does not bridge an unobserved sample', () {
    final engine = ExerciseAnalysisEngine(
      pattern: const MovementPattern(
        id: 'hold_test',
        signal: SignalSpec(BioMetric.kneeLeft),
        requiredLandmarks: [
          BodyLandmark.leftHip,
          BodyLandmark.leftKnee,
          BodyLandmark.leftAnkle,
        ],
        mode: PatternMode.hold,
        holdMin: 160,
        holdMax: 180,
      ),
    );
    engine.process(syntheticPose(at: Duration.zero), Duration.zero);
    engine.process(null, const Duration(milliseconds: 100));
    engine.process(
      syntheticPose(at: const Duration(milliseconds: 200)),
      const Duration(milliseconds: 200),
    );
    expect(engine.summary().holdTime, Duration.zero);
  });
  test('readiness requires continuous visible landmarks', () {
    final gate = PoseReadinessGate();
    const joints = [
      BodyLandmark.leftHip,
      BodyLandmark.leftKnee,
      BodyLandmark.leftAnkle,
    ];
    expect(
      gate.accept(syntheticPose(at: Duration.zero), joints, Duration.zero),
      false,
    );
    expect(
      gate.accept(
        syntheticPose(at: const Duration(milliseconds: 500)),
        joints,
        const Duration(milliseconds: 500),
      ),
      true,
    );
    expect(gate.accept(null, joints, const Duration(milliseconds: 600)), false);
    expect(
      gate.accept(
        syntheticPose(at: const Duration(milliseconds: 700)),
        joints,
        const Duration(milliseconds: 700),
      ),
      false,
    );
  });
  test('adaptive sampling uses more samples in motion and bounds gaps', () {
    final policy = MotionSamplingPolicy();
    final rest = policy.interval(
      phase: RepPhase.atRest,
      quality: .9,
      latencyMs: 20,
    );
    final moving = policy.interval(
      phase: RepPhase.goingToPeak,
      quality: .9,
      latencyMs: 20,
    );
    expect(moving, lessThan(rest));
    expect(
      policy.interval(phase: RepPhase.goingToPeak, quality: .9, latencyMs: 500),
      lessThanOrEqualTo(const Duration(milliseconds: 250)),
    );
  });
  test(
    'manual counts preserve original observations and never create a score',
    () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final repo = MotionHistoryRepository(db);
      final id = await repo.save(
        exerciseKey: 'goblet_squat',
        startedAt: DateTime(2026),
        summary: const SetSummary(
          patternId: 'squat',
          duration: Duration(seconds: 10),
          fullReps: 4,
          partialReps: 1,
          events: [],
          meanConfidence: .8,
          observedRatio: .8,
          holdTime: Duration.zero,
          status: AnalysisStatus.withinCriteria,
        ),
      );
      await repo.correctCounts(id, full: 5, partial: 0);
      await repo.correctCounts(id, full: 6, partial: 0);
      final row = (await repo.watch().first).single;
      expect(row.fullReps, 6);
      expect(row.techniqueScore, isNull);
      final correction = (jsonDecode(row.eventsJson) as List).single as Map;
      expect(correction['detectedFull'], 4);
      expect(correction['confirmedFull'], 6);
      expect(MotionHistoryRepository.eventIds(row), isEmpty);
    },
  );
}
