import '../pose_detection/pose_models.dart';
import '../repetition_counter/rep_counter_engine.dart';

/// Bounds temporal gaps while reducing work during stable rest.
class MotionSamplingPolicy {
  /// Whether a frame at [now] should be analysed. [lastFrame] is the time of
  /// the last analysed frame. A [now] earlier than [lastFrame] means the clock
  /// was reset (a new session): sample at once instead of skipping until the
  /// old timeline catches up.
  static bool shouldSample({
    required Duration now,
    required Duration lastFrame,
    required Duration interval,
  }) => now < lastFrame || now - lastFrame >= interval;

  Duration interval({
    required RepPhase phase,
    required double quality,
    required double latencyMs,
    double progressChange = 0,
  }) {
    final moving =
        phase == RepPhase.goingToPeak ||
        phase == RepPhase.returning ||
        progressChange.abs() > .025;
    final target = moving
        ? 66
        : quality < .45
        ? 120
        : 166;
    return Duration(
      milliseconds: target.clamp(latencyMs.ceil().clamp(66, 220), 250),
    );
  }
}

/// Stable visibility is a prerequisite; it does not certify camera perspective.
///
/// Counting starts after [requiredDuration] with most required joints visible.
/// Once that happens, a brief dropout (a knee hidden for one or two frames,
/// common in a side view) keeps the gate open so the rep in progress is not
/// dropped. A longer loss, or a gap over [gapReset], closes it again.
class PoseReadinessGate {
  PoseReadinessGate({
    this.requiredDuration = const Duration(milliseconds: 500),
    this.dropoutGrace = const Duration(milliseconds: 400),
  });
  final Duration requiredDuration;
  final Duration dropoutGrace;

  /// A missing pose longer than this (slow inference, camera stall) restarts
  /// the window. It is wider than one accurate-model frame.
  static const gapReset = Duration(milliseconds: 1200);

  /// Share of the required landmarks that must be visible. A side view hides
  /// the far leg; demanding every joint meant the set never started.
  static const visibleFraction = 0.6;

  static const minLikelihood = 0.45;

  Duration? _since;
  Duration? _last;
  Duration? _invalidSince;
  bool _latched = false;
  bool _lastVisible = false;

  /// Whether the last [accept] call saw enough of the body. During a short
  /// dropout this is false while [accept] still returns true.
  bool get lastVisible => _lastVisible;

  /// True once the body has been stable long enough to start counting, and
  /// stays true through a short dropout.
  bool accept(BodyPose? pose, Iterable<BodyLandmark> required, Duration time) {
    if (_last != null && time - _last! > gapReset) {
      _since = null;
      _latched = false;
      _invalidSince = null;
    }
    _last = time;
    final valid = _enoughVisible(pose, required);
    _lastVisible = valid;
    if (valid) {
      _invalidSince = null;
      _since ??= time;
      if (time - _since! >= requiredDuration) _latched = true;
      return _latched;
    }
    if (!_latched) {
      _since = null;
      return false;
    }
    _invalidSince ??= time;
    if (time - _invalidSince! > dropoutGrace) {
      _latched = false;
      _since = null;
      _invalidSince = null;
      return false;
    }
    return true;
  }

  void reset() {
    _since = null;
    _last = null;
    _invalidSince = null;
    _latched = false;
  }

  static bool _enoughVisible(BodyPose? pose, Iterable<BodyLandmark> required) {
    if (pose == null) return false;
    final list = required.toList();
    if (list.isEmpty) return true;
    var seen = 0;
    for (final landmark in list) {
      final p = pose[landmark];
      if (p != null &&
          p.likelihood >= minLikelihood &&
          p.x >= -0.02 &&
          p.x <= 1.02 &&
          p.y >= -0.02 &&
          p.y <= 1.02) {
        seen++;
      }
    }
    return seen / list.length >= visibleFraction;
  }
}
