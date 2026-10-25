/// Pre-set positioning aid: a ghost silhouette of the starting position, a
/// target frame and a framing check on the live pose.
///
/// This is a framing aid only. It does not check technique, range of motion
/// or safety. "Aligned" only means the body is visible and roughly placed in
/// the frame for the chosen camera view.
library;

import 'dart:ui' show Offset, Rect;

import '../biomechanics/geometry.dart';
import '../movement_patterns/movement_pattern.dart';
import '../pose_detection/pose_models.dart';

/// Body posture drawn by the ghost silhouette.
enum GuidePosture { standing, plank }

/// Setup tip rows in the positioning card.
enum GuideTip {
  sideView,
  frontView,
  distance,
  hipHeight,
  portrait,
  floor,
  landscape,
}

/// Framing problems. [tooClose] also covers a cut-off head or feet.
enum FramingIssue { notVisible, tooClose, tooFar, wrongView, offCentre }

/// [adjust]: at least one issue. [aligned]: no issue in this frame. [ready]:
/// aligned continuously for the stability time (set by [FramingTracker]).
enum FramingStatus { adjust, aligned, ready }

/// Thresholds for the framing check. Coordinates are normalised (0–1). The
/// values are estimates for a phone 2–3 m away, not validated measurements.
class FramingRules {
  const FramingRules({
    this.minLikelihood = 0.6,
    this.edgeMargin = 0.02,
    this.tooFarSpan = 0.45,
    this.tooCloseSpan = 0.92,
    this.centreTolerance = 0.15,
    this.facingRatio = 0.5,
    this.sideOnRatio = 0.3,
    this.stableFor = const Duration(seconds: 1),
    this.maxGap = const Duration(milliseconds: 500),
  });

  /// Minimum detector likelihood for a landmark to count as visible.
  final double minLikelihood;

  /// Landmarks closer than this to the image edge count as cut off.
  final double edgeMargin;

  /// Body extent (head to feet, along the body axis) below this is too far.
  final double tooFarSpan;

  /// Body extent above this fills the frame: too close.
  final double tooCloseSpan;

  /// The body centre may differ from the image centre by this much.
  final double centreTolerance;

  /// Side views: shoulder separation / torso length above this means the
  /// person faces the camera.
  final double facingRatio;

  /// Front views: shoulder separation / torso length below this means the
  /// person is side-on.
  final double sideOnRatio;

  /// Aligned frames must span this long before the status becomes ready.
  final Duration stableFor;

  /// A pose gap longer than this restarts the stability timer.
  final Duration maxGap;
}

/// Result of one framing check.
class FramingAssessment {
  const FramingAssessment(this.status, this.issues);

  final FramingStatus status;

  /// Issues in reporting order; empty when aligned.
  final List<FramingIssue> issues;

  /// The issue to show first, or null.
  FramingIssue? get top => issues.isEmpty ? null : issues.first;

  @override
  String toString() => 'FramingAssessment($status, $issues)';
}

/// Template skeleton, target frame and setup tips for one pattern. Built from
/// [MovementPattern.cameraView], which already includes the exercise's
/// variant override.
class PositioningGuide {
  const PositioningGuide._({
    required this.posture,
    required this.view,
    required this.expectedView,
    required this.joints,
    required this.targetFrame,
    required this.tips,
  });

  /// Chooses the template for [pattern]:
  /// - side patterns that lie horizontally (`horizontal_push`,
  ///   `core_stabilization`): side-on plank, phone on the floor, landscape;
  /// - other side patterns: standing side view, phone in portrait;
  /// - front patterns, and [CameraView.any]: standing front view.
  factory PositioningGuide.forPattern(MovementPattern pattern) {
    final expected = pattern.cameraView;
    if (expected == CameraView.side && _horizontalIds.contains(pattern.id)) {
      return const PositioningGuide._(
        posture: GuidePosture.plank,
        view: CameraView.side,
        expectedView: CameraView.side,
        joints: _plankJoints,
        targetFrame: _plankFrame,
        tips: [GuideTip.sideView, GuideTip.floor, GuideTip.landscape],
      );
    }
    if (expected == CameraView.side) {
      return const PositioningGuide._(
        posture: GuidePosture.standing,
        view: CameraView.side,
        expectedView: CameraView.side,
        joints: _sideJoints,
        targetFrame: _standingSideFrame,
        tips: [
          GuideTip.sideView,
          GuideTip.distance,
          GuideTip.hipHeight,
          GuideTip.portrait,
        ],
      );
    }
    return PositioningGuide._(
      posture: GuidePosture.standing,
      view: CameraView.front,
      expectedView: expected,
      joints: _frontJoints,
      targetFrame: _standingFrontFrame,
      tips: const [
        GuideTip.frontView,
        GuideTip.distance,
        GuideTip.hipHeight,
        GuideTip.portrait,
      ],
    );
  }

  static const _horizontalIds = {'horizontal_push', 'core_stabilization'};

  final GuidePosture posture;

  /// Template view: [CameraView.side] or [CameraView.front].
  final CameraView view;

