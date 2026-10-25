import 'dart:math' as math;

import '../pose_detection/pose_models.dart';

/// 2D point in an aspect-corrected space (x scaled by the image aspect ratio)
/// so angles are not distorted by non-square frames.
class Vec2 {
  const Vec2(this.x, this.y);
  final double x;
  final double y;

  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator *(double k) => Vec2(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);
  double dot(Vec2 o) => x * o.x + y * o.y;

  static Vec2 of(PoseLandmark p, double aspectRatio) =>
      Vec2(p.x * aspectRatio, p.y);

  static Vec2 mid(Vec2 a, Vec2 b) => Vec2((a.x + b.x) / 2, (a.y + b.y) / 2);
}

const _degrees = 180 / math.pi;

/// Interior angle at [b] formed by a–b–c, in degrees (0–180).
/// Returns null for degenerate (zero-length) segments.
double? angleAt(Vec2 a, Vec2 b, Vec2 c) {
  final ba = a - b;
  final bc = c - b;
  final la = ba.length;
  final lc = bc.length;
  if (la < 1e-6 || lc < 1e-6) return null;
  final cos = (ba.dot(bc) / (la * lc)).clamp(-1.0, 1.0);
  return math.acos(cos) * _degrees;
}

/// Angle between segment [from]→[to] and the vertical (image "down" axis),
/// in degrees (0 = vertical, 90 = horizontal). Used for trunk lean.
double? inclinationFromVertical(Vec2 from, Vec2 to) {
  final d = to - from;
  final l = d.length;
  if (l < 1e-6) return null;
  final cos = (d.y.abs() / l).clamp(0.0, 1.0);
  return math.acos(cos) * _degrees;
}

/// Angle between segment [from]→[to] and the horizontal, signed: positive
/// when [to] is higher in the image (smaller y).
double? signedInclinationFromHorizontal(Vec2 from, Vec2 to) {
  final d = to - from;
  if (d.length < 1e-6) return null;
  return math.atan2(-d.y, d.x.abs()) * _degrees;
}

/// Smallest angle between two lines (e.g. shoulder line vs hip line), 0–90°.
double? angleBetweenLines(Vec2 a1, Vec2 a2, Vec2 b1, Vec2 b2) {
  final u = a2 - a1;
  final v = b2 - b1;
  if (u.length < 1e-6 || v.length < 1e-6) return null;
  final cos = (u.dot(v).abs() / (u.length * v.length)).clamp(0.0, 1.0);
  return math.acos(cos) * _degrees;
}
