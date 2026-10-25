import '../biomechanics/biomechanics_engine.dart';
import '../pose_detection/pose_models.dart';
import 'movement_pattern.dart';

/// Built-in reusable patterns.
///
/// Counting thresholds are camera estimates for repetition detection.
/// Technique checks are provisional (validated: false): they are shown as
/// "possible" issues and must be reviewed by a qualified professional before
/// being treated as criteria. They are not universal recommendations.
class PatternLibrary {
  PatternLibrary._();

  static const _legs = [
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
    BodyLandmark.leftKnee,
    BodyLandmark.rightKnee,
    BodyLandmark.leftAnkle,
    BodyLandmark.rightAnkle,
  ];
  static const _arms = [
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftElbow,
    BodyLandmark.rightElbow,
    BodyLandmark.leftWrist,
    BodyLandmark.rightWrist,
  ];
  static const _trunk = [
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
  ];

  static const _knees = SignalSpec(
    BioMetric.kneeLeft,
    right: BioMetric.kneeRight,
    side: SignalSide.bilateral,
  );
  static const _hips = SignalSpec(
    BioMetric.hipLeft,
    right: BioMetric.hipRight,
    side: SignalSide.bilateral,
  );
  static const _elbows = SignalSpec(
    BioMetric.elbowLeft,
    right: BioMetric.elbowRight,
    side: SignalSide.bilateral,
  );
  static const _shoulders = SignalSpec(
    BioMetric.shoulderLeft,
    right: BioMetric.shoulderRight,
    side: SignalSide.bilateral,
  );
  static const _lean = SignalSpec(BioMetric.trunkLean);
  static const _line = SignalSpec(BioMetric.bodyLine);

  static const _trunkStable = TechniqueCheck(
    id: 'trunk_lean_high',
    signal: _lean,
    above: true,
    threshold: 50,
    phase: CheckPhase.nearPeak,
    messageKey: 'mfTrunkStable',
  );
  static const _noSwing = TechniqueCheck(
    id: 'trunk_swing',
    signal: _lean,
    above: true,
    threshold: 18,
    messageKey: 'mfNoSwing',
  );
  static const _bodyAligned = TechniqueCheck(
    id: 'body_line_broken',
    signal: _line,
    above: false,
    threshold: 150,
    messageKey: 'mfBodyLine',
  );

  static const squat = MovementPattern(
    id: 'squat',
    signal: _knees,
    requiredLandmarks: [..._legs, ..._trunk],
    thresholds: RepThresholds(rest: 160, peak: 105),
    checks: [_trunkStable],
    minEccentric: Duration(milliseconds: 500),
  );

  static const hipHinge = MovementPattern(
    id: 'hip_hinge',
    signal: _hips,
    requiredLandmarks: [
      ..._trunk,
      BodyLandmark.leftKnee,
      BodyLandmark.rightKnee,
    ],
    thresholds: RepThresholds(rest: 165, peak: 115),
    minEccentric: Duration(milliseconds: 500),
  );

  static const horizontalPush = MovementPattern(
    id: 'horizontal_push',
    signal: SignalSpec(
      BioMetric.elbowLeft,
      right: BioMetric.elbowRight,
      side: SignalSide.bestSide,
    ),
    requiredLandmarks: [..._arms, ..._trunk],
    thresholds: RepThresholds(rest: 155, peak: 100),
    checks: [_bodyAligned],
    minEccentric: Duration(milliseconds: 400),
  );

  static const verticalPush = MovementPattern(
    id: 'vertical_push',
    eccentricTowardPeak: false,
    signal: _elbows,
    requiredLandmarks: [..._arms, ..._trunk],
    thresholds: RepThresholds(rest: 95, peak: 155),
    checks: [
      TechniqueCheck(
        id: 'lean_back',
        signal: _lean,
        above: true,
        threshold: 20,
        messageKey: 'mfNoArch',
      ),
    ],
    cameraView: CameraView.front,
  );

