import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/biomechanics/biomechanics_engine.dart';
import 'package:vyro/features/motion_engine/biomechanics/geometry.dart';
import 'package:vyro/features/motion_engine/biomechanics/one_euro_filter.dart';
import 'package:vyro/features/motion_engine/exercise_analysis/exercise_analysis_engine.dart';
import 'package:vyro/features/motion_engine/exercise_registry/exercise_analysis_registry.dart';
import 'package:vyro/features/motion_engine/feedback_engine/feedback_engine.dart';
import 'package:vyro/features/motion_engine/movement_patterns/movement_pattern.dart';
import 'package:vyro/features/motion_engine/movement_patterns/pattern_library.dart';
import 'package:vyro/features/motion_engine/pose_detection/pose_models.dart';
import 'package:vyro/features/motion_engine/repetition_counter/rep_counter_engine.dart';

import 'synthetic_poses.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('geometry', () {
    test('interior angles', () {
      expect(
        angleAt(const Vec2(0, 0), const Vec2(1, 0), const Vec2(1, 1)),
        closeTo(90, 1e-9),
      );
      expect(
        angleAt(const Vec2(0, 0), const Vec2(1, 0), const Vec2(2, 0)),
        closeTo(180, 1e-9),
      );
      expect(
        angleAt(const Vec2(1, 0), const Vec2(1, 0), const Vec2(2, 0)),
        isNull,
      );
    });

    test('inclination from vertical and between lines', () {
      expect(
        inclinationFromVertical(const Vec2(0, 1), const Vec2(0, 0)),
        closeTo(0, 1e-9),
      );
      expect(
        inclinationFromVertical(const Vec2(0, 1), const Vec2(1, 0)),
        closeTo(45, 1e-9),
      );
      expect(
        angleBetweenLines(
          const Vec2(0, 0),
          const Vec2(1, 0),
          const Vec2(0, 1),
          const Vec2(1, 1),
        ),
        closeTo(0, 1e-9),
      );
    });

    test('aspect ratio is corrected before measuring', () {
      const p = PoseLandmark(x: 0.5, y: 0.5, likelihood: 1);
      expect(Vec2.of(p, 2).x, 1.0);
    });
  });

  test('one euro filter removes jitter and converges', () {
    final filter = OneEuroFilter();
    final random = math.Random(7);
    final raw = <double>[], out = <double>[];
    for (var i = 0; i < 120; i++) {
      final v = 100 + (random.nextDouble() - 0.5) * 10;
      raw.add(v);
      out.add(filter.filter(v, ms(i * 33)));
    }
    double spread(List<double> xs) {
      final tail = xs.skip(30).toList();
      final mean = tail.reduce((a, b) => a + b) / tail.length;
      return tail.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
          tail.length;
    }

    expect(spread(out), lessThan(spread(raw) / 3));
    expect(out.last, closeTo(100, 3));
  });

  group('rep counter', () {
    const t = RepThresholds(rest: 165, peak: 95);

    int countFull(
      List<({Duration at, double value})> curve, {
      RepCounterEngine? engine,
    }) {
      final counter = engine ?? RepCounterEngine(t);
      for (final s in curve) {
        counter.update(s.value, s.at);
      }
      return counter.fullReps;
    }

    test('counts full repetitions once each', () {
      expect(countFull(repCurve(rest: 165, peak: 95, reps: 5)), 5);
    });

    test('shallow reversals are partial, tiny movements are ignored', () {
      final counter = RepCounterEngine(t);
      for (final s in repCurve(rest: 165, peak: 125, reps: 3)) {
        counter.update(s.value, s.at);
      }
      expect(counter.fullReps, 0);
      expect(counter.partialReps, 3);

      final still = RepCounterEngine(t);
      for (final s in repCurve(rest: 165, peak: 155, reps: 4)) {
        still.update(s.value, s.at);
      }
      expect(still.fullReps + still.partialReps, 0);
    });

    test('too-fast movements are not counted', () {
      expect(
        countFull(repCurve(rest: 165, peak: 95, reps: 4, period: ms(400))),
        0,
      );
    });

    test('does not count before seeing the start position', () {
      final counter = RepCounterEngine(t);
      // Starts already at the bottom and only stands up once.
      for (var i = 0; i <= 20; i++) {
        counter.update(95 + i * 3.5, ms(i * 66));
      }
      expect(counter.fullReps, 0);
    });

    test('short tracking loss keeps the rep, long loss abandons it', () {
      final curve = repCurve(rest: 165, peak: 95, reps: 2);
      final brief = RepCounterEngine(t);
      for (final s in curve) {
        final lost = s.at > ms(1000) && s.at < ms(1500);
        brief.update(lost ? null : s.value, s.at);
      }
      expect(brief.fullReps, 2);

      final long = RepCounterEngine(t);
      RepEvent? abandoned;
      for (final s in curve) {
        final lost = s.at > ms(1100) && s.at < ms(2720);
        final u = long.update(lost ? null : s.value, s.at);
        if (u.event?.type == RepEventType.abandoned) abandoned = u.event;
      }
      expect(abandoned, isNotNull);
      expect(long.fullReps, 1); // Recovers and counts the second rep.
    });

    test('flags the end of a set after idling at rest', () {
      final counter = RepCounterEngine(
        t,
        setEndIdle: const Duration(seconds: 3),
      );
      var ended = false;
      final curve = repCurve(rest: 165, peak: 95, reps: 2);
      for (final s in curve) {
        counter.update(s.value, s.at);
      }
      final end = curve.last.at;
      for (var i = 1; i <= 60; i++) {
        if (counter.update(165, end + ms(i * 100)).setEnded) ended = true;
      }
      expect(ended, isTrue);
    });

    test('eccentric phase follows the pattern direction', () {
      RepEvent? run(bool towardPeak) {
        final counter = RepCounterEngine(t, eccentricTowardPeak: towardPeak);
        RepEvent? event;
        for (final s in repCurve(rest: 165, peak: 95, reps: 1)) {
          event = counter.update(s.value, s.at).event ?? event;
        }
        return event;
      }

      final squat = run(true)!;
      final curl = run(false)!;
      // Symmetric movement: both halves take about the same time (the
      // start/stop thresholds differ slightly, hence the tolerance)…
      expect(
        squat.eccentric!.inMilliseconds,
        closeTo(squat.concentric!.inMilliseconds, 200),
      );
      expect(squat.eccentric, greaterThan(ms(300)));
      // …and the labels swap with the pattern direction.
      expect(curl.eccentric, squat.concentric);
    });
  });

  group('biomechanics engine', () {
    test('measures knee and trunk angles from landmarks', () {
      final engine = BiomechanicsEngine();
      final frame = engine.process(
        syntheticPose(at: Duration.zero, kneeAngle: 90, trunkLean: 30),
      );
      expect(frame[BioMetric.kneeLeft]!.value, closeTo(90, 0.5));
      expect(frame[BioMetric.trunkLean]!.value, closeTo(30, 0.5));
      expect(frame.detectionQuality, closeTo(0.95, 1e-9));
    });

    test('hidden joints produce no metric and are reported missing', () {
      final engine = BiomechanicsEngine();
      final frame = engine.process(
        syntheticPose(
          at: Duration.zero,
          hidden: {BodyLandmark.leftKnee, BodyLandmark.rightKnee},
        ),
      );
      expect(frame[BioMetric.kneeLeft], isNull);
      expect(
        frame.missing,
        containsAll([BodyLandmark.leftKnee, BodyLandmark.rightKnee]),
      );
    });
  });

  group('exercise analysis', () {
    List<AnalysisUpdate> runSquat({
      double bottomLean = 10,
      Set<BodyLandmark> hidden = const {},
    }) {
      final engine = ExerciseAnalysisEngine(pattern: PatternLibrary.squat);
      return [
        for (final s in repCurve(
          rest: 172,
          peak: 88,
          reps: 3,
          period: ms(2400),
        ))
          engine.process(
            syntheticPose(
              at: s.at,
              kneeAngle: s.value,
              trunkLean: s.value < 110 ? bottomLean : 8,
              hidden: hidden,
            ),
            s.at,
          ),
      ];
    }

    test('clean squats are counted within criteria', () {
      final updates = runSquat();
      expect(updates.last.fullReps, 3);
      expect(
        updates.any((u) => u.status == AnalysisStatus.possibleIssue),
        isFalse,
      );
      expect(updates.last.status, AnalysisStatus.withinCriteria);
    });

    test('excessive trunk lean near the bottom becomes a possible issue', () {
      final engine = ExerciseAnalysisEngine(pattern: PatternLibrary.squat);
      for (final s in repCurve(
        rest: 172,
        peak: 88,
        reps: 3,
        period: ms(2400),
      )) {
        engine.process(
          syntheticPose(
            at: s.at,
            kneeAngle: s.value,
            trunkLean: s.value < 110 ? 65 : 8,
          ),
          s.at,
        );
      }
      final summary = engine.summary();
      expect(summary.fullReps, 3);
      expect(
        summary.events.where((e) => e.checkId == 'trunk_lean_high').length,
        3,
      );
      expect(summary.status, AnalysisStatus.possibleIssue);
      // Criteria are not professionally validated yet → no score.
      expect(summary.techniqueScore, isNull);
    });

    test('hidden knees are not observable and ask to show them', () {
      final updates = runSquat(
        hidden: {BodyLandmark.leftKnee, BodyLandmark.rightKnee},
      );
      expect(updates.last.fullReps, 0);
      expect(updates.last.status, AnalysisStatus.notObservable);
      expect(updates.last.feedback.map((f) => f.key), contains('mfSeeKnees'));
    });

    test('no person detected is not observable, summary inconclusive', () {
      final engine = ExerciseAnalysisEngine(pattern: PatternLibrary.squat);
      for (var i = 0; i < 30; i++) {
        engine.process(null, ms(i * 66));
      }
      expect(engine.summary().status, AnalysisStatus.inconclusive);
    });

    test('elbow flexion pattern counts curls from synthetic arms', () {
      final engine = ExerciseAnalysisEngine(
        pattern: PatternLibrary.elbowFlexion,
      );
      for (final s in repCurve(rest: 165, peak: 55, reps: 4)) {
        engine.process(syntheticPose(at: s.at, elbowAngle: s.value), s.at);
      }
      expect(engine.summary().fullReps, 4);
    });
  });

  group('registry', () {
    test('default configs validate and round-trip through JSON', () {
      final registry = ExerciseAnalysisRegistry();
      expect(registry.validate(), isEmpty);
      final copy = ExerciseAnalysisRegistry.fromJsonString(
        registry.toJsonString(),
      );
      expect(copy.validate(), isEmpty);
      expect(copy.configFor('glute_bridge').resolve()!.thresholds!.peak, 165);
    });

    test('similar exercises share patterns; unknown ones are unsupported', () {
      final registry = ExerciseAnalysisRegistry();
      expect(registry.configFor('split_squat').patternId, 'lunge');
      expect(registry.configFor('reverse_lunge').patternId, 'lunge');
      expect(registry.configFor('dumbbell_press').resolve()!.checks, isEmpty);
      expect(registry.canAnalyse('calf_raise'), isFalse);
      expect(registry.configFor('some_new_move').resolve(), isNull);
    });

    test('invalid configs are reported', () {
      const bad = ExerciseAnalysisConfig(
        exerciseKey: 'x',
        support: AnalysisSupport.supported,
        patternId: 'squat',
        thresholds: RepThresholds(rest: 100, peak: 95),
        disabledChecks: ['nope'],
      );
      expect(bad.validate().length, greaterThanOrEqualTo(2));
    });
  });

  group('feedback engine', () {
    test('setup problems outrank technique; low confidence is dropped', () {
      final engine = FeedbackEngine();
      final m = engine.offer(const [
        FeedbackCandidate(
          'mfTrunkStable',
          FeedbackLevel.warning,
          confidence: 0.9,
        ),
        FeedbackCandidate('mfSeeKnees', FeedbackLevel.setup),
      ], Duration.zero);
      expect(m!.key, 'mfSeeKnees');
      final weak = FeedbackEngine().offer(const [
        FeedbackCandidate(
          'mfTrunkStable',
          FeedbackLevel.warning,
          confidence: 0.3,
        ),
      ], Duration.zero);
      expect(weak, isNull);
    });

    test('messages are spaced and not repeated too often', () {
      final engine = FeedbackEngine();
      const rep = [FeedbackCandidate('mfRepDone', FeedbackLevel.success)];
      expect(engine.offer(rep, Duration.zero), isNotNull);
      expect(engine.offer(rep, ms(3000)), isNull); // cooldown
      expect(
        engine.offer(const [
          FeedbackCandidate('mfControlDescent', FeedbackLevel.warning),
        ], ms(1000)),
        isNull,
      ); // gap
      expect(
        engine.offer(const [
          FeedbackCandidate('mfControlDescent', FeedbackLevel.warning),
        ], ms(2500)),
        isNotNull,
      );
      expect(engine.offer(rep, ms(6500)), isNotNull);
    });
  });
}
