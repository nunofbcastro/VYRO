import 'package:flutter/material.dart';

import '../movement_patterns/movement_pattern.dart';
import '../pose_detection/pose_models.dart';
import 'positioning_guide.dart';

/// Strings key for a framing issue. [FramingIssue.wrongView] depends on the
/// view the exercise expects.
String framingMessageKey(FramingIssue issue, PositioningGuide guide) =>
    switch (issue) {
      FramingIssue.notVisible => 'frNotVisible',
      FramingIssue.tooClose => 'frTooClose',
      FramingIssue.tooFar => 'frTooFar',
      FramingIssue.offCentre => 'frOffCentre',
      FramingIssue.wrongView =>
        guide.expectedView == CameraView.front
            ? 'frWrongViewFront'
            : 'frWrongViewSide',
    };

/// Strings key and icon for each setup tip row.
String guideTipKey(GuideTip tip) => switch (tip) {
  GuideTip.sideView => 'frTipSideView',
  GuideTip.frontView => 'frTipFrontView',
  GuideTip.distance => 'frTipDistance',
  GuideTip.hipHeight => 'frTipHipHeight',
  GuideTip.portrait => 'frTipPortrait',
  GuideTip.floor => 'frTipFloor',
  GuideTip.landscape => 'frTipLandscape',
};

IconData guideTipIcon(GuideTip tip) => switch (tip) {
  GuideTip.sideView => Icons.directions_walk_rounded,
  GuideTip.frontView => Icons.person_outline_rounded,
  GuideTip.distance => Icons.straighten_rounded,
  GuideTip.hipHeight => Icons.height_rounded,
  GuideTip.portrait => Icons.stay_current_portrait_rounded,
  GuideTip.floor => Icons.vertical_align_bottom_rounded,
  GuideTip.landscape => Icons.stay_current_landscape_rounded,
};

/// Draws the target frame and a ghost silhouette over the camera preview.
///
/// Paint in the same box as the camera image (the `FittedBox` box in
/// `MotionCoachPage`), so normalised template coordinates line up with the
/// image. Front-camera previews are mirrored, as the skeleton is. The ghost is
/// accent-coloured when [aligned] and neutral otherwise; it is a low-opacity
/// aid and never blocks touches (the painter sits under the controls).
class PositioningOverlayPainter extends CustomPainter {
  PositioningOverlayPainter({
    required this.guide,
    required this.aligned,
    required this.accent,
    required this.neutral,
    this.mirror = false,
  });

  final PositioningGuide guide;
  final bool aligned;
  final Color accent;
  final Color neutral;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = guide.targetFrame;
    final rect = Rect.fromLTRB(
      (mirror ? 1 - frame.right : frame.left) * size.width,
      frame.top * size.height,
      (mirror ? 1 - frame.left : frame.right) * size.width,
      frame.bottom * size.height,
    );
    final rounded = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.shortestSide * 0.04),
    );
    final framePaint = Paint()
      ..color = (aligned ? accent : neutral).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.004;
    _drawDashed(canvas, Path()..addRRect(rounded), framePaint);

    Offset at(BodyLandmark l) {
      final p = guide.joints[l]!;
      final x = mirror ? 1 - p.dx : p.dx;
      return Offset(x * size.width, p.dy * size.height);
    }

    final color = (aligned ? accent : neutral).withValues(
      alpha: aligned ? 0.55 : 0.45,
    );
    final stroke = size.shortestSide * 0.022;
    final bone = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (a, b) in PositioningGuide.bones) {
      canvas.drawLine(at(a), at(b), bone);
    }
    final joint = Paint()..color = color;
    canvas.drawCircle(at(BodyLandmark.nose), stroke * 1.9, joint);
    for (final l in guide.joints.keys) {
      if (l == BodyLandmark.nose) continue;
      canvas.drawCircle(at(l), stroke * 0.6, joint);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 10.0, gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(PositioningOverlayPainter old) =>
      old.guide.posture != guide.posture ||
      old.guide.expectedView != guide.expectedView ||
      old.aligned != aligned ||
      old.accent != accent ||
      old.neutral != neutral ||
      old.mirror != mirror;
}

/// Top status line: the framing issue, or the ready message.
class FramingStatusPill extends StatelessWidget {
  const FramingStatusPill({super.key, required this.text, required this.ready});

  final String text;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ready ? const Color(0xFF71DB9B) : theme.colorScheme.primary;
    return Semantics(
      liveRegion: true,
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC0B0D10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: accent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact setup card: one icon row per tip.
class PositioningTipsCard extends StatelessWidget {
  const PositioningTipsCard({super.key, this.title, required this.rows});

  /// Optional heading; the page may draw its own collapsible header.
  final String? title;

  /// Icon and text for each row.
  final List<(IconData, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null) ...[
          Text(heading, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
        ],
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
