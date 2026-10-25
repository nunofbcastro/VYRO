import '../biomechanics/biomechanics_engine.dart';
import '../pose_detection/pose_models.dart';

/// How a left/right metric pair becomes one signal.
enum SignalSide {
  /// Confidence-weighted mean of both sides.
  bilateral,

  /// The side the camera sees best (side views).
  bestSide,

  /// The smaller value (e.g. the front knee in a lunge).
  minimum,

  /// The larger value.
  maximum,

  /// A single, non-paired metric.
  single,
}

class SignalSpec {
  const SignalSpec(this.left, {this.right, this.side = SignalSide.single});
  final BioMetric left;
  final BioMetric? right;
  final SignalSide side;

  MetricSample? read(BiomechanicsFrame frame) {
    final r = right;
    if (r == null || side == SignalSide.single) return frame[left];
    return switch (side) {
      SignalSide.bilateral => frame.bilateral(left, r),
      SignalSide.bestSide => frame.bestSide(left, r),
      SignalSide.minimum || SignalSide.maximum => _pick(frame, r),
      SignalSide.single => frame[left],
    };
  }

  MetricSample? _pick(BiomechanicsFrame frame, BioMetric r) {
    final a = frame[left], b = frame[r];
    if (a == null) return b;
    if (b == null) return a;
    final aFirst = side == SignalSide.minimum
        ? a.value <= b.value
        : a.value >= b.value;
    return aFirst ? a : b;
  }

  Map<String, Object?> toJson() => {
    'left': left.name,
    if (right != null) 'right': right!.name,
    'side': side.name,
  };

  static SignalSpec fromJson(Map<String, dynamic> json) => SignalSpec(
    BioMetric.values.byName(json['left'] as String),
    right: json['right'] == null
        ? null
        : BioMetric.values.byName(json['right'] as String),
    side: SignalSide.values.byName(json['side'] as String? ?? 'single'),
  );
}

/// Counting thresholds on the primary signal. A repetition leaves [rest],
/// reaches [peak] (within [hysteresis]) and returns to [rest].
///
/// These are counting thresholds for a camera estimate, not technique
/// recommendations; they are configurable per exercise.
class RepThresholds {
  const RepThresholds({
    required this.rest,
    required this.peak,
    this.hysteresis = 8,
    this.partialFraction = 0.5,
    this.minRep = const Duration(milliseconds: 600),
    this.maxRep = const Duration(seconds: 10),
  });

  final double rest;
  final double peak;
  final double hysteresis;

  /// Share of the full range a reversal must cover to count as a partial.
  final double partialFraction;
  final Duration minRep;
  final Duration maxRep;

  double get range => (peak - rest).abs();
  bool get decreasing => peak < rest;

  RepThresholds copyWith({double? rest, double? peak, double? hysteresis}) =>
      RepThresholds(
        rest: rest ?? this.rest,
        peak: peak ?? this.peak,
        hysteresis: hysteresis ?? this.hysteresis,
        partialFraction: partialFraction,
        minRep: minRep,
        maxRep: maxRep,
      );

  Map<String, Object?> toJson() => {
    'rest': rest,
    'peak': peak,
    'hysteresis': hysteresis,
    'partialFraction': partialFraction,
    'minRepMs': minRep.inMilliseconds,
    'maxRepMs': maxRep.inMilliseconds,
  };

  static RepThresholds fromJson(Map<String, dynamic> json) => RepThresholds(
    rest: (json['rest'] as num).toDouble(),
    peak: (json['peak'] as num).toDouble(),
    hysteresis: (json['hysteresis'] as num?)?.toDouble() ?? 8,
    partialFraction: (json['partialFraction'] as num?)?.toDouble() ?? 0.5,
    minRep: Duration(milliseconds: (json['minRepMs'] as num?)?.toInt() ?? 600),
    maxRep: Duration(
      milliseconds: (json['maxRepMs'] as num?)?.toInt() ?? 10000,
    ),
  );
}

/// When during a repetition a check is evaluated.
enum CheckPhase { anytime, nearPeak, moving }

enum CheckSeverity { info, warning }

