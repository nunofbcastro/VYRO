import '../movement_patterns/movement_pattern.dart';

enum RepPhase {
  /// Waiting to see the start position before counting.
  waitingForStart,

  /// At the start position.
  atRest,

  /// Moving from the start position toward the end of range.
  goingToPeak,

  /// End of range reached, returning to the start position.
  returning,

  /// Landmarks lost; the current repetition is on hold.
  paused,
}

enum RepEventType { full, partial, abandoned }

class RepEvent {
  const RepEvent({
    required this.type,
    required this.duration,
    required this.depth,
    this.eccentric,
    this.concentric,
  });

  final RepEventType type;
  final Duration duration;

  /// Fraction of the configured range reached (1 = full range).
  final double depth;

  /// Lowering phase length, when identifiable.
  final Duration? eccentric;
  final Duration? concentric;
}

/// Output of one [RepCounterEngine.update] call.
class RepUpdate {
  const RepUpdate({
    required this.phase,
    required this.progress,
    required this.fullReps,
    required this.partialReps,
    this.event,
    this.setEnded = false,
  });

  final RepPhase phase;

  /// 0 at the start position, 1 at the end of range (may exceed slightly).
  final double progress;
  final int fullReps;
  final int partialReps;
  final RepEvent? event;
  final bool setEnded;
}

/// Counts repetitions on one scalar signal with a hysteresis state machine.
///
/// Rules: it only arms after seeing the start position; a full rep must
/// reach the end of range and come back; a reversal that covered at least
/// `partialFraction` of the range is a partial rep; smaller movements are
/// ignored; reps faster than `minRep` or slower than `maxRep` are not
/// counted; losing tracking for longer than [lostTolerance] mid-rep
/// abandons that rep instead of guessing. Independent of Flutter.
class RepCounterEngine {
  RepCounterEngine(
    this.thresholds, {
    this.eccentricTowardPeak = true,
    this.lostTolerance = const Duration(milliseconds: 1500),
    this.setEndIdle = const Duration(seconds: 8),
  });

  final RepThresholds thresholds;
  final bool eccentricTowardPeak;
  final Duration lostTolerance;
  final Duration setEndIdle;

  RepPhase _phase = RepPhase.waitingForStart;
  RepPhase _beforePause = RepPhase.waitingForStart;
  int fullReps = 0;
  int partialReps = 0;
  Duration? _repStart;
  Duration? _peakAt;
  Duration? _lostAt;
  Duration? _restSince;
  bool _setEnded = false;
  double _maxProgress = 0;
  double _progress = 0;

  RepPhase get phase => _phase;

  double _toProgress(double value) =>
      (value - thresholds.rest) / (thresholds.peak - thresholds.rest);

  double get _h => thresholds.range == 0
      ? 0.1
      : (thresholds.hysteresis / thresholds.range).clamp(0.02, 0.4);

  /// Feeds one sample. [value] is null when the signal is not observable.
  RepUpdate update(double? value, Duration timestamp) {
    RepEvent? event;
    if (value == null) {
      if (_phase != RepPhase.paused) {
        _beforePause = _phase;
        _phase = RepPhase.paused;
        _lostAt = timestamp;
      } else if (_lostAt != null &&
          timestamp - _lostAt! > lostTolerance &&
          (_beforePause == RepPhase.goingToPeak ||
              _beforePause == RepPhase.returning)) {
        event = _abandon(timestamp);
        _beforePause = RepPhase.waitingForStart;
      }
      return _out(event);
    }

    if (_phase == RepPhase.paused) {
      final lostFor = timestamp - (_lostAt ?? timestamp);
      _phase =
          lostFor > lostTolerance &&
              (_beforePause == RepPhase.goingToPeak ||
                  _beforePause == RepPhase.returning)
          ? RepPhase.waitingForStart
          : _beforePause;
      _lostAt = null;
    }

    final p = _toProgress(value);
    _progress = p;
    final h = _h;

    switch (_phase) {
      case RepPhase.waitingForStart:
        if (p <= h) {
          _phase = RepPhase.atRest;
          _restSince = timestamp;
        }
      case RepPhase.atRest:
        if (p > h * 2) {
          _phase = RepPhase.goingToPeak;
          _repStart = timestamp;
          _peakAt = null;
          _maxProgress = p;
          _restSince = null;
        } else if (!_setEnded &&
            fullReps + partialReps > 0 &&
            _restSince != null &&
            timestamp - _restSince! > setEndIdle) {
          _setEnded = true;
          return _out(null, setEnded: true);
        }
      case RepPhase.goingToPeak:
        if (p > _maxProgress) {
          _maxProgress = p;
          _peakAt = timestamp;
        }
        if (p >= 1 - h) {
          _phase = RepPhase.returning;
        } else if (p <= h) {
          event = _finish(timestamp, reachedPeak: false);
        } else if (_tooLong(timestamp)) {
          event = _abandon(timestamp);
        }
      case RepPhase.returning:
        // The turning point is the deepest sample, not the threshold.
        if (p > _maxProgress) {
          _maxProgress = p;
          _peakAt = timestamp;
        }
        if (p <= h) {
          event = _finish(timestamp, reachedPeak: true);
        } else if (_tooLong(timestamp)) {
          event = _abandon(timestamp);
        }
      case RepPhase.paused:
        break;
    }
    return _out(event);
  }

  bool _tooLong(Duration t) =>
      _repStart != null && t - _repStart! > thresholds.maxRep;

  RepEvent? _finish(Duration t, {required bool reachedPeak}) {
    final start = _repStart ?? t;
    final duration = t - start;
    _phase = RepPhase.atRest;
    _restSince = t;
    _setEnded = false;
    final depth = _maxProgress;
    _maxProgress = 0;
    if (duration < thresholds.minRep) return null;
    if (reachedPeak) {
      fullReps++;
      final toPeak = (_peakAt ?? t) - start;
      final back = t - (_peakAt ?? t);
      return RepEvent(
        type: RepEventType.full,
        duration: duration,
        depth: depth,
        eccentric: eccentricTowardPeak ? toPeak : back,
        concentric: eccentricTowardPeak ? back : toPeak,
      );
    }
    if (depth >= thresholds.partialFraction) {
      partialReps++;
      return RepEvent(
        type: RepEventType.partial,
        duration: duration,
        depth: depth,
      );
    }
    return null; // Small accidental movement: ignored.
  }

  RepEvent _abandon(Duration t) {
    final duration = t - (_repStart ?? t);
    final depth = _maxProgress;
    _phase = RepPhase.waitingForStart;
    _maxProgress = 0;
    _repStart = null;
    return RepEvent(
      type: RepEventType.abandoned,
      duration: duration,
      depth: depth,
    );
  }

  RepUpdate _out(RepEvent? event, {bool setEnded = false}) => RepUpdate(
    phase: _phase,
    progress: _progress,
    fullReps: fullReps,
    partialReps: partialReps,
    event: event,
    setEnded: setEnded,
  );

  void reset() {
    _phase = RepPhase.waitingForStart;
    fullReps = 0;
    partialReps = 0;
    _repStart = null;
    _peakAt = null;
    _lostAt = null;
    _restSince = null;
    _setEnded = false;
    _maxProgress = 0;
    _progress = 0;
  }
}
