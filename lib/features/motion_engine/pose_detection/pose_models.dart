/// Engine-neutral body pose types. Detector implementations (ML Kit today)
/// convert their output into these, so the rest of the motion engine never
/// depends on a specific SDK and can be tested with synthetic landmarks.
library;

/// The 33 BlazePose / ML Kit landmarks used by the engine.
enum BodyLandmark {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  leftMouth,
  rightMouth,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// One landmark in normalised image coordinates: x and y in 0–1 (origin at
/// the top-left of the upright image), z relative depth (detector units),
/// [likelihood] the detector's in-frame confidence (0–1).
class PoseLandmark {
  const PoseLandmark({
    required this.x,
    required this.y,
    this.z = 0,
    required this.likelihood,
  });

  final double x;
  final double y;
  final double z;
  final double likelihood;

  PoseLandmark copyWith({double? x, double? y, double? z}) => PoseLandmark(
    x: x ?? this.x,
    y: y ?? this.y,
    z: z ?? this.z,
    likelihood: likelihood,
  );
}

/// All landmarks seen in one camera frame.
class BodyPose {
  const BodyPose({
    required this.landmarks,
    required this.timestamp,
    this.aspectRatio = 1,
  });

  final Map<BodyLandmark, PoseLandmark> landmarks;

  /// Capture time; analysis uses differences between frames, never the wall
  /// clock, so recorded sequences replay deterministically.
  final Duration timestamp;

  /// Width / height of the upright image, so angles are computed in a
  /// square space even though x and y are normalised separately.
  final double aspectRatio;

  PoseLandmark? operator [](BodyLandmark landmark) => landmarks[landmark];

  /// Landmark only when its likelihood reaches [minLikelihood].
  PoseLandmark? visible(BodyLandmark landmark, double minLikelihood) {
    final point = landmarks[landmark];
    return point != null && point.likelihood >= minLikelihood ? point : null;
  }
}
