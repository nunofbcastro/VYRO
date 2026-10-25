import 'dart:convert';

import '../movement_patterns/movement_pattern.dart';
import '../movement_patterns/pattern_library.dart';

/// How far the camera analysis can go for an exercise.
enum AnalysisSupport {
  /// Pattern fits and the camera usually sees the relevant joints.
  supported,

  /// Pattern fits but the view is often partial (lying, one arm, rotation).
  limited,

  /// No compatible pattern — rep counting and feedback are not offered.
  unsupported,
}

/// Exercise → pattern(s) + per-variant adjustments. Plain data, versioned,
/// serialisable to JSON so criteria can be reviewed outside the code.
class ExerciseAnalysisConfig {
  const ExerciseAnalysisConfig({
    required this.exerciseKey,
    required this.support,
    this.patternId,
    this.thresholds,
    this.disabledChecks = const [],
    this.eccentricTowardPeak,
    this.cameraView,
    this.noteKey,
    this.schemaVersion = currentSchema,
  });

  static const currentSchema = 1;

  final String exerciseKey;
  final AnalysisSupport support;
  final String? patternId;

  /// Variant-specific counting thresholds (replace the pattern's).
  final RepThresholds? thresholds;

  /// Pattern checks that do not apply to this variant (e.g. body line
  /// when lying on a bench).
  final List<String> disabledChecks;
  final bool? eccentricTowardPeak;
  final CameraView? cameraView;

  /// Optional VyroStrings key with setup advice or the reason it is limited.
  final String? noteKey;
  final int schemaVersion;

  /// The pattern with this exercise's adjustments applied.
  MovementPattern? resolve() {
    final base = patternId == null ? null : PatternLibrary.byId(patternId!);
    if (base == null || support == AnalysisSupport.unsupported) return null;
    return MovementPattern(
      id: base.id,
      signal: base.signal,
      requiredLandmarks: base.requiredLandmarks,
      thresholds: thresholds ?? base.thresholds,
      checks: [
        for (final c in base.checks)
          if (!disabledChecks.contains(c.id)) c,
      ],
      mode: base.mode,
      cameraView: cameraView ?? base.cameraView,
      minConfidence: base.minConfidence,
      holdMin: base.holdMin,
      holdMax: base.holdMax,
      minEccentric: base.minEccentric,
      eccentricTowardPeak: eccentricTowardPeak ?? base.eccentricTowardPeak,
      experimental: base.experimental,
    );
  }

  /// Schema validation; empty list = valid.
  List<String> validate() {
    final errors = <String>[];
    if (schemaVersion != currentSchema) {
      errors.add('$exerciseKey: unsupported schema $schemaVersion');
    }
    if (support == AnalysisSupport.unsupported) return errors;
    final base = patternId == null ? null : PatternLibrary.byId(patternId!);
    if (base == null) {
      errors.add('$exerciseKey: unknown pattern $patternId');
      return errors;
    }
    final t = thresholds ?? base.thresholds;
    if (base.mode == PatternMode.repetitions) {
      if (t == null) {
        errors.add('$exerciseKey: missing thresholds');
      } else {
        if (t.range < 10) errors.add('$exerciseKey: range below 10°');
        if (t.hysteresis * 2 >= t.range) {
          errors.add('$exerciseKey: hysteresis too large for range');
        }
        if (t.minRep >= t.maxRep) errors.add('$exerciseKey: minRep >= maxRep');
      }
    }
    for (final id in disabledChecks) {
      if (!base.checks.any((c) => c.id == id)) {
        errors.add('$exerciseKey: unknown check $id');
      }
    }
    return errors;
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'exerciseKey': exerciseKey,
    'support': support.name,
    if (patternId != null) 'patternId': patternId,
    if (thresholds != null) 'thresholds': thresholds!.toJson(),
    if (disabledChecks.isNotEmpty) 'disabledChecks': disabledChecks,
    if (eccentricTowardPeak != null) 'eccentricTowardPeak': eccentricTowardPeak,
    if (cameraView != null) 'cameraView': cameraView!.name,
    if (noteKey != null) 'noteKey': noteKey,
  };

  static ExerciseAnalysisConfig fromJson(Map<String, dynamic> json) =>
      ExerciseAnalysisConfig(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
        exerciseKey: json['exerciseKey'] as String,
        support: AnalysisSupport.values.byName(json['support'] as String),
        patternId: json['patternId'] as String?,
        thresholds: json['thresholds'] == null
            ? null
            : RepThresholds.fromJson(
                json['thresholds'] as Map<String, dynamic>,
              ),
        disabledChecks: [
          for (final id in (json['disabledChecks'] as List? ?? const [])) '$id',
        ],
        eccentricTowardPeak: json['eccentricTowardPeak'] as bool?,
        cameraView: json['cameraView'] == null
            ? null
            : CameraView.values.byName(json['cameraView'] as String),
        noteKey: json['noteKey'] as String?,
      );
}

