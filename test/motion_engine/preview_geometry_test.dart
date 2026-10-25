import 'dart:ui' show Size;

import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/workout_camera/preview_geometry.dart';

void main() {
  // A typical sensor frame as reported by the camera plugin (landscape).
  const sensor = Size(640, 480);

  group('isLandscapePreview', () {
    test('only the two landscape orientations are landscape', () {
      expect(isLandscapePreview(DeviceOrientation.landscapeLeft), isTrue);
      expect(isLandscapePreview(DeviceOrientation.landscapeRight), isTrue);
      expect(isLandscapePreview(DeviceOrientation.portraitUp), isFalse);
      expect(isLandscapePreview(DeviceOrientation.portraitDown), isFalse);
    });
  });

  group('uprightPreviewSize', () {
    test('landscape keeps the sensor frame as it is', () {
      expect(uprightPreviewSize(sensor, landscape: true), const Size(640, 480));
    });

    test('portrait swaps width and height', () {
      expect(
        uprightPreviewSize(sensor, landscape: false),
        const Size(480, 640),
      );
    });

    test('the box keeps the image ratio in both orientations (no stretch)', () {
      final landscape = uprightPreviewSize(sensor, landscape: true);
      final portrait = uprightPreviewSize(sensor, landscape: false);
      // CameraPreview uses sensor aspect in landscape and its inverse in
      // portrait; the box must match exactly or the image is distorted.
      expect(landscape.width / landscape.height, closeTo(640 / 480, 1e-9));
      expect(portrait.width / portrait.height, closeTo(480 / 640, 1e-9));
      expect(
        portrait.width / portrait.height,
        closeTo(1 / (landscape.width / landscape.height), 1e-9),
      );
    });

    test('the same sensor frame gives a different box per orientation', () {
      expect(
        uprightPreviewSize(sensor, landscape: true),
        isNot(uprightPreviewSize(sensor, landscape: false)),
      );
    });

    test('a square sensor frame is unchanged by rotation', () {
      const square = Size(480, 480);
      expect(
        uprightPreviewSize(square, landscape: true),
        uprightPreviewSize(square, landscape: false),
      );
    });
  });
}