/// One observable criterion. It fires only after [minFrames] consecutive
/// frames above [minConfidence], never from a single frame.
class TechniqueCheck {
  const TechniqueCheck({
    required this.id,
    required this.signal,
    required this.above,
    required this.threshold,
    required this.messageKey,
    this.phase = CheckPhase.moving,
    this.severity = CheckSeverity.warning,
    this.minConfidence = 0.6,
    this.minFrames = 5,
    this.validated = false,
  });

  final String id;
  final SignalSpec signal;

  /// Fires when the value is above (true) or below (false) [threshold].
  final bool above;
  final double threshold;

  /// Key in VyroStrings for the user message.
  final String messageKey;
  final CheckPhase phase;
  final CheckSeverity severity;
  final double minConfidence;
  final int minFrames;

  /// False until reviewed by a qualified professional; unvalidated checks
  /// are worded as "possible" and never produce a technique score.
  final bool validated;

  bool violatedBy(double value) =>
      above ? value > threshold : value < threshold;

  Map<String, Object?> toJson() => {
    'id': id,
    'signal': signal.toJson(),
    'above': above,
    'threshold': threshold,
    'messageKey': messageKey,
    'phase': phase.name,
    'severity': severity.name,
    'minConfidence': minConfidence,
    'minFrames': minFrames,
    'validated': validated,
  };

  static TechniqueCheck fromJson(Map<String, dynamic> json) => TechniqueCheck(
    id: json['id'] as String,
    signal: SignalSpec.fromJson(json['signal'] as Map<String, dynamic>),
    above: json['above'] as bool,
    threshold: (json['threshold'] as num).toDouble(),
    messageKey: json['messageKey'] as String,
    phase: CheckPhase.values.byName(json['phase'] as String? ?? 'moving'),
    severity: CheckSeverity.values.byName(
      json['severity'] as String? ?? 'warning',
    ),
    minConfidence: (json['minConfidence'] as num?)?.toDouble() ?? 0.6,
    minFrames: (json['minFrames'] as num?)?.toInt() ?? 5,
    validated: json['validated'] as bool? ?? false,
  );
}

enum PatternMode { repetitions, hold }

enum CameraView { side, front, any }

/// Reusable biomechanical pattern (squat, hinge, push, pull…). Exercises
/// reference patterns instead of having their own analysis code.
class MovementPattern {
  const MovementPattern({
    required this.id,
    required this.signal,
    required this.requiredLandmarks,
    this.thresholds,
    this.checks = const [],
    this.mode = PatternMode.repetitions,
    this.cameraView = CameraView.side,
    this.minConfidence = 0.55,
    this.holdMin,
    this.holdMax,
    this.minEccentric,
    this.eccentricTowardPeak = true,
    this.experimental = false,
  });

  final String id;

  /// Primary signal used to count reps (or to judge a hold).
  final SignalSpec signal;

  /// Landmarks that must be visible for the analysis to be meaningful.
  final List<BodyLandmark> requiredLandmarks;
  final RepThresholds? thresholds;
  final List<TechniqueCheck> checks;
  final PatternMode mode;
  final CameraView cameraView;
  final double minConfidence;

  /// For holds: the primary signal must stay within [holdMin]–[holdMax].
  final double? holdMin;
  final double? holdMax;

  /// Shorter lowering phases trigger a "control the descent" message.
  final Duration? minEccentric;

  /// True when moving from rest to peak is the lowering (eccentric) phase,
  /// as in squats and push-ups; false for curls, rows and presses.
  final bool eccentricTowardPeak;

  /// 2D estimate with known limits (e.g. rotation seen from the front).
  final bool experimental;

  MovementPattern withThresholds(RepThresholds? value) => MovementPattern(
    id: id,
    signal: signal,
    requiredLandmarks: requiredLandmarks,
    thresholds: value ?? thresholds,
    checks: checks,
    mode: mode,
    cameraView: cameraView,
    minConfidence: minConfidence,
    holdMin: holdMin,
    holdMax: holdMax,
    minEccentric: minEccentric,
    eccentricTowardPeak: eccentricTowardPeak,
    experimental: experimental,
  );
}
