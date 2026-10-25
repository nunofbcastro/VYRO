import 'dart:math' as math;

import 'package:vyro/features/motion_engine/pose_detection/pose_models.dart';

/// Reproducible side-view poses for tests.
///
/// [kneeAngle] is the hip–knee–ankle interior angle, [trunkLean] the trunk
/// angle from vertical (degrees), [elbowAngle] the shoulder–elbow–wrist
/// angle. Coordinates are normalised (aspect ratio 1).
BodyPose syntheticPose({
  required Duration at,
  double kneeAngle = 175,
  double trunkLean = 5,
  double elbowAngle = 170,
  double likelihood = 0.95,
  Set<BodyLandmark> hidden = const {},
}) {
  const shank = 0.16,
      thigh = 0.16,
      torso = 0.22,
      upperArm = 0.12,
      forearm = 0.11;
  const ankle = (x: 0.5, y: 0.88);
  final knee = (x: 0.5, y: ankle.y - shank);
  final k = kneeAngle * math.pi / 180;
  // Hip direction from knee: rotate "down" by the knee angle.
  final hip = (
    x: knee.x + thigh * math.sin(k),
    y: knee.y + thigh * math.cos(k),
  );
  final l = trunkLean * math.pi / 180;
  final shoulder = (
    x: hip.x + torso * math.sin(l),
    y: hip.y - torso * math.cos(l),
  );
  final elbow = (x: shoulder.x, y: shoulder.y + upperArm);
  final e = elbowAngle * math.pi / 180;
  // Wrist direction from elbow: rotate "up" (towards shoulder) by the angle.
  final wrist = (
    x: elbow.x + forearm * math.sin(e),
    y: elbow.y - forearm * math.cos(e),
  );

  PoseLandmark p(({double x, double y}) v, BodyLandmark which) => PoseLandmark(
    x: v.x,
    y: v.y,
    likelihood: hidden.contains(which) ? 0.1 : likelihood,
  );

  final map = <BodyLandmark, PoseLandmark>{};
  void both(BodyLandmark left, BodyLandmark right, ({double x, double y}) v) {
    map[left] = p(v, left);
    map[right] = p((x: v.x + 0.004, y: v.y), right);
  }

  both(BodyLandmark.leftAnkle, BodyLandmark.rightAnkle, ankle);
  both(BodyLandmark.leftKnee, BodyLandmark.rightKnee, knee);
  both(BodyLandmark.leftHip, BodyLandmark.rightHip, hip);
  both(BodyLandmark.leftShoulder, BodyLandmark.rightShoulder, shoulder);
  both(BodyLandmark.leftElbow, BodyLandmark.rightElbow, elbow);
  both(BodyLandmark.leftWrist, BodyLandmark.rightWrist, wrist);
  return BodyPose(landmarks: map, timestamp: at);
}

/// Smooth repetition curve between [rest] and [peak], [period] per rep,
/// starting and ending at rest, sampled at [fps].
List<({Duration at, double value})> repCurve({
  required double rest,
  required double peak,
  required int reps,
  Duration period = const Duration(seconds: 2),
  int fps = 15,
  Duration leadIn = const Duration(milliseconds: 600),
}) {
  final out = <({Duration at, double value})>[];
  final total = leadIn * 2 + period * reps;
  final step = Duration(microseconds: 1000000 ~/ fps);
  for (var t = Duration.zero; t <= total; t += step) {
    double value = rest;
    final inReps = t - leadIn;
    if (inReps > Duration.zero && inReps < period * reps) {
      final phase =
          (inReps.inMicroseconds % period.inMicroseconds) /
          period.inMicroseconds;
      final s = (1 - math.cos(2 * math.pi * phase)) / 2; // 0→1→0
      value = rest + (peak - rest) * s;
    }
    out.add((at: t, value: value));
  }
  return out;
}