  /// The view the pattern expects. [CameraView.any] skips the view check.
  final CameraView expectedView;

  /// Template skeleton in normalised image coordinates (origin top-left).
  final Map<BodyLandmark, Offset> joints;

  /// Where the body should sit, in normalised image coordinates.
  final Rect targetFrame;

  /// Setup tips for the positioning card, in display order.
  final List<GuideTip> tips;

  /// Recommended phone orientation for this posture.
  bool get landscape => posture == GuidePosture.plank;

  /// Bones drawn between template joints.
  static const bones = <(BodyLandmark, BodyLandmark)>[
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

  // Standing templates: head top ~0.12, feet ~0.90 inside a 0.08–0.92 frame.
  static const _standingSideFrame = Rect.fromLTRB(0.30, 0.08, 0.70, 0.92);
  static const _standingFrontFrame = Rect.fromLTRB(0.25, 0.08, 0.75, 0.92);
  static const _plankFrame = Rect.fromLTRB(0.05, 0.22, 0.95, 0.84);

  static const _sideJoints = <BodyLandmark, Offset>{
    BodyLandmark.nose: Offset(0.53, 0.16),
    BodyLandmark.leftShoulder: Offset(0.50, 0.26),
    BodyLandmark.rightShoulder: Offset(0.50, 0.26),
    BodyLandmark.leftElbow: Offset(0.50, 0.41),
    BodyLandmark.rightElbow: Offset(0.50, 0.41),
    BodyLandmark.leftWrist: Offset(0.50, 0.51),
    BodyLandmark.rightWrist: Offset(0.50, 0.51),
    BodyLandmark.leftHip: Offset(0.50, 0.53),
    BodyLandmark.rightHip: Offset(0.50, 0.53),
    BodyLandmark.leftKnee: Offset(0.52, 0.70),
    BodyLandmark.rightKnee: Offset(0.52, 0.70),
    BodyLandmark.leftAnkle: Offset(0.50, 0.87),
    BodyLandmark.rightAnkle: Offset(0.50, 0.87),
    BodyLandmark.leftFootIndex: Offset(0.56, 0.90),
    BodyLandmark.rightFootIndex: Offset(0.56, 0.90),
  };

  static const _frontJoints = <BodyLandmark, Offset>{
    BodyLandmark.nose: Offset(0.50, 0.16),
    BodyLandmark.leftShoulder: Offset(0.41, 0.26),
    BodyLandmark.rightShoulder: Offset(0.59, 0.26),
    BodyLandmark.leftElbow: Offset(0.38, 0.41),
    BodyLandmark.rightElbow: Offset(0.62, 0.41),
    BodyLandmark.leftWrist: Offset(0.37, 0.51),
    BodyLandmark.rightWrist: Offset(0.63, 0.51),
    BodyLandmark.leftHip: Offset(0.44, 0.53),
    BodyLandmark.rightHip: Offset(0.56, 0.53),
    BodyLandmark.leftKnee: Offset(0.43, 0.70),
    BodyLandmark.rightKnee: Offset(0.57, 0.70),
    BodyLandmark.leftAnkle: Offset(0.42, 0.87),
    BodyLandmark.rightAnkle: Offset(0.58, 0.87),
    BodyLandmark.leftFootIndex: Offset(0.40, 0.90),
    BodyLandmark.rightFootIndex: Offset(0.60, 0.90),
  };

  /// Side-on plank, head to the left, hands and toes on the floor (bottom).
  static const _plankJoints = <BodyLandmark, Offset>{
    BodyLandmark.nose: Offset(0.12, 0.38),
    BodyLandmark.leftShoulder: Offset(0.26, 0.42),
    BodyLandmark.rightShoulder: Offset(0.26, 0.42),
    BodyLandmark.leftElbow: Offset(0.27, 0.59),
    BodyLandmark.rightElbow: Offset(0.27, 0.59),
    BodyLandmark.leftWrist: Offset(0.26, 0.76),
    BodyLandmark.rightWrist: Offset(0.26, 0.76),
    BodyLandmark.leftHip: Offset(0.58, 0.54),
    BodyLandmark.rightHip: Offset(0.58, 0.54),
    BodyLandmark.leftKnee: Offset(0.76, 0.60),
    BodyLandmark.rightKnee: Offset(0.76, 0.60),
    BodyLandmark.leftAnkle: Offset(0.92, 0.66),
    BodyLandmark.rightAnkle: Offset(0.92, 0.66),
    BodyLandmark.leftFootIndex: Offset(0.95, 0.70),
    BodyLandmark.rightFootIndex: Offset(0.95, 0.70),
  };
}

/// Checks one pose against the pattern's framing template.
///
/// The nose, the pattern's required landmarks and both ankles must be visible
/// (the template is full body). Missing or cut-off joints are reported as
/// issues, never guessed. This is a single-frame check; [FramingTracker] adds
/// the stability time.
FramingAssessment assessFraming(
  BodyPose? pose,
  MovementPattern pattern, {
  FramingRules rules = const FramingRules(),
}) {
  const notVisible = FramingAssessment(FramingStatus.adjust, [
    FramingIssue.notVisible,
  ]);
  if (pose == null) return notVisible;
  bool seen(BodyLandmark l) => pose.visible(l, rules.minLikelihood) != null;

  final required = {BodyLandmark.nose, ...pattern.requiredLandmarks};
  if (required.any((l) => !seen(l))) return notVisible;

  final guide = PositioningGuide.forPattern(pattern);
  final feetSeen =
      seen(BodyLandmark.leftAnkle) && seen(BodyLandmark.rightAnkle);

  const extentLandmarks = [
    BodyLandmark.nose,
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
    BodyLandmark.leftAnkle,
    BodyLandmark.rightAnkle,
  ];
  final points = [
    for (final l in extentLandmarks) ?pose.visible(l, rules.minLikelihood),
  ];

  // Along the body axis: y when standing, x when lying (plank). A joint
  // outside the frame along the axis is cut off (too close); across the
  // axis it means the person is off centre.
  final plank = guide.posture == GuidePosture.plank;
  bool outside(double v) => v < rules.edgeMargin || v > 1 - rules.edgeMargin;
  final xCut = points.any((p) => outside(p.x));
  final yCut = points.any((p) => outside(p.y));
  final alongCut = plank ? xCut : yCut;
  final acrossCut = plank ? yCut : xCut;

  final along = [for (final p in points) plank ? p.x : p.y];
  final span = along.isEmpty
      ? 0.0
      : along.reduce((a, b) => a > b ? a : b) -
            along.reduce((a, b) => a < b ? a : b);

  final xs = [for (final p in points) p.x];
  final centreX = xs.isEmpty
      ? 0.5
      : (xs.reduce((a, b) => a < b ? a : b) +
                xs.reduce((a, b) => a > b ? a : b)) /
            2;

  final issues = <FramingIssue>[];
  if (!feetSeen || alongCut || span > rules.tooCloseSpan) {
    issues.add(FramingIssue.tooClose);
  } else if (span < rules.tooFarSpan) {
    issues.add(FramingIssue.tooFar);
  }

  if (guide.expectedView != CameraView.any) {
    final ratio = _shoulderSeparationRatio(pose);
    if (ratio != null) {
      final facing =
          guide.expectedView == CameraView.side && ratio > rules.facingRatio;
      final sideOn =
          guide.expectedView == CameraView.front && ratio < rules.sideOnRatio;
      if (facing || sideOn) issues.add(FramingIssue.wrongView);
    }
  }

  if (acrossCut || (centreX - 0.5).abs() > rules.centreTolerance) {
    issues.add(FramingIssue.offCentre);
  }

  return FramingAssessment(
    issues.isEmpty ? FramingStatus.aligned : FramingStatus.adjust,
    issues,
  );
}

/// Shoulder separation divided by torso length, both in aspect-corrected
/// units. Null when a shoulder or hip is not visible.
double? _shoulderSeparationRatio(BodyPose pose) {
  const min = 0.6;
  final ls = pose.visible(BodyLandmark.leftShoulder, min);
  final rs = pose.visible(BodyLandmark.rightShoulder, min);
  final lh = pose.visible(BodyLandmark.leftHip, min);
  final rh = pose.visible(BodyLandmark.rightHip, min);
  if (ls == null || rs == null || lh == null || rh == null) return null;
  final a = pose.aspectRatio;
  final separation = Vec2.of(ls, a) - Vec2.of(rs, a);
  final torso =
      Vec2.mid(Vec2.of(ls, a), Vec2.of(rs, a)) -
      Vec2.mid(Vec2.of(lh, a), Vec2.of(rh, a));
  if (torso.length < 1e-6) return null;
  return separation.length / torso.length;
}

/// Turns per-frame checks into a stable status. [FramingStatus.ready] is
/// reported only after the body has been aligned for [FramingRules.stableFor]
/// of pose time. Null poses, gaps longer than [FramingRules.maxGap] and
/// backwards timestamps restart the timer.
class FramingTracker {
  FramingTracker(this.pattern, {this.rules = const FramingRules()});

  final MovementPattern pattern;
  final FramingRules rules;

  Duration? _alignedSince;
  Duration? _last;

  FramingAssessment update(BodyPose? pose) {
    final base = assessFraming(pose, pattern, rules: rules);
    if (pose == null) {
      _alignedSince = null;
      return base;
    }
    final t = pose.timestamp;
    final last = _last;
    if (last != null && (t < last || t - last > rules.maxGap)) {
      _alignedSince = null;
    }
    _last = t;
    if (base.status != FramingStatus.aligned) {
      _alignedSince = null;
      return base;
    }
    final since = _alignedSince ??= t;
    final stable = t - since >= rules.stableFor;
    return FramingAssessment(
      stable ? FramingStatus.ready : FramingStatus.aligned,
      base.issues,
    );
  }

  void reset() {
    _alignedSince = null;
    _last = null;
  }
}
