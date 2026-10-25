import '../pose_detection/pose_models.dart';
import 'geometry.dart';
import 'one_euro_filter.dart';

/// Joint and posture measurements the engine can extract from 2D landmarks.
enum BioMetric {
  /// Hip–knee–ankle interior angle (180 = straight leg).
  kneeLeft,
  kneeRight,

  /// Shoulder–hip–knee interior angle (180 = upright hip).
  hipLeft,
  hipRight,

  /// Shoulder–elbow–wrist interior angle (180 = straight arm).
  elbowLeft,
  elbowRight,

  /// Hip–shoulder–elbow angle (0 = arm down by the side).
  shoulderLeft,
  shoulderRight,

  /// Trunk (mid-hip → mid-shoulder) inclination from vertical, degrees.
  trunkLean,

  /// Shoulder–hip–ankle angle of the most visible side (180 = straight line).
  bodyLine,

  /// Angle between the shoulder line and the hip line (2D rotation proxy).
  trunkRotation,

  /// Wrist height above the shoulder, in torso lengths (+ = above).
  wristHeightLeft,
  wristHeightRight,
}

/// Landmarks each metric needs.
const metricLandmarks = <BioMetric, List<BodyLandmark>>{
  BioMetric.kneeLeft: [
    BodyLandmark.leftHip,
    BodyLandmark.leftKnee,
    BodyLandmark.leftAnkle,
  ],
  BioMetric.kneeRight: [
    BodyLandmark.rightHip,
    BodyLandmark.rightKnee,
    BodyLandmark.rightAnkle,
  ],
  BioMetric.hipLeft: [
    BodyLandmark.leftShoulder,
    BodyLandmark.leftHip,
    BodyLandmark.leftKnee,
  ],
  BioMetric.hipRight: [
    BodyLandmark.rightShoulder,
    BodyLandmark.rightHip,
    BodyLandmark.rightKnee,
  ],
  BioMetric.elbowLeft: [
    BodyLandmark.leftShoulder,
    BodyLandmark.leftElbow,
    BodyLandmark.leftWrist,
  ],
  BioMetric.elbowRight: [
    BodyLandmark.rightShoulder,
    BodyLandmark.rightElbow,
    BodyLandmark.rightWrist,
  ],
  BioMetric.shoulderLeft: [
    BodyLandmark.leftHip,
    BodyLandmark.leftShoulder,
    BodyLandmark.leftElbow,
  ],
  BioMetric.shoulderRight: [
    BodyLandmark.rightHip,
    BodyLandmark.rightShoulder,
    BodyLandmark.rightElbow,
  ],
  BioMetric.trunkLean: [
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
  ],
  BioMetric.bodyLine: [
    BodyLandmark.leftShoulder,
    BodyLandmark.leftHip,
    BodyLandmark.leftAnkle,
  ],
  BioMetric.trunkRotation: [
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
  ],
  BioMetric.wristHeightLeft: [
    BodyLandmark.leftShoulder,
    BodyLandmark.leftWrist,
    BodyLandmark.leftHip,
  ],
  BioMetric.wristHeightRight: [
    BodyLandmark.rightShoulder,
    BodyLandmark.rightWrist,
    BodyLandmark.rightHip,
  ],
};

/// One smoothed measurement and how much the detector trusted its inputs.
class MetricSample {
  const MetricSample(this.value, this.confidence);
  final double value;

  /// Lowest likelihood among the landmarks used (0–1).
  final double confidence;
}

/// Measurements for one frame.
class BiomechanicsFrame {
  const BiomechanicsFrame({
    required this.timestamp,
    required this.metrics,
    required this.detectionQuality,
    required this.outOfFrame,
    required this.missing,
  });

  final Duration timestamp;
  final Map<BioMetric, MetricSample> metrics;

  /// Mean likelihood of the main body landmarks (0–1).
  final double detectionQuality;

  /// Main landmarks touching the image border (body partly out of frame).
  final Set<BodyLandmark> outOfFrame;