  static const horizontalPull = MovementPattern(
    id: 'horizontal_pull',
    eccentricTowardPeak: false,
    signal: SignalSpec(
      BioMetric.elbowLeft,
      right: BioMetric.elbowRight,
      side: SignalSide.bestSide,
    ),
    requiredLandmarks: [..._arms, ..._trunk],
    thresholds: RepThresholds(rest: 150, peak: 95),
  );

  static const verticalPull = MovementPattern(
    id: 'vertical_pull',
    eccentricTowardPeak: false,
    signal: _elbows,
    requiredLandmarks: [..._arms, ..._trunk],
    thresholds: RepThresholds(rest: 150, peak: 90),
    checks: [_noSwing],
    cameraView: CameraView.front,
  );

  static const elbowFlexion = MovementPattern(
    id: 'elbow_flexion',
    eccentricTowardPeak: false,
    signal: _elbows,
    requiredLandmarks: [..._arms, BodyLandmark.leftHip, BodyLandmark.rightHip],
    thresholds: RepThresholds(rest: 150, peak: 70),
    checks: [
      _noSwing,
      TechniqueCheck(
        id: 'elbow_drift',
        signal: _shoulders,
        above: true,
        threshold: 35,
        messageKey: 'mfElbowsIn',
      ),
    ],
    minEccentric: Duration(milliseconds: 400),
  );

  static const elbowExtension = MovementPattern(
    id: 'elbow_extension',
    eccentricTowardPeak: false,
    signal: _elbows,
    requiredLandmarks: [..._arms, BodyLandmark.leftHip, BodyLandmark.rightHip],
    thresholds: RepThresholds(rest: 85, peak: 150),
    checks: [
      TechniqueCheck(
        id: 'elbow_drift',
        signal: _shoulders,
        above: true,
        threshold: 35,
        messageKey: 'mfElbowsIn',
      ),
    ],
  );

  static const shoulderAbduction = MovementPattern(
    id: 'shoulder_abduction',
    eccentricTowardPeak: false,
    signal: _shoulders,
    requiredLandmarks: [..._arms, BodyLandmark.leftHip, BodyLandmark.rightHip],
    thresholds: RepThresholds(rest: 25, peak: 75),
    checks: [_noSwing],
    cameraView: CameraView.front,
    minEccentric: Duration(milliseconds: 400),
  );

  static const lunge = MovementPattern(
    id: 'lunge',
    signal: SignalSpec(
      BioMetric.kneeLeft,
      right: BioMetric.kneeRight,
      side: SignalSide.minimum,
    ),
    requiredLandmarks: [..._legs, ..._trunk],
    thresholds: RepThresholds(rest: 160, peak: 105),
    checks: [
      TechniqueCheck(
        id: 'trunk_lean_lunge',
        signal: _lean,
        above: true,
        threshold: 30,
        phase: CheckPhase.nearPeak,
        messageKey: 'mfTrunkUpright',
      ),
    ],
    minEccentric: Duration(milliseconds: 400),
  );

  static const trunkRotation = MovementPattern(
    id: 'trunk_rotation',
    signal: SignalSpec(BioMetric.trunkRotation),
    requiredLandmarks: _trunk,
    thresholds: RepThresholds(rest: 6, peak: 28, hysteresis: 5),
    cameraView: CameraView.front,
    experimental: true,
  );

  static const coreStabilization = MovementPattern(
    id: 'core_stabilization',
    signal: _line,
    requiredLandmarks: [
      ..._trunk,
      BodyLandmark.leftAnkle,
      BodyLandmark.rightAnkle,
    ],
    mode: PatternMode.hold,
    holdMin: 155,
    holdMax: 200,
    checks: [_bodyAligned],
  );

  static const all = <MovementPattern>[
    squat,
    hipHinge,
    horizontalPush,
    verticalPush,
    horizontalPull,
    verticalPull,
    elbowFlexion,
    elbowExtension,
    shoulderAbduction,
    lunge,
    trunkRotation,
    coreStabilization,
  ];

  static MovementPattern? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
