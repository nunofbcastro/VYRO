import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Cheap on-device checks so we can ask for a better photo instead of guessing.
class PhotoQuality {
  const PhotoQuality({
    this.tooSmall = false,
    this.tooDark = false,
    this.tooBright = false,
    this.tooBlurry = false,
  });

  final bool tooSmall;
  final bool tooDark;
  final bool tooBright;
  final bool tooBlurry;

  bool get ok => !tooSmall && !tooDark && !tooBright && !tooBlurry;

  /// String key for [FoodVisionResult.note] / UI copy.
  String? get note => tooSmall
      ? 'photoTooSmall'
      : tooDark
      ? 'photoTooDark'
      : tooBright
      ? 'photoTooBright'
      : tooBlurry
      ? 'photoTooBlurry'
      : null;
}

PhotoQuality assessPhotoBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const PhotoQuality(tooSmall: true);
  return assessPhoto(decoded);
}

PhotoQuality assessPhoto(img.Image image) {
  final shortest = image.width < image.height ? image.width : image.height;
  if (shortest < 96) return const PhotoQuality(tooSmall: true);

  final sample = img.copyResize(image, width: 128);
  const step = 1;
  var n = 0;
  var sum = 0.0;
  var detailSum = 0.0;
  var detailSq = 0.0;
  double luminance(int x, int y) {
    final p = sample.getPixel(x, y);
    return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }

  for (var y = 1; y < sample.height - 1; y += step) {
    for (var x = 1; x < sample.width - 1; x += step) {
      final px = sample.getPixel(x, y);
      final lum = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
      sum += lum;
      final lap =
          4 * lum -
          luminance(x - 1, y) -
          luminance(x + 1, y) -
          luminance(x, y - 1) -
          luminance(x, y + 1);
      detailSum += lap;
      detailSq += lap * lap;
      n++;
    }
  }
  if (n == 0) return const PhotoQuality(tooSmall: true);
  final mean = sum / n;
  final variance = detailSq / n - (detailSum / n) * (detailSum / n);
  return PhotoQuality(
    tooDark: mean < 26,
    tooBright: mean > 248,
    // Heuristic warning, never a hard rejection or a calibrated probability.
    tooBlurry: variance < 12,
  );
}
