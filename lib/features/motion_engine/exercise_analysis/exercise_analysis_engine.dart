import '../biomechanics/biomechanics_engine.dart';
import '../feedback_engine/feedback_engine.dart';
import '../movement_patterns/movement_pattern.dart';
import '../pose_detection/pose_models.dart';
import '../repetition_counter/rep_counter_engine.dart';

/// The four outcomes VYRO distinguishes, plus "waiting" before data exists.
enum AnalysisStatus {
  waiting,

  /// Enough data and no checked criterion was exceeded.
  withinCriteria,

  /// A configured criterion was exceeded with sufficient confidence.
  possibleIssue,

  /// The relevant joints are not visible.
  notObservable,

  /// Some data, but not enough to say anything.
  inconclusive,
}

/// A technique event recorded during the set.
class TechniqueEvent {
  const TechniqueEvent({
    required this.checkId,
    required this.messageKey,
    required this.at,
    required this.confidence,
    required this.repIndex,
    required this.validated,
  });

  final String checkId;
  final String messageKey;
  final Duration at;
  final double confidence;

  /// 1-based repetition during which it happened (0 = before the first).
  final int repIndex;
  final bool validated;

  Map<String, Object> toJson() => {
    'checkId': checkId,
    'at': at.inMilliseconds,
    'confidence': double.parse(confidence.toStringAsFixed(2)),
    'rep': repIndex,
    'validated': validated,
  };
}

class AnalysisUpdate {
  const AnalysisUpdate({
    required this.status,
    required this.phase,
    required this.progress,
    required this.fullReps,
    required this.partialReps,
    required this.detectionQuality,
    required this.feedback,
    required this.holdTime,
    this.repEvent,
    this.setEnded = false,
  });

  final AnalysisStatus status;
  final RepPhase phase;
  final double progress;
  final int fullReps;
  final int partialReps;
  final double detectionQuality;

  /// Messages the feedback engine may choose from this frame.
  final List<FeedbackCandidate> feedback;

  /// Time spent inside the hold range (hold patterns only).
  final Duration holdTime;
  final RepEvent? repEvent;
  final bool setEnded;
}

/// End-of-set result.
class SetSummary {
  const SetSummary({
    required this.patternId,
    required this.duration,
    required this.fullReps,
    required this.partialReps,
    required this.events,
    required this.meanConfidence,
    required this.observedRatio,
    required this.holdTime,
    required this.status,
    this.techniqueScore,
  });

  final String patternId;
  final Duration duration;
  final int fullReps;
  final int partialReps;
  final List<TechniqueEvent> events;
  final double meanConfidence;

  /// Share of frames in which the primary signal was observable.
  final double observedRatio;
  final Duration holdTime;
  final AnalysisStatus status;

  /// Only computed when every active check is validated by a professional;
  /// null otherwise (the default today).
  final double? techniqueScore;

  SetSummary withUserCounts(int full, int partial) => SetSummary(
    patternId: patternId,
    duration: duration,
    fullReps: full,
    partialReps: partial,
    events: events,
    meanConfidence: meanConfidence,
    observedRatio: observedRatio,
    holdTime: holdTime,
    status: status,
  );
}

/// Combines biomechanics, a movement pattern, the rep counter and the
/// technique checks for one set. Pure Dart; feed it [BodyPose]s (or null
/// when no person is detected).
class ExerciseAnalysisEngine {
  ExerciseAnalysisEngine({
    required this.pattern,
    BiomechanicsEngine? biomechanics,
  }) : biomechanics = biomechanics ?? BiomechanicsEngine(),
       counter = pattern.thresholds == null
           ? null
           : RepCounterEngine(
               pattern.thresholds!,
               eccentricTowardPeak: pattern.eccentricTowardPeak,
             );

  final MovementPattern pattern;
  final BiomechanicsEngine biomechanics;
  final RepCounterEngine? counter;

  final _events = <TechniqueEvent>[];
  final _violationsSince = <String, Duration>{};
  final _firedThisRep = <String>{};
  Duration? _start;
  Duration? _last;
  int _frames = 0;
  int _observed = 0;
  double _confidenceSum = 0;
  Duration _hold = Duration.zero;
  Duration? _lastHoldTick;
  bool _activeIssue = false;