/// Looks up the analysis configuration for catalogue exercises. Exercises
/// without a compatible pattern are explicitly unsupported (no invented
/// rules).
class ExerciseAnalysisRegistry {
  ExerciseAnalysisRegistry([List<ExerciseAnalysisConfig>? configs])
    : _configs = {for (final c in configs ?? defaultConfigs) c.exerciseKey: c};

  final Map<String, ExerciseAnalysisConfig> _configs;

  ExerciseAnalysisConfig configFor(String exerciseKey) =>
      _configs[exerciseKey] ??
      ExerciseAnalysisConfig(
        exerciseKey: exerciseKey,
        support: AnalysisSupport.unsupported,
        noteKey: 'maNoPattern',
      );

  bool canAnalyse(String exerciseKey) =>
      configFor(exerciseKey).support != AnalysisSupport.unsupported;

  /// All validation errors across the registry.
  List<String> validate() => [for (final c in _configs.values) ...c.validate()];

  String toJsonString() => const JsonEncoder.withIndent(
    '  ',
  ).convert([for (final c in _configs.values) c.toJson()]);

  static ExerciseAnalysisRegistry fromJsonString(String raw) =>
      ExerciseAnalysisRegistry([
        for (final item in jsonDecode(raw) as List)
          ExerciseAnalysisConfig.fromJson(item as Map<String, dynamic>),
      ]);

  static const defaultConfigs = <ExerciseAnalysisConfig>[
    ExerciseAnalysisConfig(
      exerciseKey: 'goblet_squat',
      support: AnalysisSupport.supported,
      patternId: 'squat',
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'split_squat',
      support: AnalysisSupport.supported,
      patternId: 'lunge',
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'reverse_lunge',
      support: AnalysisSupport.supported,
      patternId: 'lunge',
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'push_up',
      support: AnalysisSupport.supported,
      patternId: 'horizontal_push',
      noteKey: 'maSetupSideLow',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'pike_push_up',
      support: AnalysisSupport.limited,
      patternId: 'horizontal_push',
      disabledChecks: ['body_line_broken'],
      noteKey: 'maSetupSideLow',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'dumbbell_press',
      support: AnalysisSupport.limited,
      patternId: 'horizontal_push',
      disabledChecks: ['body_line_broken'],
      thresholds: RepThresholds(rest: 150, peak: 95),
      noteKey: 'maLimitedLying',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'shoulder_press',
      support: AnalysisSupport.supported,
      patternId: 'vertical_push',
      noteKey: 'maSetupFront',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'seated_row',
      support: AnalysisSupport.supported,
      patternId: 'horizontal_pull',
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'dumbbell_row',
      support: AnalysisSupport.limited,
      patternId: 'horizontal_pull',
      noteKey: 'maLimitedOneArm',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'face_pull',
      support: AnalysisSupport.limited,
      patternId: 'horizontal_pull',
      thresholds: RepThresholds(rest: 150, peak: 85),
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'lat_pulldown',
      support: AnalysisSupport.supported,
      patternId: 'vertical_pull',
      noteKey: 'maSetupFront',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'biceps_curl',
      support: AnalysisSupport.supported,
      patternId: 'elbow_flexion',
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'triceps_pushdown',
      support: AnalysisSupport.supported,
      patternId: 'elbow_extension',
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'lateral_raise',
      support: AnalysisSupport.supported,
      patternId: 'shoulder_abduction',
      noteKey: 'maSetupFront',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'hip_hinge',
      support: AnalysisSupport.supported,
      patternId: 'hip_hinge',
      noteKey: 'maSetupSide',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'glute_bridge',
      support: AnalysisSupport.limited,
      patternId: 'hip_hinge',
      thresholds: RepThresholds(rest: 125, peak: 165, hysteresis: 6),
      eccentricTowardPeak: false,
      noteKey: 'maLimitedLying',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'plank',
      support: AnalysisSupport.supported,
      patternId: 'core_stabilization',
      noteKey: 'maSetupSideLow',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'side_plank',
      support: AnalysisSupport.limited,
      patternId: 'core_stabilization',
      cameraView: CameraView.front,
      noteKey: 'maSetupFront',
    ),
    // No compatible, observable pattern yet: explicitly unsupported.
    ExerciseAnalysisConfig(
      exerciseKey: 'dead_bug',
      support: AnalysisSupport.unsupported,
      noteKey: 'maNoPattern',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'bird_dog',
      support: AnalysisSupport.unsupported,
      noteKey: 'maNoPattern',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'superman',
      support: AnalysisSupport.unsupported,
      noteKey: 'maNoPattern',
    ),
    ExerciseAnalysisConfig(
      exerciseKey: 'calf_raise',
      support: AnalysisSupport.unsupported,
      noteKey: 'maNoPattern',
    ),
  ];
}