  /// Main landmarks below the likelihood threshold.
  final Set<BodyLandmark> missing;

  MetricSample? operator [](BioMetric metric) => metrics[metric];

  /// Mean of the available left/right values (e.g. both knees), weighted by
  /// confidence; falls back to whichever side is visible.
  MetricSample? bilateral(BioMetric left, BioMetric right) {
    final l = metrics[left];
    final r = metrics[right];
    if (l == null) return r;
    if (r == null) return l;
    final w = l.confidence + r.confidence;
    return MetricSample(
      (l.value * l.confidence + r.value * r.confidence) / w,
      l.confidence < r.confidence ? l.confidence : r.confidence,
    );
  }

  /// Side with the higher confidence (for side-view exercises).
  MetricSample? bestSide(BioMetric left, BioMetric right) {
    final l = metrics[left];
    final r = metrics[right];
    if (l == null) return r;
    if (r == null) return l;
    return l.confidence >= r.confidence ? l : r;
  }
}

const mainLandmarks = [
  BodyLandmark.leftShoulder,
  BodyLandmark.rightShoulder,
  BodyLandmark.leftElbow,
  BodyLandmark.rightElbow,
  BodyLandmark.leftWrist,
  BodyLandmark.rightWrist,
  BodyLandmark.leftHip,
  BodyLandmark.rightHip,
  BodyLandmark.leftKnee,
  BodyLandmark.rightKnee,
  BodyLandmark.leftAnkle,
  BodyLandmark.rightAnkle,
];

/// Turns [BodyPose]s into smoothed joint angles and posture metrics.
///
/// Independent of Flutter and of the detector. Metrics whose landmarks are
/// below [minLikelihood] are simply absent from the frame (never guessed);
/// filters reset after [resetAfter] without data so stale values are not
/// blended into new ones.
class BiomechanicsEngine {
  BiomechanicsEngine({
    this.minLikelihood = 0.5,
    this.borderMargin = 0.02,
    this.resetAfter = const Duration(milliseconds: 600),
  });

  final double minLikelihood;
  final double borderMargin;
  final Duration resetAfter;

  final _filters = <BioMetric, OneEuroFilter>{};
  final _lastSeen = <BioMetric, Duration>{};

  BiomechanicsFrame process(BodyPose pose) {
    final raw = _measure(pose);
    final smoothed = <BioMetric, MetricSample>{};
    for (final entry in raw.entries) {
      final last = _lastSeen[entry.key];
      final filter = _filters.putIfAbsent(entry.key, OneEuroFilter.new);
      if (last != null && pose.timestamp - last > resetAfter) filter.reset();
      _lastSeen[entry.key] = pose.timestamp;
      smoothed[entry.key] = MetricSample(
        filter.filter(entry.value.value, pose.timestamp),
        entry.value.confidence,
      );
    }

    var sum = 0.0;
    final missing = <BodyLandmark>{};
    final outOfFrame = <BodyLandmark>{};
    for (final landmark in mainLandmarks) {
      final p = pose[landmark];
      sum += p?.likelihood ?? 0;
      if (p == null || p.likelihood < minLikelihood) {
        missing.add(landmark);
      } else if (p.x < borderMargin ||
          p.x > 1 - borderMargin ||
          p.y < borderMargin ||
          p.y > 1 - borderMargin) {
        outOfFrame.add(landmark);
      }
    }
    return BiomechanicsFrame(
      timestamp: pose.timestamp,
      metrics: smoothed,
      detectionQuality: sum / mainLandmarks.length,
      outOfFrame: outOfFrame,
      missing: missing,
    );
  }

  /// Filtered rate of change of [metric] (units per second).
  double velocity(BioMetric metric) => _filters[metric]?.velocity ?? 0;

  void reset() {
    _filters.clear();
    _lastSeen.clear();
  }