  static const _visibilityMessages = <BodyLandmark, String>{
    BodyLandmark.leftKnee: 'mfSeeKnees',
    BodyLandmark.rightKnee: 'mfSeeKnees',
    BodyLandmark.leftAnkle: 'mfSeeFeet',
    BodyLandmark.rightAnkle: 'mfSeeFeet',
    BodyLandmark.leftHip: 'mfSeeHips',
    BodyLandmark.rightHip: 'mfSeeHips',
    BodyLandmark.leftWrist: 'mfSeeArms',
    BodyLandmark.rightWrist: 'mfSeeArms',
    BodyLandmark.leftElbow: 'mfSeeArms',
    BodyLandmark.rightElbow: 'mfSeeArms',
  };

  AnalysisUpdate process(BodyPose? pose, Duration timestamp) {
    if (_last != null && timestamp < _last!)
      return _result(AnalysisStatus.inconclusive, null, const [], 0);
    if (_last != null &&
        timestamp - _last! > const Duration(milliseconds: 500)) {
      _lastHoldTick = null;
      _violationsSince.clear();
      counter?.interrupt();
    }
    _start ??= timestamp;
    _last = timestamp;
    _frames++;
    final feedback = <FeedbackCandidate>[];

    if (pose == null) {
      _lastHoldTick = null;
      _violationsSince.clear();
      feedback.add(const FeedbackCandidate('mfNoPerson', FeedbackLevel.setup));
      return _result(
        AnalysisStatus.notObservable,
        counter?.update(null, timestamp),
        feedback,
        0,
      );
    }

    final frame = biomechanics.process(pose);
    final required = pattern.requiredLandmarks;
    final missing = required.where(frame.missing.contains).toList();
    final outside = required.where(frame.outOfFrame.contains).toList();
    final sample = pattern.signal.read(frame);
    final usable = sample != null && sample.confidence >= pattern.minConfidence;

    // Visibility feedback, most specific first.
    if (missing.length > required.length * 0.3) {
      final key = missing
          .map((l) => _visibilityMessages[l])
          .firstWhere((k) => k != null, orElse: () => 'mfPartlyVisible');
      feedback.add(FeedbackCandidate(key!, FeedbackLevel.setup));
    } else if (outside.isNotEmpty) {
      feedback.add(
        const FeedbackCandidate('mfAdjustCamera', FeedbackLevel.setup),
      );
    } else if (frame.detectionQuality < 0.45) {
      feedback.add(const FeedbackCandidate('mfLowLight', FeedbackLevel.setup));
    }

    if (!usable && feedback.isEmpty) {
      // The counting signal itself is not visible: say which joints.
      final signalLandmarks = [
        ...?metricLandmarks[pattern.signal.left],
        if (pattern.signal.right != null)
          ...?metricLandmarks[pattern.signal.right!],
      ];
      final key = signalLandmarks
          .where(frame.missing.contains)
          .map((l) => _visibilityMessages[l])
          .firstWhere((k) => k != null, orElse: () => 'mfPartlyVisible');
      feedback.add(FeedbackCandidate(key!, FeedbackLevel.setup));
    }

    if (!usable) {
      _violationsSince.clear();
      _lastHoldTick = null;
      return _result(
        missing.isEmpty
            ? AnalysisStatus.inconclusive
            : AnalysisStatus.notObservable,
        counter?.update(null, timestamp),
        feedback,
        frame.detectionQuality,
      );
    }

    _observed++;
    _confidenceSum += sample.confidence;

    RepUpdate? rep;
    if (pattern.mode == PatternMode.hold) {
      final inRange =
          sample.value >= (pattern.holdMin ?? double.negativeInfinity) &&
          sample.value <= (pattern.holdMax ?? double.infinity);
      if (inRange && _lastHoldTick != null) {
        final dt = timestamp - _lastHoldTick!;
        if (dt < const Duration(milliseconds: 500)) _hold += dt;
      }
      _lastHoldTick = inRange ? timestamp : null;
    } else {
      rep = counter?.update(sample.value, timestamp);
      final event = rep?.event;
      if (event != null) {
        _firedThisRep.clear();
        if (event.type == RepEventType.full) {
          feedback.add(
            const FeedbackCandidate('mfRepDone', FeedbackLevel.success),
          );
          final minEcc = pattern.minEccentric;
          if (minEcc != null &&
              event.eccentric != null &&
              event.eccentric! < minEcc) {
            _record(
              'fast_eccentric',
              'mfControlDescent',
              timestamp,
              sample.confidence,
              false,
            );
            feedback.add(
              FeedbackCandidate(
                'mfControlDescent',
                FeedbackLevel.warning,
                confidence: sample.confidence,
              ),
            );
          }
        } else if (event.type == RepEventType.partial) {
          feedback.add(
            const FeedbackCandidate('mfPartialRep', FeedbackLevel.info),
          );
        }
      }
    }

    // Technique checks over consecutive frames.
    _activeIssue = false;
    final phase = rep?.phase ?? counter?.phase;
    final progress = rep?.progress ?? 0;
    for (final check in pattern.checks) {
      final value = check.signal.read(frame);
      final inPhase = switch (check.phase) {
        CheckPhase.anytime => true,
        CheckPhase.nearPeak =>
          pattern.mode == PatternMode.hold || progress >= 0.75,
        CheckPhase.moving =>
          pattern.mode == PatternMode.hold ||
              phase == RepPhase.goingToPeak ||
              phase == RepPhase.returning,
      };
      if (value == null || value.confidence < check.minConfidence || !inPhase) {
        _violationsSince.remove(check.id);
        continue;
      }
      if (!check.violatedBy(value.value)) {
        _violationsSince.remove(check.id);
        continue;
      }
      final since = _violationsSince.putIfAbsent(check.id, () => timestamp);
      // Preserve legacy thresholds as elapsed time at their reference 15 fps.
      if (timestamp - since >=
          Duration(milliseconds: (check.minFrames - 1) * 66)) {
        _activeIssue = true;
        feedback.add(
          FeedbackCandidate(
            check.messageKey,
            FeedbackLevel.warning,
            confidence: value.confidence,
          ),
        );
        if (_firedThisRep.add(check.id)) {
          _record(
            check.id,
            check.messageKey,
            timestamp,
            value.confidence,
            check.validated,
          );
        }
      }
    }

    final status = _activeIssue
        ? AnalysisStatus.possibleIssue
        : (counter?.fullReps ?? 0) + (counter?.partialReps ?? 0) > 0 ||
              _hold > Duration.zero
        ? AnalysisStatus.withinCriteria
        : AnalysisStatus.waiting;
    return _result(status, rep, feedback, frame.detectionQuality);
  }

