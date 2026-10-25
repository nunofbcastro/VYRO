import 'package:flutter/material.dart';

import '../pose_detection/pose_models.dart';

/// Draws detected landmarks and limbs over the camera preview. Joints below
/// [minLikelihood] are omitted rather than drawn in a guessed place.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({
    required this.pose,
    required this.color,
    this.mirror = false,
    this.minLikelihood = 0.5,
  });

  final BodyPose? pose;
  final Color color;

  /// Front camera previews are mirrored, so landmarks are too.
  final bool mirror;
  final double minLikelihood;

  static const _bones = [
    (BodyLandmark.leftShoulder, BodyLandmark.rightShoulder),
    (BodyLandmark.leftHip, BodyLandmark.rightHip),
    (BodyLandmark.leftShoulder, BodyLandmark.leftHip),
    (BodyLandmark.rightShoulder, BodyLandmark.rightHip),
    (BodyLandmark.leftShoulder, BodyLandmark.leftElbow),
    (BodyLandmark.leftElbow, BodyLandmark.leftWrist),
    (BodyLandmark.rightShoulder, BodyLandmark.rightElbow),
    (BodyLandmark.rightElbow, BodyLandmark.rightWrist),
    (BodyLandmark.leftHip, BodyLandmark.leftKnee),
    (BodyLandmark.leftKnee, BodyLandmark.leftAnkle),
    (BodyLandmark.rightHip, BodyLandmark.rightKnee),
    (BodyLandmark.rightKnee, BodyLandmark.rightAnkle),
    (BodyLandmark.leftAnkle, BodyLandmark.leftFootIndex),
    (BodyLandmark.rightAnkle, BodyLandmark.rightFootIndex),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose;
    if (p == null) return;
    Offset? at(BodyLandmark l) {
      final point = p.visible(l, minLikelihood);
      if (point == null) return null;
      final x = mirror ? 1 - point.x : point.x;
      return Offset(x * size.width, point.y * size.height);
    }

    final bone = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = size.shortestSide * 0.012
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = Colors.white;
    for (final (a, b) in _bones) {
      final pa = at(a), pb = at(b);
      if (pa != null && pb != null) canvas.drawLine(pa, pb, bone);
    }
    for (final l in BodyLandmark.values.skip(11)) {
      final pt = at(l);
      if (pt != null) canvas.drawCircle(pt, size.shortestSide * 0.012, joint);
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      old.pose != pose || old.mirror != mirror || old.color != color;
}
