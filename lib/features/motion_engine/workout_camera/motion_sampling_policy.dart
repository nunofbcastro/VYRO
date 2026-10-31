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
class PoseReadinessGate {
  PoseReadinessGate({
    this.requiredDuration = const Duration(milliseconds: 500),
  });
  final Duration requiredDuration;
  Duration? _since;
  Duration? _last;
  bool _lastVisible = false;

  /// Whether the last [accept] call saw every required landmark visible. True
  /// while the body is in the stability window; false only when it is absent
  /// or partly out of frame.
  bool get lastVisible => _lastVisible;

  bool accept(BodyPose? pose, Iterable<BodyLandmark> required, Duration time) {
    if (_last != null && time - _last! > const Duration(milliseconds: 500))
      _since = null;
    _last = time;
    final valid =
        pose != null &&
        required.every((l) {
          final p = pose[l];
          return p != null &&
              p.likelihood >= .6 &&
              p.x > .02 &&
              p.x < .98 &&
              p.y > .02 &&
              p.y < .98;
        });
    _lastVisible = valid;
    if (!valid) {
      _since = null;
      return false;
    }
    _since ??= time;
    return time - _since! >= requiredDuration;
  }

  void reset() {
    _since = null;
    _last = null;
  }
}