  void _record(
    String id,
    String key,
    Duration at,
    double confidence,
    bool validated,
  ) {
    _events.add(
      TechniqueEvent(
        checkId: id,
        messageKey: key,
        at: at - (_start ?? at),
        confidence: confidence,
        repIndex: (counter?.fullReps ?? 0) + (counter?.partialReps ?? 0) + 1,
        validated: validated,
      ),
    );
  }

  AnalysisUpdate _result(
    AnalysisStatus status,
    RepUpdate? rep,
    List<FeedbackCandidate> feedback,
    double quality,
  ) => AnalysisUpdate(
    status: status,
    phase: rep?.phase ?? counter?.phase ?? RepPhase.waitingForStart,
    progress: rep?.progress ?? 0,
    fullReps: counter?.fullReps ?? 0,
    partialReps: counter?.partialReps ?? 0,
    detectionQuality: quality,
    feedback: feedback,
    holdTime: _hold,
    repEvent: rep?.event,
    setEnded: rep?.setEnded ?? false,
  );

  SetSummary summary() {
    final observedRatio = _frames == 0 ? 0.0 : _observed / _frames;
    final allValidated =
        pattern.checks.isNotEmpty && pattern.checks.every((c) => c.validated);
    final reps = (counter?.fullReps ?? 0) + (counter?.partialReps ?? 0);
    final status = observedRatio < 0.6
        ? AnalysisStatus.inconclusive
        : _events.isNotEmpty
        ? AnalysisStatus.possibleIssue
        : (reps > 0 || _hold > Duration.zero)
        ? AnalysisStatus.withinCriteria
        : AnalysisStatus.inconclusive;
    double? score;
    if (allValidated && reps > 0 && observedRatio >= 0.8) {
      final repsWithIssues = _events.map((e) => e.repIndex).toSet().length;
      score = ((reps - repsWithIssues) / reps).clamp(0.0, 1.0);
    }
    return SetSummary(
      patternId: pattern.id,
      duration: (_last ?? Duration.zero) - (_start ?? Duration.zero),
      fullReps: counter?.fullReps ?? 0,
      partialReps: counter?.partialReps ?? 0,
      events: List.unmodifiable(_events),
      meanConfidence: _observed == 0 ? 0 : _confidenceSum / _observed,
      observedRatio: observedRatio,
      holdTime: _hold,
      status: status,
      techniqueScore: score,
    );
  }

  void interrupt() {
    counter?.interrupt();
    biomechanics.reset();
    _lastHoldTick = null;
    _violationsSince.clear();
    _firedThisRep.clear();
  }
}