  Map<BioMetric, MetricSample> _measure(BodyPose pose) {
    final ar = pose.aspectRatio;
    Vec2? v(BodyLandmark l) {
      final p = pose.visible(l, minLikelihood);
      return p == null ? null : Vec2.of(p, ar);
    }

    double conf(List<BodyLandmark> ls) =>
        ls.map((l) => pose[l]?.likelihood ?? 0).reduce((a, b) => a < b ? a : b);

    final out = <BioMetric, MetricSample>{};
    void put(BioMetric metric, double? value, List<BodyLandmark> used) {
      if (value != null) out[metric] = MetricSample(value, conf(used));
    }

    void joint(BioMetric metric) {
      final ls = metricLandmarks[metric]!;
      final a = v(ls[0]), b = v(ls[1]), c = v(ls[2]);
      if (a == null || b == null || c == null) return;
      put(metric, angleAt(a, b, c), ls);
    }

    for (final m in const [
      BioMetric.kneeLeft,
      BioMetric.kneeRight,
      BioMetric.hipLeft,
      BioMetric.hipRight,
      BioMetric.elbowLeft,
      BioMetric.elbowRight,
      BioMetric.shoulderLeft,
      BioMetric.shoulderRight,
    ]) {
      joint(m);
    }

    final ls = v(BodyLandmark.leftShoulder), rs = v(BodyLandmark.rightShoulder);
    final lh = v(BodyLandmark.leftHip), rh = v(BodyLandmark.rightHip);
    if (ls != null && rs != null && lh != null && rh != null) {
      final used = metricLandmarks[BioMetric.trunkLean]!;
      put(
        BioMetric.trunkLean,
        inclinationFromVertical(Vec2.mid(lh, rh), Vec2.mid(ls, rs)),
        used,
      );
      put(BioMetric.trunkRotation, angleBetweenLines(ls, rs, lh, rh), used);
    } else {
      // Side view: one shoulder/hip pair is enough for lean.
      final s = ls ?? rs, h = lh ?? rh;
      if (s != null && h != null) {
        put(BioMetric.trunkLean, inclinationFromVertical(h, s), [
          ls != null ? BodyLandmark.leftShoulder : BodyLandmark.rightShoulder,
          lh != null ? BodyLandmark.leftHip : BodyLandmark.rightHip,
        ]);
      }
    }

    // Body line on whichever side is more visible.
    MetricSample? line(BodyLandmark s, BodyLandmark h, BodyLandmark a) {
      final vs = v(s), vh = v(h), va = v(a);
      if (vs == null || vh == null || va == null) return null;
      final angle = angleAt(vs, vh, va);
      return angle == null ? null : MetricSample(angle, conf([s, h, a]));
    }

    final left = line(
      BodyLandmark.leftShoulder,
      BodyLandmark.leftHip,
      BodyLandmark.leftAnkle,
    );
    final right = line(
      BodyLandmark.rightShoulder,
      BodyLandmark.rightHip,
      BodyLandmark.rightAnkle,
    );
    final bodyLine = left == null
        ? right
        : right == null
        ? left
        : (left.confidence >= right.confidence ? left : right);
    if (bodyLine != null) out[BioMetric.bodyLine] = bodyLine;

    void wrist(
      BioMetric metric,
      BodyLandmark s,
      BodyLandmark w,
      BodyLandmark h,
    ) {
      final vs = v(s), vw = v(w), vh = v(h);
      if (vs == null || vw == null || vh == null) return;
      final torso = (vh - vs).length;
      if (torso < 1e-3) return;
      put(metric, (vs.y - vw.y) / torso, [s, w, h]);
    }

    wrist(
      BioMetric.wristHeightLeft,
      BodyLandmark.leftShoulder,
      BodyLandmark.leftWrist,
      BodyLandmark.leftHip,
    );
    wrist(
      BioMetric.wristHeightRight,
      BodyLandmark.rightShoulder,
      BodyLandmark.rightWrist,
      BodyLandmark.rightHip,
    );
    return out;
  }
}
